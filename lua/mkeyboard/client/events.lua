net.Receive( "mkeyboard.set_current_keyboard", function()
    local ent = nil

    if net.ReadBool() then
        ent = net.ReadEntity()
    end

    if IsValid( ent ) then
        MKeyboard:Activate( ent )
    else
        MKeyboard:Deactivate()
    end
end )

function MKeyboard:Activate( ent )
    self:Deactivate()

    if not IsValid( ent ) then
        ErrorNoHaltWithStack( "Received an invalid entity when activating the Musical Keyboard!" )
        return
    end

    self.Config:Load()
    self.entity = ent
    self.blockInputTimeout = RealTime() + 0.3

    self.frame = vgui.Create( "MKeyboard_Frame" )
    self.frame:SetKeyboardInstrument()
    self.frame:SetKeyboardLayout()

    self.frame.pianoPanel.GetActiveNotes = function()
        if not IsValid( ent ) then return end

        local rangedEmitter = ent.rangedEmitter
        if not rangedEmitter then return end

        return rangedEmitter.activeNotes
    end

    if self.MIDI then
        if not self.MIDI.selectedPort then
            self.frame:OpenMIDIDevicesDialog()
        end

        timer.Create( "MKeyboard.MIDI.CheckDevices", 1, 0, function()
            self.MIDI:CheckDevices()
        end )
    end

    -- Keep track of all the note press/release events
    -- that happened since the last time we sent them to the server.
    local transmitBuffer = {}
    local transmitCount = 0

    self.frame.OnNotePressed = function( _, channelIndex, note, velocity, instrumentIndex, isAutomated )
        -- Passthrough local note press events to our local entity
        if IsValid( self.entity ) then
            self.EntityPlayNote( self.entity, channelIndex, note, velocity, instrumentIndex, isAutomated )
        end

        -- Do not add more note press events when the buffer is full
        if transmitCount >= MKeyboard.MAX_NOTE_EVENTS then return end

        local event = {
            time = CurTime(), -- The time when the note was pressed
            note = note,
            velocity = velocity,
            channelIndex = channelIndex,
            instrumentIndex = instrumentIndex,
            isAutomated = isAutomated
        }

        transmitCount = transmitCount + 1
        transmitBuffer[transmitCount] = event
    end

    self.frame.OnNoteReleased = function( _, channelIndex, note )
        -- Passthrough local note release events to our local entity
        if IsValid( self.entity ) then
            self.EntityStopNote( self.entity, channelIndex, note )
        end

        -- Remove all note press events if the buffer is full
        if transmitCount >= MKeyboard.MAX_NOTE_EVENTS then
            local event

            for i = transmitCount, 1, -1 do
                event = transmitBuffer[i]

                if event.instrumentIndex then
                    table.remove( transmitBuffer, i )
                end
            end

            transmitCount = #transmitBuffer
        end

        local event = {
            time = CurTime(), -- The time when the note was released
            note = note,
            channelIndex = channelIndex
        }

        transmitCount = transmitCount + 1
        transmitBuffer[transmitCount] = event
    end

    self.frame.OnReleaseAllNotes = function()
        if IsValid( self.entity ) then
            self.EntityReleaseAllNotes( self.entity )
        end

        transmitCount = 0
        table.Empty( transmitBuffer )
    end

    -- Passthrough button events while the frame is focused
    self.frame.OnKeyCodePressed = function( _, key )
        self:OnButtonPress( key )
    end

    self.frame.OnKeyCodeReleased = function( _, key )
        self:OnButtonRelease( key )
    end

    timer.Create( "MKeyboard.TransmitNotes", MKeyboard.TRANSMIT_BUFFER_INTERVAL, 0, function()
        if transmitCount < 1 then return end

        local entity = self.entity
        if not IsValid( entity ) then return end

        net.Start( "mkeyboard.notes", false )
        net.WriteEntity( entity )
        MKeyboard.WriteEvents( transmitBuffer )
        net.SendToServer()

        transmitCount = 0
        table.Empty( transmitBuffer )
    end )

    hook.Add( "Think", "MKeyboard.ProcessLocalKeyboard", function()
        if not IsValid( self.entity ) then
            self:Deactivate()
            return
        end
    end )

    hook.Add( "PlayerButtonDown", "MKeyboard.DetectButtonPress", function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() and not ply:KeyDown( IN_WALK ) then
            self:OnButtonPress( button )
        end
    end )

    hook.Add( "PlayerButtonUp", "MKeyboard.DetectButtonRelease", function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() then
            self:OnButtonRelease( button )
        end
    end )

    local DONT_BLOCK_BINDS = {
        ["+attack"] = true,
        ["+attack2"] = true,
        ["+duck"] = true,
        ["+walk"] = true
    }

    hook.Add( "PlayerBindPress", "MKeyboard.BlockBinds", function( ply, bind )
        if not DONT_BLOCK_BINDS[bind] and not ply:KeyDown( IN_WALK ) then
            return true
        end
    end )

    local DONT_DRAW = {
        ["CHudAmmo"] = true
    }

    hook.Add( "HUDShouldDraw", "MKeyboard.HideHUD", function( name )
        if DONT_DRAW[name] then
            return false
        end
    end )

    -- Custom Chat compatibility
    if CustomChat then
        hook.Add( "CustomChatBlockInput", "MKeyboard.PreventOpeningChat", function()
            return true
        end )
    end

    -- Easychat compatibility
    if EasyChat then
        hook.Add( "StartChat", "MKeyboard.PreventOpeningChat", function()
            return true
        end )
    end
