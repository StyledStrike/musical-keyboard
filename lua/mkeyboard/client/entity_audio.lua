local MAX_PROCESSING_DISTANCE = MKeyboard.MAX_PROCESSING_DISTANCE

--[[
    A utility class used to automatically create/destroy
    client-side `Emitter` instances depending on:

    - The local player's distance from the Musical Keyboard entity
    - The Musical Keyboard's `Entity:IsDormant` state
]]
local RangedEmitter = MKeyboard.RangedEmitter or {}

RangedEmitter.__index = RangedEmitter
MKeyboard.RangedEmitter = RangedEmitter

function MKeyboard.CreateRangedEmitter( ent )
    return setmetatable( {
        ent = ent,
        isActive = false
    }, RangedEmitter )
end

function RangedEmitter:Destroy()
    self:Deactivate()
    setmetatable( self, nil )
end

function RangedEmitter:Activate()
    self.isActive = true
    self.channels = {}
    self.activeNotes = {}

    -- Store the events that we receive from the server to reproduce later
    self.reproduceEvents = {}
    self.reproduceLastId = 0

    if not self.emitter then
        self.emitter = MKeyboard.WebAudio.CreateEmitter()
        self.emitter:SetMaxDistance( MAX_PROCESSING_DISTANCE )
    end

    local ent = self.ent

    -- Get emitter effect parameters from the entity
    local ir = MKeyboard.impulseResponses[ent:GetImpulseResponseIndex()]
    self.emitter:SetImpulseResponseAudioFile( ir ~= nil and ir.fileName )
    self.emitter:SetHRTFEnabled( ent:GetHRTFEnabled() )
end

function RangedEmitter:Deactivate()
    self.isActive = false

    if self.emitter and self.emitter.id then
        self.emitter:Destroy()
    end

    self.emitter = nil
    self.channels = nil
    self.activeNotes = nil
    self.reproduceEvents = nil
    self.reproduceLastId = nil
end

do
    local activateDist = MAX_PROCESSING_DISTANCE * 0.9
    local deactivateDist = MAX_PROCESSING_DISTANCE

    activateDist = activateDist * activateDist
    deactivateDist = deactivateDist * deactivateDist

    local MainEyePos = MainEyePos

    function RangedEmitter:Think()
        local ent = self.ent
        local entPos = ent:GetPos()
        local dist = entPos:DistToSqr( MainEyePos() )
        local isDormant = ent:IsDormant()

        if self.isActive then
            local emitter = self.emitter

            if emitter and emitter.id then
                emitter:SetPosition( entPos )
            end

            if dist > deactivateDist or isDormant then
                self:Deactivate()
            end

        elseif dist < activateDist and not isDormant then
            self:Activate()
        end
    end
end

--[[
    Logic to create/destroy `Sample` instances on demand,
    whenever Musical Keyboard entities want to play a note.

    `Sample` instances could've always stayed loaded, but
    the WebAudio logic will remove the HTML panel when
    no samples/emitters exist to save memory,
    so we should unload them when possible.
]]

-- Automatically unload instruments, if they go unused for this amount of time
local INSTRUMENT_TIMEOUT = 15 -- Time, in seconds

-- Samples have a unique global ID, this is used to generate one
local SAMPLE_ID_FORMAT = "mkeyboard.instrument_%d.%s"

local RealTime = RealTime
local allInstruments = MKeyboard.instruments
local loadedInstruments = MKeyboard.loadedInstruments or {}

MKeyboard.loadedInstruments = loadedInstruments

