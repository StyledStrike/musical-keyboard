AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local MAX_USE_DISTANCE_SQR = 200 * 200

duplicator.RegisterEntityClass( "base_musical_keyboard", MKeyboard.EntityFactory, "Data" )

function ENT:SpawnFunction( ply, tr )
    if tr.Hit then
        return MKeyboard.EntityFactory( ply, {
            Pos = tr.HitPos,
            Angle = Angle( 0, ply:EyeAngles().y + 90, 0 ),
            Class = self.ClassName
        } )
    end
end

function ENT:Initialize()
    self:SetModel( "models/styledstrike/musical_keyboard.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self:DrawShadow( true )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then phys:Wake() end

    self.activePlayer = nil

    if WireLib then
        WireLib.CreateSpecialInputs( self,
            { "PressNote", "ReleaseNote" },
            { "ARRAY", "ARRAY" },
            { [[Changing this input will press a note (and keep it pressed).
The array should contain:
[1] Note MIDI number (0-127)
[2] Note velocity (0-127)
[3] Channel index (Between 0 and 15)
[4] Instrument index (The number near each name on the instruments list)]],
            [[Changing this input will release a note.
The array should contain:
[1] Note MIDI number (0-127)
[2] Channel index (Between 0 and 15)]]
        } )

        WireLib.CreateSpecialOutputs( self,
            { "NotePressed", "NoteReleased" },
            { "ARRAY", "ARRAY" },
            { [[Triggered when the user played a note.
This array contains:
[1] Note MIDI number (0-127)
[2] Note velocity (0-127)
[3] Channel index (Between 0 and 15)
[4] Instrument index (The number near each name on the instruments list)
[5] Was the note played via an external MIDI device/program? (1 for "Yes", 0 for "No"))]],
            [[Triggered when the user released a note.
This array contains:
[1] Note MIDI number (0-127)
[2] Channel index (Between 0 and 15)]]
        } )

        self.wireReproduceEvents = {}
        self.wireReproduceLastId = 0

        self.wireTransmitBuffer = {}
        self.wireTransmitCount = 0
        self.wireNextTransmitTime = 0
    end
end

local IsValid = IsValid

function ENT:Use( ply )
    if not IsValid( self.activePlayer ) then
        self:SetPlayer( ply )
    end
end

function ENT:SetPlayer( ply )
    self:RemovePlayer()

    if IsValid( ply ) and ply:Alive() then
        net.Start( "mkeyboard.set_current_keyboard", false )
        net.WriteBool( true )
        net.WriteEntity( self )
        net.Send( ply )

        self.activePlayer = ply
    end
end

function ENT:RemovePlayer()
    if IsValid( self.activePlayer ) then
        net.Start( "mkeyboard.set_current_keyboard", false )
        net.WriteBool( false )
        net.Send( self.activePlayer )
    end

    self.activePlayer = nil

    local targets = MKeyboard.GetNearbyPlayers( self:GetPos() )
    if #targets < 0 then return end

    -- Send a empty note events buffer, which stops all notes.
    net.Start( "mkeyboard.notes", false )
    net.WriteEntity( self )
    MKeyboard.WriteEvents( {} )
    net.Send( targets )
end

local CurTime = CurTime

function ENT:Think()
    local time = CurTime()
    self:NextThink( time )

    if IsValid( self.activePlayer ) and (
        not self.activePlayer:Alive() or
        self.activePlayer:GetPos():DistToSqr( self:GetPos() ) > MAX_USE_DISTANCE_SQR )
    then
        self:RemovePlayer()
    end

    self:ProcessServerNotes( time )

    return true
end

if not WireLib then
    -- Dummy functions
    function ENT:ProcessServerNotes( _t ) end
    function ENT:OnReceiveNoteEvents( _events ) end

    return
end

function ENT:OnReceiveNoteEvents( events )
    local reproduceEvents = self.wireReproduceEvents

    if #events < 1 then
        table.Empty( reproduceEvents )
        return
    end

    -- Queue events to be sent to the Wire output
    local id = self.wireReproduceLastId

    for _, event in ipairs( events ) do
        id = id + 1
        reproduceEvents[id] = event
    end

    self.wireReproduceLastId = id
end

