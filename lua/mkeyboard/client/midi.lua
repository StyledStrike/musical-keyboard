local OCTAVE_WHITE_KEYS = { [0] = true, [2] = true, [4] = true, [5] = true, [7] = true, [9] = true, [11] = true }
local OCTAVE_BLACK_KEYS = { [1] = true, [3] = true, [6] = true, [8] = true, [10] = true }

MKeyboard.OCTAVE_WHITE_KEYS = OCTAVE_WHITE_KEYS
MKeyboard.OCTAVE_BLACK_KEYS = OCTAVE_BLACK_KEYS

function MKeyboard.MidiNoteIterator( useBlackKeys, startNote, endNote )
    startNote = startNote or 0
    endNote = endNote or 127

    local i = startNote - 1
    local octaveKeys = useBlackKeys and OCTAVE_BLACK_KEYS or OCTAVE_WHITE_KEYS

    return function()
        while i < endNote do
            i = i + 1

            if octaveKeys[i % 12] then
                return i
            end
        end
    end
end

do
    -- Utility to convert MIDI note numbers to note names
    local noteLetters = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

    local function GetOctave( midiNote )
        return math.floor( midiNote / 12 ) - 1
    end

    local function GetNoteLetter( midiNote )
        return noteLetters[midiNote % 12 + 1]
    end

    function MKeyboard.MidiNoteToNoteName( midiNote )
        return GetNoteLetter( midiNote ) .. GetOctave( midiNote )
    end
end

do
    -- Utility to convert note names to MIDI note numbers
    local NOTE_NAMES_TO_SEMITONE = {
        ["C"] = 0, ["C#"] = 1, ["D"] = 2, ["D#"] = 3, ["E"] = 4,
        ["F"] = 5, ["F#"] = 6, ["G"] = 7, ["G#"] = 8,
        ["A"] = 9, ["A#"] = 10, ["B"] = 11
    }

    function MKeyboard.NoteNameToMidiNote( noteName )
        local note, octave = noteName:match( "([%a#]+)(%-?%d+)" )

        if not note or not octave or not NOTE_NAMES_TO_SEMITONE[note] then
            return nil
        end

        octave = tonumber( octave )

        if not octave then
            return nil
        end

        return ( octave + 1 ) * 12 + NOTE_NAMES_TO_SEMITONE[note]
    end
end

if util.IsBinaryModuleInstalled( "midi" ) then
    require( "midi" )
end

if not midi then
    MKeyboard.Print( "MIDI module is not installed" )
    return
end

local GetPorts = midi.GetPorts

local MIDI = MKeyboard.MIDI or {}
MIDI.channelState = {}
MKeyboard.MIDI = MIDI

function MIDI.GetDevices()
    local devices = {}

    for port, name in pairs( GetPorts() ) do
        devices[#devices + 1] = {
            port = port,
            name = name
        }
    end

    return devices
end

function MIDI:Close()
    self.openPort = nil
    self.openPortName = nil
    --self.selectedPort = nil

    table.Empty( self.channelState )

    if midi.IsOpened() then
        midi.Close()
        MKeyboard.Print( "MIDI port has been closed" )
    end

    MKeyboard:OnCloseMIDIPort()
end

function MIDI:SelectPort( port )
    local portName = GetPorts()[port]

    if not portName then
        MKeyboard.Print( "Tried to select a invalid MIDI port: %d", port )
        return
    end

    self:Close()
    self.selectedPort = port
end

function MIDI:CheckDevices()
    if midi.IsOpened() then
        if self.openPort and not GetPorts()[self.openPort] then
            print( "Current open MIDI port no longer exists, closing..." )
            self:Close()
        end

    elseif not self.openPort and self.selectedPort then
        local portName = GetPorts()[self.selectedPort]

        if not portName then
            MKeyboard.Print( "Tried to open a invalid MIDI port: %d", self.selectedPort )
            self.selectedPort = nil

            return
        end

        MKeyboard.Print( "Opening MIDI port: " .. portName )

        local success, err = pcall( midi.Open, self.selectedPort )

        if success then
            self.openPort = self.selectedPort
            self.openPortName = portName

            MKeyboard.Print( "Opened MIDI port: " ..  portName )
            MKeyboard:OnOpenMIDIPort( portName, self.openPort )
        else
            MKeyboard.Print( "Failed to open MIDI port: " .. err )
        end
    end
end

hook.Add( "MIDI", "MKeyboard.CaptureMIDIEvents", function( _, code, p1, p2 )
    local frame = MKeyboard.frame
    if not IsValid( frame ) then return end

    local cmd = midi.GetCommandName( code )
    local Config = MKeyboard.Config

    if cmd == "NOTE_ON" and p2 > 0 then
        local channel = midi.GetCommandChannel( code )
        local instrumentIndex = Config:GetInstrumentFromCurrentChannelMap( channel )
        if not instrumentIndex then return end

        local note = p1 + Config.midiTranspose
        local velocity = math.floor( p2 )

        frame:PressNote( channel, note, velocity, instrumentIndex, true )

    elseif cmd == "NOTE_OFF" then
        local channel = midi.GetCommandChannel( code )
        local note = p1 + Config.midiTranspose

        frame:ReleaseNote( channel, note )
    end
end )