--- Make sure the instrument identified by `instrumentIndex`
--- has it's samples loaded into memory, and reset it's unload timeout.
---
--- If `instrumentIndex` is valid, returns the instrument preset (the one
--- given to `MKeyboard:RegisterInstrument`). Otherwise, returns `nil`.
local function UseInstrument( instrumentIndex )
    local instrument = allInstruments[instrumentIndex]
    if not instrument then return end

    local loadedInstrument = loadedInstruments[instrumentIndex]

    if not loadedInstrument then
        MKeyboard.Print( "Loading instrument #%d (%s)", instrumentIndex, instrument.name )

        loadedInstrument = {
            timeout = 0,
            sampleIds = {}
        }

        loadedInstruments[instrumentIndex] = loadedInstrument

        -- Load the sample files from this instrument
        for _, sample in ipairs( instrument.samples ) do
            local sampleId = SAMPLE_ID_FORMAT:format( instrumentIndex, sample.fileName )

            -- Store the IDs given to these samples so they can be unload them later
            loadedInstrument.sampleIds[#loadedInstrument.sampleIds + 1] = sampleId

            MKeyboard.WebAudio.LoadSample( sampleId, instrument.basePath .. "/" .. sample.fileName )
        end
    end

    -- Reset the timeout
    loadedInstrument.timeout = RealTime() + INSTRUMENT_TIMEOUT

    return instrument
end

--- Given a MIDI note number, return the closest sample
--- that matches it, alongside a pitch value to make
--- the sample perfectly match the note tone.
local function GetSampleFromNote( instrument, note )
    local samples = instrument.samples
    local index = 1

    for i = #samples, 1, -1 do
        if note >= samples[i].note then
            index = i
            break
        end
    end

    local sample = samples[index]
    local semitoneDiff = note - sample.note
    local pitch = 2 ^ ( semitoneDiff / 12 )

    return sample, pitch
end

local IsValid = IsValid

function MKeyboard.EntityPlayNote( ent, channelIndex, note, velocity, instrumentIndex, isAutomated )
    if not IsValid( ent ) then return end
    if not ent.rangedEmitter then return end

    local emitter = ent.rangedEmitter.emitter
    if not emitter then return end

    local instrument = UseInstrument( instrumentIndex )
    if not instrument then return end

    -- TODO: Add a limit to how many notes can play simultaneously

    local sample, pitch = GetSampleFromNote( instrument, note )
    local sampleId = SAMPLE_ID_FORMAT:format( instrumentIndex, sample.fileName )
    local volume = velocity / 127

    if instrument.params and instrument.params.volume then
        volume = volume * instrument.params.volume
    end

    -- We use the note as the sourceId. It's unique for this emitter,
    -- so that means that calling `MKeyboard.EntityPlayNote` with the same
    -- entity/channel/note/instrument will replace the existing source.
    local sourceId = channelIndex .. "_" .. note
    emitter:CreateSource( sourceId, sampleId, volume, pitch, sample.loopStart, sample.loopEnd )

    local channels = ent.rangedEmitter.channels
    local channelNotes = channels[channelIndex] or {}

    -- Store this note's sourceId/instrumentIndex as playing on the target channel 
    channelNotes[note] = {
        sourceId = sourceId,
        instrumentIndex = instrumentIndex
    }

    channels[channelIndex] = channelNotes
    ent.rangedEmitter.activeNotes[note] = isAutomated and "automated" or "manual"
end

function MKeyboard.EntityStopNote( ent, channelIndex, note )
    if not IsValid( ent ) then return end
    if not ent.rangedEmitter then return end

    local emitter = ent.rangedEmitter.emitter
    if not emitter then return end

    local channelNotes = ent.rangedEmitter.channels[channelIndex]
    if not channelNotes then return end

    local playingNote = channelNotes[note]
    if not playingNote then return end

    local releaseTime = 0.3
    local instrument = allInstruments[playingNote.instrumentIndex]

    if instrument and instrument.params and instrument.params.releaseTime then
        releaseTime = instrument.params.releaseTime
    end

    emitter:DestroySource( playingNote.sourceId, releaseTime )

    ent.rangedEmitter.activeNotes[note] = nil
end

function MKeyboard.EntityReleaseAllNotes( ent )
    if not IsValid( ent ) then return end

    local rangedEmitter = ent.rangedEmitter
    if not rangedEmitter then return end

    local emitter = rangedEmitter.emitter
    if not emitter then return end

    for channelIndex, channelNotes in pairs( rangedEmitter.channels ) do
        for note, _ in pairs( channelNotes ) do
            MKeyboard.EntityStopNote( ent, channelIndex, note )
        end
    end
end

function MKeyboard.EntityDestroyAllNotes( ent )
    if not IsValid( ent ) then return end

    local rangedEmitter = ent.rangedEmitter
    if not rangedEmitter then return end

    local emitter = rangedEmitter.emitter
    if not emitter then return end

    for _, channelNotes in pairs( rangedEmitter.channels ) do
        for note, playingNote in pairs( channelNotes ) do
            emitter:DestroySource( playingNote.sourceId )
            rangedEmitter.activeNotes[note] = nil
        end
    end
end

timer.Create( "MKeyboard.AutoUnloadInstruments", 5, 0, function()
    -- Unload "timed out" instruments
    local t = RealTime()

    for instrumentIndex, loadedInstrument in pairs( loadedInstruments ) do
        if t > loadedInstrument.timeout then
            loadedInstruments[instrumentIndex] = nil

            MKeyboard.Print( "Unloading instrument #%d", instrumentIndex )

            for _, sampleId in ipairs( loadedInstrument.sampleIds ) do
                MKeyboard.WebAudio.UnloadSample( sampleId )
            end
        end
    end
end )
