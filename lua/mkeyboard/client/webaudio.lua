local Print = MKeyboard.Print
local WebAudio = MKeyboard.WebAudio

local sampleInstances = WebAudio.sampleInstances or {}
local emitterInstances = WebAudio.emitterInstances or {}

WebAudio.sampleInstances = sampleInstances
WebAudio.emitterInstances = emitterInstances

-- If this is set to `true`, load the JS code directly from a file on the disk
WebAudio.TEST_MODE = false

concommand.Add( "musical_keyboard_webaudio_restart", function()
    WebAudio:Restart()
end )

-- Here we find the logic to create the HTML panel
-- only when there are active `Sample`/`Emitter` instances.
do
    local TableCount = table.Count
    local isLoaded = WebAudio.isReady

    function WebAudio.CheckActivationCriteria()
        local shouldLoad = TableCount( sampleInstances ) + TableCount( emitterInstances ) > 0

        if isLoaded ~= shouldLoad then
            isLoaded = shouldLoad

            if shouldLoad then
                WebAudio:Enable()
            else
                WebAudio:Disable()
            end
        end
    end

    timer.Create( "MKeyboard.WebAudio.CheckActivationCriteria", 30, 0, WebAudio.CheckActivationCriteria )
end

function WebAudio.IsAvailable()
    if ( system.IsLinux() or system.IsOSX() ) and BRANCH ~= "x86-64" then
        return false, "Linux/MacOS must be on the x86-64 beta branch"
    end

    return true
end

--- Returns a minified version of `data_static/musical_keyboard/web_audio_script.txt`.
function WebAudio.GetJavaScript()
    if WebAudio.TEST_MODE then
        return file.Read( "data_static/musical_keyboard/web_audio_script.txt", "GAME" )
    end

    return [[]] -- TODO: get minified version
end

function WebAudio:Restart()
    self:Disable()

    timer.Simple( 0.5, function()
        self:Enable()
    end )
end

function WebAudio:Disable()
    hook.Remove( "Think", "MKeyboard.WebAudio.Think" )

    local panel = self.panel

    if IsValid( panel ) then
        panel:Remove()
    end

    self.panel = nil
    self.isLoaded = false
    self.RunJS = nil

    Print( "WebAudio disabled." )

    -- Mark all active `Sample` instances as unloaded
    for _, sample in pairs( self.sampleInstances ) do
        sample.isReady = false
        sample.shouldInit = true
    end

    -- Mark all active `Emitter` instances as unloaded
    for _, emitter in pairs( self.emitterInstances ) do
        emitter.isReady = false
        emitter.shouldInit = true

        for _, source in pairs( emitter.sources ) do
            source.shouldInit = true
        end

        for _, property in pairs( emitter.properties ) do
            property.hasChanged = true
        end
    end
end

function WebAudio:Enable()
    local panel = self.panel

    if IsValid( panel ) then
        return
    end

    local isAvailable, reason = self.IsAvailable()

    if not isAvailable then
        self:Disable()

        Print( "WebAudio is not available: %s", reason )

        return
    end

    Print( "Loading WebAudio..." )
    self.isLoaded = false

    panel = vgui.Create( "HTML", GetHUDPanel() )
    panel:Dock( FILL )
    self.panel = panel

    panel.OnCallback = function( _, obj, func, args )
        if obj ~= "webaudio" then return end

        if self[func] then
            self[func]( self, unpack( args ) )
        end
    end

    panel.ConsoleMessage = function( _, msg, _, line, _ )
        if not isstring( msg ) then
            msg = tostring( msg )
        end

        if isnumber( line ) then
            Print( ( "[WebAudio JS:%d] %s" ):format( line, msg )  )
        else
            Print( ( "[WebAudio JS] %s" ):format( msg )  )
        end
    end

    panel.OnFinishLoadingDocument = function()
        panel:NewObject( "webaudio" )

        panel:NewObjectCallback( "webaudio", "OnInitialized" )
        panel:NewObjectCallback( "webaudio", "OnInitFailed" ) -- reason: string = "no_audio_context"

        panel:NewObjectCallback( "webaudio", "OnEmitterCreated" ) -- emitterId: string
        panel:NewObjectCallback( "webaudio", "OnSampleLoaded" ) -- sampleId: string
        panel:NewObjectCallback( "webaudio", "OnSampleFailed" ) -- sampleId: string, reason: string

        panel:RunJavascript( WebAudio.GetJavaScript() )
    end

    panel:SetHTML( "<!DOCTYPE html>\n<html><body></body></html>" )
