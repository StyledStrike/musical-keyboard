-- TODO: When available next update,
-- use util.IsBinaryModuleInstalled

-- based on Starfall"s SF.Require, for clientside use
local function SafeRequireModule( moduleName )
    local osSuffix

    if system.IsWindows() then
        osSuffix = jit.arch ~= "x64" and "win32" or "win64"
    elseif system.IsLinux() then
        osSuffix = jit.arch ~= "x64" and "linux" or "linux64"
    elseif system.IsOSX() then
        osSuffix = jit.arch ~= "x64" and "osx" or "osx64"
    else
        return
    end

    if file.Exists( "lua/bin/gmcl_" .. moduleName .. "_" .. osSuffix .. ".dll", "GAME" ) then
        local ok, err = pcall( require, moduleName )
        if ok then
            return true
        else
            ErrorNoHalt( err )

            return false
        end
    end

    return false
end

-- safely require the midi module
SafeRequireModule( "midi" )

if not midi then return end

MKeyboard.isMidiAvailable = true
MKeyboard.selectedMidiPort = nil
MKeyboard.channelState = {}

function MKeyboard:MidiOpen( port )
    if midi.IsOpened() then
        self:MidiClose()
    end

    local portName = midi.GetPorts()[port]
    if not portName then
        print( "Could not find MIDI port: " .. port )

        return
    end

    print( "Opening MIDI port: " .. portName )

    local success, err = pcall( midi.Open, port )
    if success then
        self:SetMidiPortName( portName )
    else
        print( "Failed to open MIDI port: " .. err )
    end
end

function MKeyboard:MidiClose()
    self:SetMidiPortName( nil )

    if midi and midi.IsOpened() then
        print( "Closing MIDI port." )
        midi.Close()
    end
end

local portTimer = 0

function MKeyboard:CheckMidiPorts()
    -- Try to open the selected midi port
    if self.selectedMidiPort and not midi.IsOpened() and RealTime() > portTimer then
        portTimer = RealTime() + 5
        self:MidiOpen( self.selectedMidiPort )
    end
end

function MKeyboard:SetMidiPortName( name )
    if name then
        if string.len( name ) > 28 then
            name = string.sub( name, 1, 25 ) .. "..."
        end

        self.midiPortName = string.format( language.GetPhrase( "mk.midi.connected" ), name )
    else
        self.midiPortName = nil
    end
end

local settings = MKeyboard.settings

hook.Add( "MIDI", "MKeyboard.CaptureMIDIEvents", function( _, code, p1, p2 )
    if not IsValid( MKeyboard.entity ) then return end
    if not code then return end

    local midiCmd = midi.GetCommandName( code )
    local transpose = settings.midiTranspose

    if midiCmd == "NOTE_ON" and p2 > 0 then
        local midiChannel = midi.GetCommandChannel( code )
        local instrument = settings.channelInstruments[midiChannel]

        MKeyboard:PressNote( p1 + transpose, p2, instrument, true )
        MKeyboard.channelState[midiChannel] = 1

    elseif midiCmd == "NOTE_OFF" then
        MKeyboard:ReleaseNote( p1 + transpose )
    end
end )