end

function MKeyboard:Deactivate()
    if IsValid( self.frame ) then
        self.frame:Close()
    end

    self.frame = nil
    self.entity = nil

    hook.Remove( "Think", "MKeyboard.ProcessLocalKeyboard" )

    hook.Remove( "PlayerButtonDown", "MKeyboard.DetectButtonPress" )
    hook.Remove( "PlayerButtonUp", "MKeyboard.DetectButtonRelease" )
    hook.Remove( "HUDShouldDraw", "MKeyboard.HideHUD" )
    hook.Remove( "PlayerBindPress", "MKeyboard.BlockBinds" )

    hook.Remove( "CustomChatBlockInput", "MKeyboard.PreventOpeningChat" )
    hook.Remove( "StartChat", "MKeyboard.PreventOpeningChat" )

    timer.Remove( "MKeyboard.MIDI.CheckDevices" )
    timer.Remove( "MKeyboard.TransmitNotes" )

    if self.MIDI then
        self.MIDI:Close()
    end
end

function MKeyboard:Leave()
    if IsValid( self.entity ) then
        RunConsoleCommand( "musical_keyboard_leave", self.entity:EntIndex() )
    end

    self:Deactivate()
end

function MKeyboard:OnOpenMIDIPort( name, _port )
    if not IsValid( self.frame ) then return end

    if string.len( name ) > 40 then
        name = string.sub( name, 1, 37 ) .. "..."
    end

    self.frame:SetStatusText( string.format( language.GetPhrase( "#musicalk.midi.connected" ), name ) )
end

function MKeyboard:OnCloseMIDIPort()
    if not IsValid( self.frame ) then return end

    self.frame:SetStatusText( nil )
end

function MKeyboard:OnButtonPress( button )
    if self.blockInputTimeout and RealTime() < self.blockInputTimeout then
        return
    end

    self.blockInputTimeout = nil

    if IsValid( self.frame ) then
        self.frame:OnKeyboardPressButton( button )
    end
end

local SHORTCUT_KEYS = {
    [KEY_TAB] =	function( _frame )
        MKeyboard:Leave()
    end,

    [KEY_SPACE] = function( frame )
        frame:ToggleExpanded()
    end,

    [KEY_UP] = function( frame )
        frame:SwitchInstrument( -1 )
    end,

    [KEY_DOWN] = function( frame )
        frame:SwitchInstrument( 1 )
    end,

    [KEY_RIGHT] = function( frame )
        frame:SetKeyboardTranspose( MKeyboard.Config.keyboardTranspose + 1 )
    end,

    [KEY_LEFT] = function( frame )
        frame:SetKeyboardTranspose( MKeyboard.Config.keyboardTranspose - 1 )
    end
}

function MKeyboard:OnButtonRelease( button )
    if not IsValid( self.frame ) then return end

    if self.blockInputTimeout and RealTime() < self.blockInputTimeout then
        return
    end

    if SHORTCUT_KEYS[button] then
        SHORTCUT_KEYS[button]( self.frame )

        return
    end

    self.frame:OnKeyboardReleaseButton( button )
end

net.Receive( "mkeyboard.notes", function()
    local ent = net.ReadEntity()
    if not IsValid( ent ) then return end

    local rangedEmitter = ent.rangedEmitter
    if not rangedEmitter then return end

    local reproduceEvents = rangedEmitter.reproduceEvents
    if not reproduceEvents then return end

    local events = MKeyboard.ReadEvents()

    -- An empty buffer means "stop all notes".
    if #events < 1 then
        table.Empty( reproduceEvents )
        MKeyboard.EntityReleaseAllNotes( ent )
        return
    end

    -- Queue events to be reproduced
    local id = rangedEmitter.reproduceLastId

    for _, event in ipairs( events ) do
        id = id + 1
        reproduceEvents[id] = event
    end

    rangedEmitter.reproduceLastId = id
end )
