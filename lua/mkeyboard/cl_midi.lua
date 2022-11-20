-- based on Starfall's SF.Require, for clientside use
local function SafeRequireModule( moduleName )
    local osSuffix

    if system.IsWindows() then
        osSuffix = jit.arch ~= 'x64' and 'win32' or 'win64'
    elseif system.IsLinux() then
        osSuffix = jit.arch ~= 'x64' and 'linux' or 'linux64'
    elseif system.IsOSX() then
        osSuffix = jit.arch ~= 'x64' and 'osx' or 'osx64'
    else
        return
    end

    if file.Exists( 'lua/bin/gmcl_' .. moduleName .. '_' .. osSuffix .. '.dll', 'GAME' ) then
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
SafeRequireModule( 'midi' )

local midiHandler = {
    selectedPort = nil,
    portTimer = 0
}

MKeyboard.midiHandler = midiHandler

function midiHandler:Open( port )
    self:Close()

    local portName = midi.GetPorts()[port]
    if not portName then
        print( 'Could not find MIDI port: ' .. port )

        return
    end

    print( 'Opening MIDI port: ' .. portName )

    local success, err = pcall( midi.Open, port )
    if success then
        MKeyboard.uiHandler:SetMidiPortName( portName )
    else
        print( 'Failed to open MIDI port: ' .. err )
    end
end

function midiHandler:Close()
    MKeyboard.uiHandler:SetMidiPortName( nil )

    if midi and midi.IsOpened() then
        print( 'Closing MIDI port.' )
        midi.Close()
    end
end

function midiHandler:Think()
    -- Try to open the selected midi port
    if self.selectedPort and not midi.IsOpened() and RealTime() > self.portTimer then
        self.portTimer = RealTime() + 5
        self:Open( self.selectedPort )
    end
end

-- listen to events from the MIDI module
hook.Add( 'MIDI', 'mkeyboard_CaptureMIDIEvents', function( _, code, p1, p2 )
    if not IsValid( MKeyboard.entity ) then return end
    if not code then return end

    local midiCmd = midi.GetCommandName( code )
    local transpose = MKeyboard.settings.midiTranspose

    if midiCmd == 'NOTE_ON' and p2 > 0 then
        local midiChannel = midi.GetCommandChannel( code )
        MKeyboard:NoteOn( p1 + transpose, p2, true, midiChannel )

    elseif midiCmd == 'NOTE_OFF' then
        MKeyboard:NoteOff( p1 + transpose )
    end
end )