end

function WebAudio:OnInitialized()
    self.isLoaded = true
    self.lastMasterVolume = 0

    Print( "WebAudio is ready." )

    -- Provide a way to queue JavaScript code efficiently
    local lines = {}
    local lineIndex = 0

    self.RunJS = function( str, ... )
        lineIndex = lineIndex + 1
        lines[lineIndex] = str:format( ... )
    end

    -- Limit how many times WebAudio:Think runs each second
    local RealTime = RealTime
    local nextThink = RealTime()
    local panel = self.panel

    hook.Add( "Think", "MKeyboard.WebAudio.Think", function()
        local time = RealTime()

        if time > nextThink then
            self:Think()

            -- Delay the next WebAudio:Think call so that
            -- it runs at most 60 times per second.
            nextThink = time + 0.016666

            -- Run queued JavaScript (if any)
            if lineIndex > 0 then
                panel:RunJavascript( table.concat( lines, "\n" ) )

                lineIndex = 0
                table.Empty( lines )
            end
        end
    end )
end

function WebAudio:OnInitFailed( reason )
    Print( "WebAudio failed to initialize: %s", reason )
    self:Disable()
end

function WebAudio:OnEmitterCreated( emitterId )
    local emitter = self.emitterInstances[emitterId]

    -- Make sure the Lua side still has this `Emitter` instance
    if not emitter then
        if WebAudio.RunJS then
            WebAudio.RunJS( "manager.destroyEmitter('%s');", emitterId )
        end

        return
    end

    Print( "Created emitter: '%s'", emitterId )

    emitter.isReady = true

    if emitter.onReady then
        emitter.onReady( emitter )
    end
end

function WebAudio:OnSampleLoaded( sampleId )
    -- Make sure the Lua side still has this `Sample` instance
    local sample = self.sampleInstances[sampleId]

    if not sample then
        if WebAudio.RunJS then
            WebAudio.RunJS( "manager.destroySample('%s');", sampleId )
        end

        return
    end

    Print( "Sample loaded: '%s'", sampleId )

    sample.isReady = true

    if sample.onReady then
        sample.onReady( sample )
    end
end

function WebAudio:OnSampleFailed( sampleId, reason )
    -- Make sure the Lua side still has this `Sample` instance
    local sample = self.sampleInstances[sampleId]
    if not sample then return end

    Print( "Failed to create a sample with ID '%s': %s", sampleId, reason )

    self.sampleInstances[sampleId] = nil

    if sample.onFail then
        sample.onFail( sample, reason )
    end
end

do
    local cvarVolume = GetConVar( "volume" )
    local cvarMuteLoseFocus = GetConVar( "snd_mute_losefocus" )

    local Round = math.Round
    local MainEyePos = MainEyePos
    local MainEyeAngles = MainEyeAngles

    local JS_SET_MASTER_VOL = "manager.setMasterVolume(%.2f);"
    local JS_SET_LISTENER_LOC = "manager.setListenerLocation(%.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f);"

    function WebAudio:Think()
        local RunJS = self.RunJS

        -- WebAudio bypasses Source Engine audio, so we need to apply volume console variables manually
        local masterVolume = Round( cvarVolume:GetFloat(), 2 )

        if cvarMuteLoseFocus:GetBool() and not system.HasFocus() then
            masterVolume = 0
        end

        if self.lastMasterVolume ~= masterVolume then
            self.lastMasterVolume = masterVolume
            RunJS( JS_SET_MASTER_VOL, masterVolume )
        end

        local eyePos, eyeAng = MainEyePos(), MainEyeAngles()

        -- Update listener position and orientation
        local fw = eyeAng:Forward()
        local up = eyeAng:Up()

        RunJS( JS_SET_LISTENER_LOC,
            eyePos[1], eyePos[2], eyePos[3],
            fw[1], fw[2], fw[3],
            up[1], up[2], up[3]
        )

        -- Update active `Sample` instances
        for _, sample in pairs( self.sampleInstances ) do
            if not sample.isReady and sample.shouldInit then
                sample.shouldInit = false
                RunJS( "manager.createSample('%s', '%s');", sample.id, sample.filePath )
            end
        end

        -- Update active `Emitter` instances
        for _, emitter in pairs( self.emitterInstances ) do
            if emitter.isReady then
                emitter:Think()

            elseif emitter.shouldInit then
                emitter.shouldInit = false
                RunJS( "manager.createEmitter('%s');", emitter.id )
            end
        end
    end
