MKeyboard = MKeyboard or {}

-- MIDI constants
MKeyboard.MIDI_CHANNEL_ID_MIN = 0
MKeyboard.MIDI_CHANNEL_ID_MAX = 15

--[[
    Distance required for:

    - Sending note network events to nearby players only
    - Processing client-side sounds for nearby keyboards only
]]
MKeyboard.MAX_PROCESSING_DISTANCE = 1000

--[[
    Max. number of notes that can play simultaneously per entity
]]
MKeyboard.MAX_EMITTER_SOURCES = 30

-- Sandbox limits
cleanup.Register( "musical_keyboards" )

CreateConVar(
    "sbox_maxmusical_keyboards",
    "3", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "Max. number of Musical Keyboards that one player can have", 0
)

do
    local isDeveloperActive = false

    function MKeyboard.GetDevMode()
        return isDeveloperActive
    end

    -- Using `cvars.AddChangeCallback` is unreliable serverside,
    -- so we will check it periodically instead.
    local cvarDeveloper = GetConVar( "developer" )
    isDeveloperActive = cvarDeveloper:GetBool()

    timer.Create( "MKeyboard.CheckDeveloperConvar", 3, 0, function()
        isDeveloperActive = cvarDeveloper:GetBool()
    end )

    local COLOR_TAG = Color( 255, 255, 255 )
    local COLOR_SV = Color( 3, 169, 244 )
    local COLOR_CL = Color( 222, 169, 9 )

    function MKeyboard.Print( str, ... )
        if not isDeveloperActive then return end
        MsgC( COLOR_TAG, "[", SERVER and COLOR_SV or COLOR_CL, "MKeyboard", COLOR_TAG, "] ", string.format( str, ... ), "\n" )
    end
end

function MKeyboard.ValidateNumber( v, min, max, default )
    return math.Clamp( tonumber( v ) or default, min, max )
end

function MKeyboard.SetNumber( t, k, v, min, max, default )
    t[k] = MKeyboard.ValidateNumber( v, min, max, default )
end

function MKeyboard.JSONToTable( json )
    if type( json ) ~= "string" or json == "" then
        return {}
    end

    return util.JSONToTable( json ) or {}
end

function MKeyboard.LoadDataFile( path )
    MKeyboard.Print( "Reading %s", path )
    return file.Read( path, "DATA" )
end

function MKeyboard.SaveDataFile( path, data )
    MKeyboard.Print( "Writing %s to %s", string.NiceSize( string.len( data ) ), path )
    file.Write( path, data )
end

local function IncludeDir( dirPath, doInclude, doTransfer )
    local files = file.Find( dirPath .. "*.lua", "LUA" )
    local path

    for _, fileName in ipairs( files ) do
        path = dirPath .. fileName

        if doInclude then
            MKeyboard.Print( "Including %s", path )
            include( path )
        end

        if doTransfer then
            MKeyboard.Print( "Adding %s to client Lua files", path )
            AddCSLuaFile( path )
        end
    end
end

if SERVER then
    resource.AddWorkshop( "2656563609" )

    -- Shared files
    IncludeDir( "mkeyboard/", true, true )

    -- Server-only files
    IncludeDir( "mkeyboard/server/", true, false )

    -- Client-only files
    AddCSLuaFile( "includes/modules/styled_theme.lua" )
    IncludeDir( "mkeyboard/client/", false, true )
    IncludeDir( "mkeyboard/client/vgui/", false, true )
    IncludeDir( "mkeyboard/client/autoload/", false, true )
end

if CLIENT then
    -- URL for the midi installation guide
    MKeyboard.URL_MIDI_GUIDE = "https://steamcommunity.com/workshop/filedetails/discussion/2656563609/3199240042192880687/"

    MKeyboard.NOTE_COLORS = {
        manual = Color( 245, 163, 108 ),
        automated = Color( 196, 0, 226 ),
    }

    -- Make these tables available before we include everything
    MKeyboard.instruments = MKeyboard.instruments or {}
    MKeyboard.layouts = MKeyboard.layouts or {}
    MKeyboard.sheets = MKeyboard.sheets or {}
    MKeyboard.impulseResponses = MKeyboard.impulseResponses or {}

    MKeyboard.Config = MKeyboard.Config or {}
    MKeyboard.WebAudio = MKeyboard.WebAudio or {}

    -- UI theme library
    require( "styled_theme" )

    StyledTheme.RegisterFont( "MKeyboard_Large", 0.022, {
        font = "Roboto",
        weight = 300,
    } )

    StyledTheme.RegisterFont( "MKeyboard_Small", 0.015, {
        font = "Roboto",
        weight = 600,
    } )

    -- Shared files
    IncludeDir( "mkeyboard/", true, false )

    -- Client-only files
    IncludeDir( "mkeyboard/client/", true, false )
    IncludeDir( "mkeyboard/client/vgui/", true, false )
    IncludeDir( "mkeyboard/client/autoload/", true, false )
end
