MKeyboard.entity = nil

MKeyboard.reproduceQueue = {}
MKeyboard.transmitQueue = {}
MKeyboard.queueTimer = nil
MKeyboard.queueStart = 0

MKeyboard.shiftMode = false
MKeyboard.noteStates = {}
MKeyboard.blockInput = 0

-- settings & persistence
MKeyboard.settings = {
    layout = 1,
    instrument = 1,
    sheet = 0,
    velocity = 127,
    octave = 0,
    midiTranspose = 0,

    channelInstruments = {},
    drawKeyLabels = true
}

local shortcuts = {
    [KEY_TAB] =	function()
        RunConsoleCommand( 'keyboard_leave', MKeyboard.entity:EntIndex() )
    end,

    [KEY_SPACE] = function()
        MKeyboard.uiHandler:ToggleExpandedBar()
    end,

    [KEY_LEFT] = function()
        MKeyboard.uiHandler:ChangeInstrument( -1 )
    end,

    [KEY_RIGHT] = function()
        MKeyboard.uiHandler:ChangeInstrument( 1 )
    end,

    [KEY_UP] = function()
        MKeyboard.uiHandler:AddOctave( 1 )
    end,

    [KEY_DOWN] = function()
        MKeyboard.uiHandler:AddOctave( -1 )
    end
}

local dontBlockBinds = {
    ['+attack'] = true,
    ['+attack2'] = true,
    ['+duck'] = true
}

local function validateInteger( n, min, max )
    return math.Round( math.Clamp( tonumber( n ), min, max ) )
end