end

--[[
    Lua side for the `Sample` class from the WebAudio JavaScript.

    A `Sample` is a single audio buffer. Each `Sample` can have multiple
    audio sources playing it on one or many `Emitter`s, with varying volume,
    pitch and loop parameters.

    You must give a unique ID string to play this sample on a `Emitter` later.
]]

function WebAudio.LoadSample( id, filePath, onReady, onFail )
    assert( type( id ) == "string", "Sample ID must be a string!" )

    if sampleInstances[id] then
        Print( "A sample with ID '" .. id .. "' already exists, ignored `LoadSample` call." )
        return
    end

    Print( "Loading sample '%s'...", id )

    sampleInstances[id] = {
        id = id,
        filePath = filePath,

        onReady = onReady,
        onFail = onFail,

        isReady = false, -- Has the JS side created this `Sample`?
        shouldInit = true, -- Should the Lua side run the JS code to create this `Sample`?
    }

    WebAudio.CheckActivationCriteria()
end

function WebAudio.UnloadSample( sampleId )
    local sample = sampleInstances[sampleId]

    if not sample then
        Print( "A sample with ID '" .. sampleId .. "' does not exist, ignored `UnloadSample` call." )
        return
    end

    sampleInstances[sampleId] = nil

    if WebAudio.RunJS then
        WebAudio.RunJS( "manager.destroySample('%s');", sampleId )
    end

    Print( "Destroyed sample '%s'", sampleId )

    -- Mark all active `Emitter` sources that are using this sample as unloaded
    for _, emitter in pairs( emitterInstances ) do
        for _, source in pairs( emitter.sources ) do
            if source.sampleId == sampleId then
                source.shouldInit = true
            end
        end
    end
end

--[[
    Lua side for the `Emitter` class from the WebAudio JavaScript.

    A `Emitter` is a location in 3D space, that can have multiple
    `Sample` being played by `Sources`. Every `Source` has
    an unique ID string within their parent `Emitter`.
]]

local Emitter = WebAudio.Emitter or {}

Emitter.__index = Emitter
WebAudio.Emitter = Emitter

-- Setup properties that should be sent to JS when they change
local EMITTER_PROPERTIES = {
    maxDistance = {
        defaultValue = 500,
        OnChange = function( emitterId, value, RunJS )
            RunJS( "manager.emitterSetMaxDistance('%s', %.2f);", emitterId, value )
        end
    },
    position = {
        defaultValue = Vector(),
        OnChange = function( emitterId, value, RunJS )
            RunJS( "manager.emitterSetPosition('%s', %.2f, %.2f, %.2f);",
                emitterId, value[1], value[2], value[3] )
        end
    },
    enableHRTF = {
        defaultValue = nil,
        OnChange = function( emitterId, value, RunJS )
            RunJS( "manager.emitterSetHRTFEnabled('%s', %s);", emitterId, value == true and "true" or "false" )
        end
    },
    impulseResponseFile = {
        defaultValue = nil,
        OnChange = function( emitterId, value, RunJS )
            RunJS( "manager.emitterSetImpulseResponseAudioFile('%s', %s);",
                emitterId, value and "'" .. value .. "'" or "null" )
        end
    }
}

function WebAudio.CreateEmitter( onReady )
    local id = ( WebAudio.lastEmitterId or 0 ) + 1
    WebAudio.lastEmitterId = id

    id = "emitter_" .. id
    Print( "Creating emitter '%s'...", id )

    if emitterInstances[id] then
        error( "A emitter with ID '" .. id .. "' already exists!" )
    end

    local emitter = setmetatable( {
        id = id,
        sources = {},
        properties = {},
        onReady = onReady,

        isReady = false, -- Has the JS side created this `Emitter`?
        shouldInit = true, -- Should the Lua side run the JS code to create this `Emitter`?
    }, Emitter )

    for k, v in pairs( EMITTER_PROPERTIES ) do
        emitter.properties[k] = {
            value = v.defaultValue,
            hasChanged = false
        }
    end

    emitterInstances[id] = emitter

    WebAudio.CheckActivationCriteria()

    return emitter
