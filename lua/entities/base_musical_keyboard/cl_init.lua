include( "shared.lua" )

function ENT:Initialize()
    self.rangedEmitter = MKeyboard.CreateRangedEmitter( self )
end

function ENT:OnRemove( fullUpdate )
    if fullUpdate then return end

    if self.rangedEmitter then
        self.rangedEmitter:Destroy()
        self.rangedEmitter = nil
    end
end

local CurTime = CurTime
local TableRemove = table.remove

local EntityPlayNote = MKeyboard.EntityPlayNote
local EntityStopNote = MKeyboard.EntityStopNote

local removeIndexes = {}

local function ProcessMarkedForRemoval( queue )
    -- We have to transverse the queue backwards
    -- to avoid issues with the indexes shifting.
    for index = #queue, 1, -1 do
        if removeIndexes[index] then
            removeIndexes[index] = nil
            TableRemove( queue, index )
        end
    end
end

--[[
    Process note start/stop events according to their timestamp,
    removing them from the note press/release event queues.

    Note that we process events with a FIFO (first in, first out) logic,
    and that we process the note press events before note release events,
    since a note release event for the same channel/note might come in the same tick.
]]
local function ProcessPlaybackQueue( ent, rangedEmitter )
    -- For proper timing, we offset the playback time by
    -- two times the buffer transmission interval.
    -- (Look for the `MKeyboard.TransmitNotes` timer on mkeyboard/client/events.lua)
    local t = CurTime() - MKeyboard.TRANSMIT_BUFFER_INTERVAL * 2

    local noteOnEvents = rangedEmitter.reproduceNoteOnEvents
    local event

    for index = 1, #noteOnEvents do
        event = noteOnEvents[index]

        if t >= event.time then
            -- Mark from removal from the queue
            removeIndexes[index] = true

            EntityPlayNote( ent, event.channelIndex, event.note, event.velocity, event.instrumentIndex, event.isAutomated )
        end
    end

    ProcessMarkedForRemoval( noteOnEvents )

    local noteOffEvents = rangedEmitter.reproduceNoteOffEvents

    for index = 1, #noteOffEvents do
        event = noteOffEvents[index]

        if t >= event.time then
            -- Mark from removal from the queue
            removeIndexes[index] = true

            EntityStopNote( ent, event.channelIndex, event.note, event.additionalReleaseTime )
        end
    end

    ProcessMarkedForRemoval( noteOffEvents )
end

function ENT:Think()
    self:SetNextClientThink( CurTime() )

    local rangedEmitter = self.rangedEmitter

    if rangedEmitter then
        rangedEmitter:Think()

        if rangedEmitter.reproduceNoteOnEvents then
            ProcessPlaybackQueue( self, rangedEmitter )
        end
    end

    return true
end

function ENT:OnUserVarChanged( name, _, value )
    local rangedEmitter = self.rangedEmitter
    if not rangedEmitter then return end

    local emitter = rangedEmitter.emitter
    if not emitter then return end

    if name == "HRTFEnabled" then
        emitter:SetHRTFEnabled( value == true )

    elseif name == "ImpulseResponseIndex" then
        local ir = MKeyboard.impulseResponses[value]
        emitter:SetImpulseResponseAudioFile( ir ~= nil and ir.fileName )
    end
end

local BLACK_KEYS = {
    [1] = true, [3] = true, [6] = true, [8] = true, [10] = true
}

local KEY_OFFSETS = {
    [2] = 0.2,
    [4] = 0.4,
    [5] = -0.1,
    [7] = 0.1,
    [9] = 0.4,
    [11] = 0.6
}

local NOTE_COLORS = MKeyboard.NOTE_COLORS
local NOTE_MIN, NOTE_MAX = 21, 108

local Remap = math.Remap
local DrawBox = render.DrawBox
local pos, min, max = Vector(), Vector(), Vector()

function ENT:Draw()
    self:DrawModel()

    local rangedEmitter = self.rangedEmitter
    if not rangedEmitter then return end

    local activeNotes = rangedEmitter.activeNotes
    if not activeNotes then return end

    render.SetColorMaterial()

    local ang = self:GetAngles()
    local relativeNote
    local x, w, h, l

    for note, colorIndex in pairs( activeNotes ) do
        if note >= NOTE_MIN and note <= NOTE_MAX then
            relativeNote = note % 12
            x = -1.1
            w = 1.6
            h = -0.2
            l = 8

            if BLACK_KEYS[relativeNote] then
                x = -0.6
                w = 1
                h = 0.1
                l = 5
            end

            x = x + ( KEY_OFFSETS[relativeNote] or 0 )
            pos[1] = -Remap( note, NOTE_MIN, NOTE_MAX, -37, 36.7 )

            min:SetUnpacked( x, -1.5, -1 )
            max:SetUnpacked( x + w, l, h )

            DrawBox( self:LocalToWorld( pos ), ang, min, max, NOTE_COLORS[colorIndex] )
        end
    end
end
