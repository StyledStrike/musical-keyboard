net.Receive('mkeyboard.set_entity', function()
	local ent = net.ReadEntity()

	MKeyboard:Shutdown()

	if IsValid(ent) then
		MKeyboard:Init(ent)
	end
end)

net.Receive('mkeyboard.notes', function()
	local ent = net.ReadEntity()
	if not IsValid(ent) or not ent.EmitNote then return end

	local automated = net.ReadBool()
	local noteCount = net.ReadUInt(5)
	local note, vel, instr, timeOffset

	local t = SysTime()

	for i = 1, noteCount do
		note = net.ReadUInt(7)
		vel = net.ReadUInt(7)
		instr = net.ReadUInt(6)
		timeOffset = net.ReadFloat()

		MKeyboard.reproduceQueue[t + timeOffset] = { ent, note, vel, instr, automated }
	end
end)

-- settings & persistence
MKeyboard.Settings = {
	layout = 1,
	instrument = 1,
	sheet = 0,
	velocity = 127,
	transpose = 0,

	channelInstruments = {},
	drawKeyLabels = true
}

local function ValidateInteger(n, min, max)
	return math.Round(math.Clamp(tonumber(n), min, max))
end

function MKeyboard:LoadSettings()
	local rawData = file.Read(self.SETTINGS_FILE, 'DATA')
	if rawData == nil then return end

	local data = util.JSONToTable(rawData) or {}
	local nInstruments = #self.Instruments

	-- last layout that was used on the keyboard
	if data.layout then
		self.Settings.layout = ValidateInteger(data.layout, 1, #self.Layouts)
	end

	-- last instrument that was used on the keyboard
	if data.instrument then
		self.Settings.instrument = ValidateInteger(data.instrument, 1, nInstruments)
	end

	-- last selected sheet
	if data.sheet then
		self.Settings.sheet = ValidateInteger(data.sheet, 0, #self.Sheets)
	end

	-- last velocity set by the settings
	if data.velocity then
		self.Settings.velocity = ValidateInteger(data.velocity, 1, 127)
	end

	-- last transpose that was used on the keyboard
	if data.transpose then
		self.Settings.transpose = ValidateInteger(data.transpose, -3, 3)
	end

	-- links between instruments and MIDI channels
	if data.channelInstruments and type(data.channelInstruments) == 'table' then
		for c, i in pairs(data.channelInstruments) do
			local channel = ValidateInteger(c, 0, 15)
			local instrument = ValidateInteger(i, 1, nInstruments)

			self.Settings.channelInstruments[channel] = instrument
		end
	end

	-- draw labels for keys
	self.Settings.drawKeyLabels = Either(isbool(data.drawKeyLabels), tobool(data.drawKeyLabels), true)
end

function MKeyboard:SaveSettings()
	local s = self.Settings

	file.Write(self.SETTINGS_FILE, util.TableToJSON({
		layout				= s.layout,
		instrument			= s.instrument,
		sheet				= s.sheet,
		velocity			= s.velocity,
		transpose			= s.transpose,
		channelInstruments	= s.channelInstruments,
		drawKeyLabels		= s.drawKeyLabels
	}, true))
end

MKeyboard.entity = nil

MKeyboard.reproduceQueue = {}
MKeyboard.transmitQueue = {}
MKeyboard.queueTimer = nil
MKeyboard.queueStart = 0

MKeyboard.shiftMode = false
MKeyboard.noteState = {}
MKeyboard.blockInput = 0

local shortcuts = {
	[KEY_TAB] =	function()
		RunConsoleCommand('keyboard_leave', MKeyboard.entity:EntIndex())
	end,

	[KEY_SPACE] = function()
		MKeyboard.HUD:ToggleExpandedBar()
	end,

	[KEY_LEFT] = function()
		MKeyboard.HUD:ChangeInstrument(-1)
	end,

	[KEY_RIGHT] = function()
		MKeyboard.HUD:ChangeInstrument(1)
	end,

	[KEY_UP] = function()
		MKeyboard.HUD:ChangeTranspose(1)
	end,

	[KEY_DOWN] = function()
		MKeyboard.HUD:ChangeTranspose(-1)
	end
}

local dontBlockBinds = {
	['+attack'] = true,
	['+attack2'] = true,
	['+duck'] = true
}

function MKeyboard:Init(ent)
	self.entity = ent
	self.blockInput = RealTime() + 0.5

	self.HUD:Init()

	hook.Add('Think', 'mkeyboard_Think', function()
		self:Think()
	end)

	hook.Add('PlayerButtonDown', 'mkeyboard_PlayerButtonDown', function(ply, button)
		if ply == LocalPlayer() and IsFirstTimePredicted() then
			self:OnButton(button, true)
		end
	end)

	hook.Add('PlayerButtonUp', 'mkeyboard_PlayerButtonUp', function(ply, button)
		if ply == LocalPlayer() and IsFirstTimePredicted() then
			self:OnButton(button, false)
		end
	end)

	hook.Add('PlayerBindPress', 'mkeyboard_PlayerBindPress', function(_, bind)
		if not dontBlockBinds[bind] then return true end
	end)

	-- Custom Chat compatibility
	hook.Add('BlockChatInput', 'mkeyboard_BlockChatInput', function()
		return true
	end)
end

function MKeyboard:Shutdown()
	self.entity = nil

	self.transmitQueue = {}
	self.queueTimer = nil

	self.shiftMode = false
	self.noteState = {}

	self.MIDI:Close()
	self.HUD:Shutdown()

	hook.Remove('Think', 'mkeyboard_Think')
	hook.Remove('PlayerButtonDown', 'mkeyboard_PlayerButtonDown')
	hook.Remove('PlayerButtonUp', 'mkeyboard_PlayerButtonUp')
	hook.Remove('PlayerBindPress', 'mkeyboard_PlayerBindPress')
	hook.Remove('BlockChatInput', 'mkeyboard_BlockChatInput')
end

function MKeyboard:NoteOn(note, velocity, isMidi, midiChannel)
	local instrument = self.Settings.instrument

	if midiChannel then
		self.HUD.channelState[midiChannel] = 1
		instrument = self.Settings.channelInstruments[midiChannel] or instrument

		if instrument == 0 then return end
	end

	local instr = self.Instruments[instrument]
	if note < instr.firstNote or note > instr.lastNote then return end

	self.entity:EmitNote(note, velocity, 80, instrument, isMidi)

	self.noteState[note] = isMidi and 4 or 3 -- see themeColors on cl_hud.lua 
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

function MKeyboard:NoteOff(note)
	self.noteState[note] = nil
end

function MKeyboard:Reproduce()
	local t = SysTime()

	-- play the networked notes, keeping the original timings
	for time, data in pairs(self.reproduceQueue) do
		if t > time then
			if IsValid(data[1]) then
				data[1]:EmitNote(data[2], data[3], 80, data[4], data[5])
			end

			self.reproduceQueue[time] = nil
		end
	end
end

function MKeyboard:TransmitQueue()
	net.Start('mkeyboard.notes', false)
	net.WriteEntity(self.entity)
	net.WriteBool(self.lastNoteWasAutomated)
	net.WriteUInt(#self.transmitQueue, 5)

	for _, params in ipairs(self.transmitQueue) do
		net.WriteUInt(params[1], 7) -- note
		net.WriteUInt(params[2], 7) -- velocity
		net.WriteUInt(params[3], 6) -- instrument
		net.WriteFloat(params[4])   -- time offset
	end

	net.SendToServer()

	table.Empty(self.transmitQueue)
	self.queueTimer = nil
end

function MKeyboard:Think()
	if not IsValid(self.entity) then
		self:Shutdown()
		return
	end

	self.MIDI:Think()

	local t = SysTime()

	-- if the queued notes are ready to be sent...
	if self.queueTimer and t > self.queueTimer then
		self:TransmitQueue()
	end
end

function MKeyboard:OnButton(button, isPressed)
	-- if gui.IsGameUIVisible() then return end

	if button == KEY_LSHIFT then
		self.shiftMode = isPressed
	end

	-- process shortcuts
	if shortcuts[button] and not isPressed then
		shortcuts[button]()
		return
	end

	if self.blockInput > RealTime() then return end

	local layoutKeys = self.Layouts[self.Settings.layout].keys

	-- process layout keys
	for idx, params in ipairs(layoutKeys) do
		-- params: key [1], note [2], type [3], label [4], require SHIFT [5], alternative key [6]

		if params[1] == button or (params[6] and params[6] == button) then
			local note = params[2] + self.Settings.transpose * 12

			if isPressed then
				if params[5] and self.shiftMode then
					self:NoteOn(note, self.Settings.velocity, false)
					break
				end

				if not params[5] and not self.shiftMode then
					self:NoteOn(note, self.Settings.velocity, false)
					break
				end
			else
				self:NoteOff(note)
			end
		end
	end
end

hook.Add('Think', 'mkeyboard_OffscreenThink', function()
	MKeyboard:Reproduce()
end)