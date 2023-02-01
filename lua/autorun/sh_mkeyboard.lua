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
    include( "mkeyboard/sv_init.lua" )

    AddCSLuaFile( "mkeyboard/data/instruments.lua" )
    AddCSLuaFile( "mkeyboard/data/layouts.lua" )
    AddCSLuaFile( "mkeyboard/data/sheets.lua" )

    AddCSLuaFile( "mkeyboard/cl_init.lua" )
    AddCSLuaFile( "mkeyboard/cl_keyboard.lua" )
    AddCSLuaFile( "mkeyboard/cl_midi.lua" )
    AddCSLuaFile( "mkeyboard/cl_ui.lua" )
end

if CLIENT then
    include( "mkeyboard/data/instruments.lua" )
    include( "mkeyboard/data/layouts.lua" )
    include( "mkeyboard/data/sheets.lua" )

    include( "mkeyboard/cl_init.lua" )
    include( "mkeyboard/cl_keyboard.lua" )
    include( "mkeyboard/cl_midi.lua" )
    include( "mkeyboard/cl_ui.lua" )

    MKeyboard:LoadSettings()
end