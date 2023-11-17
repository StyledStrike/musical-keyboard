MKeyboard = {
    -- max. allowed number of notes per net event
    NET_MAX_NOTES = 31,

    -- players need to be within this distance to receive net events
    NET_BROADCAST_DISTANCE = 1500,

    -- name/location of the settings file
    SETTINGS_FILE = "musical_keyboard.json",

    -- URL for the midi installation guide
    URL_MIDI_GUIDE = "https://steamcommunity.com/workshop/filedetails/discussion/2656563609/3199240042192880687/"
}

if SERVER then
    include( "mkeyboard/server/init.lua" )

    AddCSLuaFile( "mkeyboard/client/init.lua" )
end

if CLIENT then
    include( "mkeyboard/client/init.lua" )
end