end

function Emitter:Destroy()
    local emitterId = self.id
    if not emitterId then return end

    self.isReady = false
    self.shouldInit = false
    self.id = nil

    self.sources = nil
    self.properties = nil

    setmetatable( self, nil )
    emitterInstances[emitterId] = nil

    if WebAudio.RunJS then
        WebAudio.RunJS( "manager.destroyEmitter('%s');", emitterId )
    end

    Print( "Destroyed emitter '%s'", emitterId )
end

function Emitter:SetMaxDistance( maxDistance )
    self.properties.maxDistance.value = maxDistance
    self.properties.maxDistance.hasChanged = true
end

function Emitter:SetPosition( position )
    local property = self.properties.position
    property.value = position
    property.hasChanged = true
end

function Emitter:SetImpulseResponseAudioFile( irFileName )
    local property = self.properties.impulseResponseFile
    if property.value == irFileName then return end

    property.value = irFileName
    property.hasChanged = true
end

function Emitter:SetHRTFEnabled( enableHRTF )
    local property = self.properties.enableHRTF
    if property.value == enableHRTF then return end

    property.value = enableHRTF
    property.hasChanged = true
end

--- Creates a source to play the target `sampleId`.
---
--- If the `sampleId` does not exist or has not loaded yet, the
--- source will wait to play until the sample loads. 
function Emitter:CreateSource( sourceId, sampleId, gain, playbackRate, loopStart, loopEnd )
    assert( type( sourceId ) == "string", "'sourceId' must be a string!" )
    assert( type( sampleId ) == "string", "'sampleId' must be a string!" )

    gain = gain or 1.0

    assert( type( gain ) == "number", "'gain' must be a number!" )
    assert( playbackRate == nil or type( playbackRate ) == "number", "'playbackRate' must be a number!" )
    assert( loopStart == nil or type( loopStart ) == "number", "'loopStart' must be a number!" )
    assert( loopEnd == nil or type( loopEnd ) == "number", "'loopEnd' must be a number!" )

    self.sources[sourceId] = {
        sampleId = sampleId,
        gain = gain,
        playbackRate = playbackRate,
        loopStart = loopStart,
        loopEnd = loopEnd,

        shouldInit = true -- Should the Lua side run the JS code to create this source?
    }
end

function Emitter:DestroySource( sourceId, releaseTime )
    releaseTime = releaseTime or 0

    assert( type( sourceId ) == "string", "'sourceId' must be a string!" )
    assert( type( releaseTime ) == "number", "'releaseTime' must be a number!" )

    if not self.sources[sourceId] then return end

    if WebAudio.RunJS then
        WebAudio.RunJS( "manager.emitterDestroySource('%s', '%s', %.3f);", self.id, sourceId, releaseTime )
    end

    self.sources[sourceId] = nil
end

function Emitter:Think()
    local RunJS = WebAudio.RunJS
    local emitterId = self.id

    -- Send properties that have changed to JS
    for k, property in pairs( self.properties ) do
        if property.hasChanged then
            property.hasChanged = false
            EMITTER_PROPERTIES[k].OnChange( emitterId, property.value, RunJS )
        end
    end

    -- Update sources
    for sourceId, source in pairs( self.sources ) do
        -- Only load the source if the target sampleId is also loaded
        if
            source.shouldInit and
            sampleInstances[source.sampleId] and
            sampleInstances[source.sampleId].isReady
        then
            source.shouldInit = false

            local playbackRate = source.playbackRate and ( "%.4f" ):format( source.playbackRate ) or "null";
            local loopStart = source.loopStart and ( "%f" ):format( source.loopStart ) or "null";
            local loopEnd = source.loopEnd and ( "%f" ):format( source.loopEnd ) or "null";

            RunJS( "manager.emitterCreateSource('%s', '%s', '%s', %.2f, %s, %s, %s);",
                emitterId, sourceId, source.sampleId, source.gain, playbackRate, loopStart, loopEnd )
        end
    end
end
