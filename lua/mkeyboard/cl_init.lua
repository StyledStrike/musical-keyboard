surface.CreateFont( "MKeyboard_Title", {
    size = ScrH() * 0.025, weight = 300, antialias = true, font = "Coolvetica"
} )

surface.CreateFont( "MKeyboard_Key", {
    size = ScrH() * 0.02, weight = 300, antialias = true, font = "Coolvetica"
} )

surface.CreateFont( "MKeyboard_Sheet", {
    size = ScrH() * 0.022, antialias = true, font = "Roboto"
} )

MKeyboard.entity = nil

MKeyboard.reproduceQueue = {}
MKeyboard.transmitQueue = {}
MKeyboard.queueTimer = nil
MKeyboard.queueStart = 0

MKeyboard.colors = {
    black = Color( 0, 0, 0, 255 ),
    white = Color( 255, 255, 255, 255 ),
    bg = Color( 0, 0, 0, 240 ),

    disabled = Color( 120, 120, 120, 255 ),
    manual = Color( 245, 163, 108 ),
    midi = Color( 196, 0, 226 )
}

MKeyboard.shortcuts = {
    [KEY_TAB] =	function()
        RunConsoleCommand( "keyboard_leave", MKeyboard.entity:EntIndex() )
    end,

    [KEY_SPACE] = function()
        MKeyboard:ToggleMenu()
    end,

    [KEY_LEFT] = function()
        MKeyboard:ChangeInstrument( -1 )
    end,

    [KEY_RIGHT] = function()
        MKeyboard:ChangeInstrument( 1 )
    end,

    [KEY_UP] = function()
        MKeyboard:AddOctave( 1 )
    end,

    [KEY_DOWN] = function()
        MKeyboard:AddOctave( -1 )
    end
}

do
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

    local function validateInteger( n, min, max )
        return math.Round( math.Clamp( tonumber( n ), min, max ) )
    end

    function MKeyboard:LoadSettings()
        local rawData = file.Read( self.SETTINGS_FILE, "DATA" )
        if not rawData then return end

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
        if data.channelInstruments and type( data.channelInstruments ) == "table" then
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
end

local dontBlockBinds = {
    ["+attack"] = true,
    ["+attack2"] = true,
    ["+duck"] = true
}

function MKeyboard:Init( ent )
    self.entity = ent
    self.blockInputTimer = RealTime() + 0.3

    self:CreateInterface()

    hook.Add( "Think", "MKeyboard.ProcessLocalKeyboard", function()
        if not IsValid( self.entity ) then
            self:Shutdown()

            return
        end

        if self.isMidiAvailable then
            self:CheckMidiPorts()
        end

        local t = SysTime()

        -- if the queued notes are ready to be sent...
        if self.queueTimer and t > self.queueTimer then
            self:TransmitQueue()
        end
    end )

    hook.Add( "PlayerButtonDown", "MKeyboard.DetectButtonPress", function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() then
            self:ButtonPress( button )
        end
    end )

    hook.Add( "PlayerButtonUp", "MKeyboard.DetectButtonRelease", function( ply, button )
        if ply == LocalPlayer() and IsFirstTimePredicted() then
            self:ButtonRelease( button )
        end
    end )

    hook.Add( "PlayerBindPress", "MKeyboard.BlockBinds", function( _, bind )
        if not dontBlockBinds[bind] then return true end
    end )

    -- Custom Chat compatibility
    hook.Add( "CustomChatBlockInput", "MKeyboard.PreventOpeningChat", function()
        return true
    end )
end

function MKeyboard:Shutdown()
    self.entity = nil

    self.transmitQueue = {}
    self.queueTimer = nil

    self.shiftMode = false
    self.noteStates = {}

    self:CloseInterface()

    if self.isMidiAvailable then
        self:MidiClose()
    end

    hook.Remove( "Think", "MKeyboard.ProcessLocalKeyboard" )
    hook.Remove( "PlayerButtonDown", "MKeyboard.DetectButtonPress" )
    hook.Remove( "PlayerButtonUp", "MKeyboard.DetectButtonRelease" )
    hook.Remove( "PlayerBindPress", "MKeyboard.BlockBinds" )
    hook.Remove( "BlockChatInput", "MKeyboard.PreventOpeningChat" )
end

function MKeyboard:OnNoteOn( note, velocity, instrument, isMidi )
    velocity = velocity or self.settings.velocity
    instrument = instrument or self.settings.instrument

    local instr = self.instruments[instrument] or self.instruments[1]
    if note < instr.firstNote or note > instr.lastNote then return end

    self.entity:EmitNote( note, velocity, 80, instrument, isMidi )
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
        self.transmitQueue[noteCount + 1] = {
            note, velocity, instrument, t - self.queueStart
        }
    end
end

function MKeyboard:TransmitQueue()
    net.Start( "mkeyboard.notes", false )
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

local SysTime = SysTime

hook.Add( "Think", "MKeyboard.ProcessReproductionQueue", function()
    local now = SysTime()
    local queue = MKeyboard.reproduceQueue
    local timestamps = table.GetKeys( queue )

    -- play the networked notes, keeping the original timings
    for _, t in ipairs( timestamps ) do
        if now > t then
            local n = queue[t]

            if IsValid( n[1] ) then
                n[1]:EmitNote( n[2], n[3], 80, n[4], n[5] )
            end

            queue[t] = nil
        end
    end
end )

net.Receive( "mkeyboard.set_entity", function()
    local ent = net.ReadEntity()

    MKeyboard:Shutdown()

    if IsValid( ent ) then
        MKeyboard:Init( ent )
    end
end )

net.Receive( "mkeyboard.notes", function()
    local ent = net.ReadEntity()
    if not IsValid( ent ) or not ent.EmitNote then return end

    local automated = net.ReadBool()
    local noteCount = net.ReadUInt( 5 )
    local note, vel, instr, timeOffset

    local queue = MKeyboard.reproduceQueue
    local t = SysTime()

    for i = 1, noteCount do
        note = net.ReadUInt( 7 )
        vel = net.ReadUInt( 7 )
        instr = net.ReadUInt( 6 )
        timeOffset = net.ReadFloat()

        -- "i * 0.01" exists just to prevent overriding stuff already on the queue
        queue[t + timeOffset + ( i * 0.01 )] = { ent, note, vel, instr, automated }
    end
end )

-- Workaround net events for hooks that only run serverside on single-player
if game.SinglePlayer() then
    net.Receive( "mkeyboard.key", function()
        local button = net.ReadUInt( 8 )
        local pressed = net.ReadBool()

        if IsValid( MKeyboard.entity ) then
            if pressed then
                MKeyboard:ButtonPress( button )
            else
                MKeyboard:ButtonRelease( button )
            end
        end
    end )
end