local TRANSMIT_BUFFER_INTERVAL = MKeyboard.TRANSMIT_BUFFER_INTERVAL
local TriggerOutput = WireLib.TriggerOutput
local GetNearbyPlayers = MKeyboard.GetNearbyPlayers

local notePressOutputTable = {}
local noteReleaseOutputTable = {}

function ENT:ProcessServerNotes( t )
    -- We do a similar "note transmit" logic used on the client-side,
    -- but our source of events are Wire inputs.
    if t > self.wireNextTransmitTime and self.wireTransmitCount > 0 then
        self.wireNextTransmitTime = t + TRANSMIT_BUFFER_INTERVAL
        self.wireTransmitCount = 0

        local targets = GetNearbyPlayers( self:GetPos() )

        if #targets > 0 then
            net.Start( "mkeyboard.notes", false )
            net.WriteEntity( self )
            MKeyboard.WriteEvents( self.wireTransmitBuffer )
            net.Send( targets )
        end

        table.Empty( self.wireTransmitBuffer )
    end

    -- We do a similar logic used on the client-side, but instead of playing the notes,
    -- we output note events via Wire with the correct timing.
    t = t - TRANSMIT_BUFFER_INTERVAL * 2

    -- Process note start/stop events according to ther timestamp.
    local reproduceEvents = self.wireReproduceEvents

    -- We must process the note press events first, since the note release
    -- event for the same channel/note might come in the same tick.
    for id, event in pairs( reproduceEvents ) do
        if t >= event.time and event.instrumentIndex then
            reproduceEvents[id] = nil

            notePressOutputTable[1] = event.note
            notePressOutputTable[2] = event.velocity
            notePressOutputTable[3] = event.channelIndex
            notePressOutputTable[4] = event.instrumentIndex
            notePressOutputTable[5] = event.isAutomated and 1 or 0

            TriggerOutput( self, "NotePressed", notePressOutputTable )
        end
    end

    for id, event in pairs( reproduceEvents ) do
        if t >= event.time and not event.instrumentIndex then
            reproduceEvents[id] = nil

            noteReleaseOutputTable[1] = event.note
            noteReleaseOutputTable[2] = event.channelIndex

            TriggerOutput( self, "NoteReleased", noteReleaseOutputTable )
        end
    end
end

local MIDI_CHANNEL_ID_MIN = MKeyboard.MIDI_CHANNEL_ID_MIN
local MIDI_CHANNEL_ID_MAX = MKeyboard.MIDI_CHANNEL_ID_MAX
local MAX_NOTE_EVENTS = MKeyboard.MAX_NOTE_EVENTS

local ValidateNumber = MKeyboard.ValidateNumber

function ENT:TriggerInput( name, value )
    local transmitBuffer = self.wireTransmitBuffer
    local transmitCount = self.wireTransmitCount

    if name == "PressNote" then
        local note = ValidateNumber( value[1], 0, 127, 0 )
        if note < 1 then return end

        local velocity = ValidateNumber( value[2], 0, 127, 0 )
        if velocity < 1 then return end

        local channel = ValidateNumber( value[3], MIDI_CHANNEL_ID_MIN, MIDI_CHANNEL_ID_MAX, -1 )
        if channel < 0 then return end

        local instrument = ValidateNumber( value[4], 0, 127, 0 )
        if instrument < 1 then return end

        -- Do not add more note press events when the buffer is full
        if transmitCount >= MAX_NOTE_EVENTS then return end

        local event = {
            time = CurTime(), -- The time when the note was pressed
            note = note,
            velocity = velocity,
            channelIndex = channel,
            instrumentIndex = instrument,
            isAutomated = true
        }

        transmitCount = transmitCount + 1
        transmitBuffer[transmitCount] = event

    elseif name == "ReleaseNote" then
        local note = ValidateNumber( value[1], 0, 127, 0 )
        if note < 1 then return end

        local channel = ValidateNumber( value[2], MIDI_CHANNEL_ID_MIN, MIDI_CHANNEL_ID_MAX, -1 )
        if channel < 0 then return end

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
            channelIndex = channel
        }

        transmitCount = transmitCount + 1
        transmitBuffer[transmitCount] = event
    end

    self.wireTransmitCount = transmitCount
end
