MKeyboard = {
	-- max. allowed number of notes per net event
	NET_MAX_NOTES = 32,

	-- players need to be within this distance to receive net events
	NET_BROADCAST_DISTANCE = 1500,

	-- name/location of the settings file
	SETTINGS_FILE = 'musical_keyboard.json'
}

if SERVER then
	include('mkeyboard/sv_init.lua')

	AddCSLuaFile('mkeyboard/cl_init.lua')
	AddCSLuaFile('mkeyboard/cl_interface.lua')
	AddCSLuaFile('mkeyboard/cl_midi.lua')

	AddCSLuaFile('mkeyboard/data/instruments.lua')
	AddCSLuaFile('mkeyboard/data/layouts.lua')
	AddCSLuaFile('mkeyboard/data/sheets.lua')
end

if CLIENT then
	include('mkeyboard/cl_init.lua')
	include('mkeyboard/cl_interface.lua')
	include('mkeyboard/cl_midi.lua')

	include('mkeyboard/data/instruments.lua')
	include('mkeyboard/data/layouts.lua')
	include('mkeyboard/data/sheets.lua')

	MKeyboard:LoadSettings()
end