function MKeyboard:LoadSettings()
    local rawData = file.Read( self.SETTINGS_FILE, 'DATA' )
    if rawData == nil then return end

    local data = util.JSONToTable( rawData ) or {}
    local instrumentCount = #self.instruments

    -- last layout that was used on the keyboard
    if data.layout then
        self.settings.layout = validateInteger( data.layout, 1, #self.layouts )
    end

    -- last instrument that was used on the keyboard
    if data.instrument then
        self.settings.instrument = validateInteger( data.instrument, 1, instrumentCount )
    end

    -- last selected sheet
    if data.sheet then
        self.settings.sheet = validateInteger( data.sheet, 0, #self.sheets )
    end

    -- last velocity set by the settings
    if data.velocity then
        self.settings.velocity = validateInteger( data.velocity, 1, 127 )
    end

    -- last octave that was used on the keyboard
    if data.octave then
        self.settings.octave = validateInteger( data.octave, -3, 3 )
    end

    -- last transpose that was used with midi
    if data.midiTranspose then
        self.settings.midiTranspose = validateInteger( data.midiTranspose, -48, 48 )
    end

    -- links between instruments and MIDI channels
    if data.channelInstruments and type( data.channelInstruments ) == 'table' then
        for c, i in pairs( data.channelInstruments ) do
            local channel = validateInteger( c, 0, 15 )
            local instrument = validateInteger( i, 1, instrumentCount )

            self.settings.channelInstruments[channel] = instrument
        end
    end

    -- draw labels for keys
    self.settings.drawKeyLabels = Either( isbool( data.drawKeyLabels ), tobool( data.drawKeyLabels ), true )
end

function MKeyboard:SaveSettings()
    local s = self.settings

    file.Write(
        self.SETTINGS_FILE,
        util.TableToJSON( {
            layout				= s.layout,
            instrument			= s.instrument,
            sheet				= s.sheet,
            velocity			= s.velocity,
            octave				= s.octave,
            midiTranspose		= s.midiTranspose,
            channelInstruments	= s.channelInstruments,
            drawKeyLabels		= s.drawKeyLabels
        }, true )
    )
end

function MKeyboard:Init( ent )
    self.entity = ent
    self.blockInput = RealTime() + 0.3

    self.uiHandler:Init()

    hook.Add( 'Think', 'mkeyboard_ProcessLocalKeyboard', function()
        self:Think()
    end )

    hook.Add( 'PlayerButtonDown', 'mkeyboard_LocalButtonPress', function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() then
            self:OnButton( button, true )
        end
    end )

    hook.Add( 'PlayerButtonUp', 'mkeyboard_LocalButtonRelease', function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() then
            self:OnButton( button, false )
        end
    end )

    hook.Add( 'PlayerBindPress', 'mkeyboard_BlockBinds', function( _, bind )
        if not dontBlockBinds[bind] then return true end
    end )

    -- Custom Chat compatibility
    hook.Add( 'BlockChatInput', 'mkeyboard_PreventOpeningChat', function()
        return true
    end )
end

function MKeyboard:Shutdown()
    self.entity = nil

    self.transmitQueue = {}
    self.queueTimer = nil

    self.shiftMode = false
    self.noteStates = {}

    self.midiHandler:Close()
    self.uiHandler:Shutdown()

    hook.Remove( 'Think', 'mkeyboard_ProcessLocalKeyboard' )
    hook.Remove( 'PlayerButtonDown', 'mkeyboard_LocalButtonPress' )
    hook.Remove( 'PlayerButtonUp', 'mkeyboard_LocalButtonRelease' )
    hook.Remove( 'PlayerBindPress', 'mkeyboard_BlockBinds' )
    hook.Remove( 'BlockChatInput', 'mkeyboard_PreventOpeningChat' )
end

function MKeyboard:NoteOn( note, velocity, isMidi, midiChannel )
    local instrument = self.settings.instrument

    if midiChannel then
        self.uiHandler.channelState[midiChannel] = 1
        instrument = self.settings.channelInstruments[midiChannel] or instrument

        if instrument == 0 then return end
    end

    local instr = self.instruments[instrument]
    if note < instr.firstNote or note > instr.lastNote then return end

    self.entity:EmitNote( note, velocity, 80, instrument, isMidi )

    self.noteStates[note] = isMidi and 'midi' or 'on'
    self.lastNoteWasAutomated = isMidi

    -- remember when we started putting notes
    -- on the queue, and when we should send them
    local t = SysTime()

    if not self.queueTimer then
        self.queueTimer = t + 0.4
        self.queueStart = t
    end

    -- add notes to the queue unless the limit is was reached
    local noteCount = #self.transmitQueue
    if noteCount < self.NET_MAX_NOTES then
        self.transmitQueue[noteCount + 1] = { note, velocity, instrument, t - self.queueStart }
    end
end

function MKeyboard:NoteOff( note )
    self.noteStates[note] = nil
end

function MKeyboard:NoteOffAll()
    for k, _ in pairs( self.noteStates ) do
        self.noteStates[k] = nil
    end
end

function MKeyboard:ReproduceQueue()
    local t = SysTime()

    -- play the networked notes, keeping the original timings
    for time, data in pairs( self.reproduceQueue ) do
        if t > time then
            if IsValid( data[1] ) then
                data[1]:EmitNote( data[2], data[3], 80, data[4], data[5] )
            end

            self.reproduceQueue[time] = nil
        end
    end
end

function MKeyboard:TransmitQueue()
    net.Start( 'mkeyboard.notes', false )
    net.WriteEntity( self.entity )
    net.WriteBool( self.lastNoteWasAutomated )
    net.WriteUInt( #self.transmitQueue, 5 )

    for _, params in ipairs( self.transmitQueue ) do
        net.WriteUInt( params[1], 7 ) -- note
        net.WriteUInt( params[2], 7 ) -- velocity
        net.WriteUInt( params[3], 6 ) -- instrument
        net.WriteFloat( params[4] )   -- time offset
    end

    net.SendToServer()

    table.Empty( self.transmitQueue )
    self.queueTimer = nil
end

function MKeyboard:Think()
    if not IsValid( self.entity ) then
        self:Shutdown()

        return
    end

    self.midiHandler:Think()

    local t = SysTime()

    -- if the queued notes are ready to be sent...
    if self.queueTimer and t > self.queueTimer then
        self:TransmitQueue()
    end
end

function MKeyboard:OnButton( button, isPressed )
    if button == KEY_LSHIFT then
        self.shiftMode = isPressed
    end

    -- process shortcuts
    if shortcuts[button] and not isPressed then
        shortcuts[button]()
        return
    end

    if self.blockInput > RealTime() then return end

    local layoutKeys = self.layouts[self.settings.layout].keys

    -- process layout keys
    for _, params in ipairs( layoutKeys ) do
        --[[ params:
            key [1],
            note [2],
            type [3],
            label [4],
            require SHIFT [5],
            alternative key [6]
        ]]

        -- if either the "main" or "alternative" buttons are pressed for this key...
        if params[1] == button or ( params[6] and params[6] == button ) then
            local note = params[2] + self.settings.octave * 12

            if isPressed then
                -- if this key requires shift and shift is pressed...
                if params[5] and self.shiftMode then
                    self:NoteOn( note, self.settings.velocity, false )
                    break
                end

                -- if this key does NOT require shift and shift is NOT pressed...
                if not params[5] and not self.shiftMode then
                    self:NoteOn( note, self.settings.velocity, false )
                    break
                end
            else
                self:NoteOff( note )
            end
        end
    end
end

hook.Add( 'Think', 'mkeyboard_ProcessReproductionQueue', function()
    MKeyboard:ReproduceQueue()
end )

net.Receive( 'mkeyboard.set_entity', function()
    local ent = net.ReadEntity()

    MKeyboard:Shutdown()

    if IsValid( ent ) then
        MKeyboard:Init( ent )
    end
end )

net.Receive( 'mkeyboard.notes', function()
    local ent = net.ReadEntity()
    if not IsValid( ent ) or not ent.EmitNote then return end

    local automated = net.ReadBool()
    local noteCount = net.ReadUInt( 5 )
    local note, vel, instr, timeOffset

    local t = SysTime()
    local i = 1

    while i < noteCount do
        note = net.ReadUInt( 7 )
        vel = net.ReadUInt( 7 )
        instr = net.ReadUInt( 6 )
        timeOffset = net.ReadFloat()

        MKeyboard.reproduceQueue[t + timeOffset] = { ent, note, vel, instr, automated }
        i = i + 1
    end
end )

-- key press/release net event that only runs on single-player
if game.SinglePlayer() then
    net.Receive( 'mkeyboard.key', function()
        local button = net.ReadUInt( 8 )
        local pressed = net.ReadBool()

        if IsValid( MKeyboard.entity ) then
            MKeyboard:OnButton( button, pressed )
        end
    end )
end