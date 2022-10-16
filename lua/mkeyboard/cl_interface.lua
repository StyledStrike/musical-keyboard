surface.CreateFont('MKeyboard_Title', {
	size = ScrH() * 0.025, weight = 300, antialias = true, font = 'Coolvetica'
})

surface.CreateFont('MKeyboard_Key', {
	size = ScrH() * 0.02, weight = 300, antialias = true, font = 'Coolvetica'
})

surface.CreateFont('MKeyboard_Sheet', {
	size = ScrH() * 0.022, antialias = true, font = 'Roboto'
})

local setDrawColor = surface.SetDrawColor
local drawRect = surface.DrawRect
local simpleText = draw.SimpleText
local roundedBoxEx = draw.RoundedBoxEx
local langGet = language.GetPhrase

local themeColors = {
	[1] = Color(0, 0, 0, 255),
	[2] = Color(255, 255, 255, 255),
	[3] = Color(245, 163, 108),
	[4] = Color(196, 0, 226),
	[5] = Color(120, 120, 120, 255),
	[6] = Color(0, 0, 0, 240)
}

local HUD = {
	expanded = false,
	openPortName = nil,
	channelState = {},
	whiteKeyCount = 0
}

MKeyboard.HUD = HUD

-- register a "Button" type for DProperties
local DPropertyButton = {}

function DPropertyButton:Init() end

function DPropertyButton:Setup(label)
	self:Clear()

	label = label or ''

	local btn = self:Add('DButton')
	btn:Dock(FILL)
	btn:SetText(label)

	self.IsEditing = function()
		return false
	end

	self.SetEnabled = function(_, b)
		btn:SetEnabled(b)
	end

	self.SetValue = function(_, val)
		btn:SetText(val)
	end

	btn.DoClick = function()
		self.m_pRow:OnClick()
	end
end

derma.DefineControl('DProperty_Button', '', DPropertyButton, 'DProperty_Generic')

local function drawKey(x, y, w, h, state, label, label2, rounded)
	local color = themeColors[state]

	if rounded then
		roundedBoxEx(4, x, y, w, h, color, false, false, true, true)
	else
		setDrawColor(color.r, color.g, color.b, 255)
		drawRect(x, y, w, h)
	end

	if not MKeyboard.Settings.drawKeyLabels then return end

	local labelColor = themeColors[ (state == 1) and 2 or 1 ]

	if label then
		simpleText(label, 'MKeyboard_Key', x + (w * 0.5), y + h - 2,
			labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	if label2 then
		simpleText(label2, 'MKeyboard_Key', x + (w * 0.5), y + h - 22,
			labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end
end

local function drawKeyboard(x, y, h)
	local keyWidth = math.ceil(ScrW() * 0.018)
	local borderSize = math.ceil(ScrW() * 0.002)
	local infoSize = math.ceil(ScrW() * 0.016)

	local w = keyWidth * HUD.whiteKeyCount
	x = x - w * 0.5

	setDrawColor(0, 0, 0, 240)
	drawRect(x - borderSize, y - infoSize - borderSize, w + borderSize * 2, h + infoSize + borderSize * 2)

	local layoutData = MKeyboard.Layouts[MKeyboard.Settings.layout]
	local instrumentData = MKeyboard.Instruments[MKeyboard.Settings.instrument]
	local octave = MKeyboard.Settings.octave

	if octave ~= 0 then
		surface.SetFont('MKeyboard_Key')
		local offsetX = surface.GetTextSize(layoutData.name)

		surface.SetTextPos(x + offsetX + borderSize * 2, y - infoSize + borderSize)
		surface.SetTextColor(255, 208, 22)
		surface.DrawText(octave > 0 and '+' .. octave or octave)
	end

	simpleText(layoutData.name, 'MKeyboard_Key', x + borderSize, y - infoSize + borderSize, themeColors[2])
	simpleText(instrumentData.name, 'MKeyboard_Key',
		x + w - borderSize, y - infoSize + borderSize, themeColors[2], TEXT_ALIGN_RIGHT)

	local noteOffset = octave * 12
	local noteState = MKeyboard.noteState
	local minNote = instrumentData.firstNote
	local maxNote = instrumentData.lastNote

	-- draw the white keys
	local whiteKeyBorder = math.ceil(ScrW() * 0.0004)
	local keyX = x

	for _, params in ipairs(layoutData.keys) do
		if params[3] == 'b' then continue end

		local note = params[2] + noteOffset
		local state = noteState[note]

		if note < minNote or note > maxNote then
			drawKey(keyX + whiteKeyBorder, y, keyWidth - whiteKeyBorder * 2, h, 5)
		elseif state then
			drawKey(keyX + whiteKeyBorder, y, keyWidth - whiteKeyBorder * 2, h, state, params[4], params[7])
		else
			drawKey(keyX + whiteKeyBorder, y, keyWidth - whiteKeyBorder * 2, h, 2, params[4], params[7])
		end

		keyX = keyX + keyWidth
	end

	-- draw the black keys
	keyX = x
	local bWidth, bHeight = keyWidth * 0.6, h * 0.64

	for _, params in ipairs(layoutData.keys) do
		if params[3] == 'w' then
			keyX = keyX + keyWidth
			continue
		end

		local note = params[2] + noteOffset
		local state = noteState[note]

		if note < minNote or note > maxNote then
			drawKey(keyX - (bWidth * 0.5), y, bWidth, bHeight, 5)
		elseif state then
			drawKey(keyX - (bWidth * 0.5), y, bWidth, bHeight, state, params[4], params[7], true)
		else
			drawKey(keyX - (bWidth * 0.5), y, bWidth, bHeight, 1, params[4], params[7], true)
		end
	end
end

local function drawSheet(sheet, x, y)
	local oldClipping = DisableClipping(true)
	local borderSize = math.ceil(ScrW() * 0.002)
	local titleBarSize = ScrH() * 0.028
	local sheetData = MKeyboard.Sheets[sheet]

	surface.SetFont('MKeyboard_Sheet')

	local sheetW, sheetH = surface.GetTextSize(sheetData.sequence)
	local w, h = math.max(ScrW() * 0.3, sheetW + borderSize * 2), sheetH + titleBarSize * 0.5

	x = x - w * 0.5
	y = y - h

	setDrawColor(0, 0, 0, 254)
	drawRect(x, y, w, h)

	draw.DrawText(sheetData.sequence,'MKeyboard_Sheet', x + w * 0.5, y + titleBarSize, nil, TEXT_ALIGN_CENTER)
	simpleText(sheetData.title, 'MKeyboard_Title', x + w * 0.5, y + borderSize, themeColors[2], TEXT_ALIGN_CENTER)

	DisableClipping(oldClipping)
end

local function createCategoryPanel(title, parent, dock, wide, help)
	local dockPadding = ScrH() * 0.01
	local dSkin = derma.GetDefaultSkin()

	local pnl = vgui.Create('DPanel', parent)
	pnl:DockPadding(dockPadding, dockPadding, dockPadding, dockPadding)
	pnl:Dock(dock)

	if wide then
		pnl:SetWide(wide)
	end

	pnl.oldPaint = pnl.Paint

	pnl.Paint = function(s, sw, sh)
		s.oldPaint(s, sw - 4, sh)
	end

	local pnlHeader = vgui.Create('DPanel', pnl)
	pnlHeader:Dock(TOP)
	pnlHeader:SetPaintBackground(false)

	local lblTitle = vgui.Create('DLabel', pnlHeader)
	lblTitle:SetFont('MKeyboard_Key')
	lblTitle:SetText(title)
	lblTitle:SizeToContents()
	lblTitle:Dock(LEFT)
	lblTitle:SetTextColor(dSkin.Colours.Label.Dark)

	if help then
		local lblHelp = vgui.Create('DLabel', pnlHeader)
		lblHelp:SetFont('MKeyboard_Key')
		lblHelp:SetText(help)
		lblHelp:SizeToContents()
		lblHelp:Dock(RIGHT)
		lblHelp:SetTextColor(dSkin.Colours.Label.Dark)
	end

	return pnl
end

function HUD:Init()
	if not MKeyboard.MIDI.selectedPort and midi then
		self:ShowDevicesDialog()
	end

	local wide = ScrW() * 0.7
	local tall = ScrH() * 0.5

	self.frameKeyboard = vgui.Create('DFrame')
	self.frameKeyboard:SetPos((ScrW() - wide) * 0.5, ScrH() - tall * 0.5)
	self.frameKeyboard:SetSize(wide, tall)
	self.frameKeyboard:SetTitle('')
	self.frameKeyboard:SetDeleteOnClose(true)
	self.frameKeyboard:SetDraggable(false)
	self.frameKeyboard:SetSizable(false)
	self.frameKeyboard:ShowCloseButton(false)
	self.frameKeyboard:LerpPositions(1, true)

	self.frameKeyboard.OnKeyCodePressed = function(_, key)
		MKeyboard:OnButton(key, true)
	end

	self.frameKeyboard.OnKeyCodeReleased = function(_, key)
		MKeyboard:OnButton(key, false)
	end

	local helpMessage = {
		[false] = langGet('mk.help.open'),
		[true] = langGet('mk.help.close'),
	}

	self.frameKeyboard.Paint = function(_, sw, sh)
		drawKeyboard(sw * 0.5, sh * 0.1, sh * 0.22)
		roundedBoxEx(8, 0, sh * 0.4, sw, sh * 0.6, themeColors[6], true, true, false, false)

		if self.openPortName then
			simpleText(self.openPortName, 'MKeyboard_Title', sw - (sw * 0.01), sh * 0.43,
				themeColors[2], TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			simpleText(helpMessage[self.expanded], 'MKeyboard_Title', sw * 0.01, sh * 0.43,
				themeColors[2], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		else
			simpleText(helpMessage[self.expanded], 'MKeyboard_Title', sw * 0.5, sh * 0.43,
				themeColors[2], TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		local sheet = MKeyboard.Settings.sheet
		if sheet > 0 then
			drawSheet(sheet, sw * 0.5, 0)
		end
	end

	local pnlParent = vgui.Create('DPanel', self.frameKeyboard)
	pnlParent:SetPos(wide * 0.01, tall * 0.52)
	pnlParent:SetSize(wide * 0.98, tall * 0.45)
	pnlParent:DockPadding(0, 0, 0, 0)
	pnlParent:SetPaintBackground(false)

	local pnlSettings = createCategoryPanel(langGet('mk.settings'), pnlParent, LEFT, wide * 0.3)

	local propertyPanel = vgui.Create('DProperties', pnlSettings)
	propertyPanel:Dock(FILL)
	propertyPanel:DockMargin(0, 8, 0, 0)

	local layoutValues = {}

	for k, v in ipairs(MKeyboard.Layouts) do
		layoutValues[v.name] = k
	end

	local rLayouts = propertyPanel:CreateRow(langGet('mk.vkeys'), langGet('mk.layout'))
	rLayouts:Setup('Combo', {
		text = 'Select a layout...',
		values = layoutValues
	})

	rLayouts:SetValue(MKeyboard.Settings.layout)

	rLayouts.DataChanged = function(_, val)
		MKeyboard.Settings.layout = val
		MKeyboard.Settings.sheet = 0

		local limits = MKeyboard.Layouts[val].octaveLimits
		MKeyboard.Settings.octave = math.Clamp(MKeyboard.Settings.octave, limits.min, limits.max)
		MKeyboard:SaveSettings()

		self.rowOctave:Setup('Int', {min = limits.min, max = limits.max})
		self.rowOctave:SetValue(MKeyboard.Settings.octave)
		self:UpdateLayout()
	end

	local rDrawLabels = propertyPanel:CreateRow(langGet('mk.vkeys'), langGet('mk.vkeys.labels'))
	rDrawLabels:Setup('Boolean')
	rDrawLabels:SetValue(MKeyboard.Settings.drawKeyLabels)

	rDrawLabels.DataChanged = function(_, val)
		MKeyboard.Settings.drawKeyLabels = tobool(val)
		MKeyboard:SaveSettings()
	end

	local rVelocity = propertyPanel:CreateRow(langGet('mk.vkeys'), langGet('mk.vkeys.velocity'))
	rVelocity:Setup('Int', {min = 1, max = 127})
	rVelocity:SetValue(MKeyboard.Settings.velocity)

	rVelocity.DataChanged = function(_, val)
		MKeyboard.Settings.velocity = math.ceil(val)
	end

	local octaveLimits = MKeyboard.Layouts[MKeyboard.Settings.layout].octaveLimits

	self.rowOctave = propertyPanel:CreateRow(langGet('mk.vkeys'), langGet('mk.vkeys.octave'))
	self.rowOctave:Setup('Int', {min = octaveLimits.min, max = octaveLimits.max})
	self.rowOctave:SetValue(MKeyboard.Settings.octave)

	self.rowOctave.DataChanged = function(_, val)
		if val < 0 then
			MKeyboard.Settings.octave = math.ceil(val)
		else
			MKeyboard.Settings.octave = math.floor(val)
		end

		MKeyboard:SaveSettings()
		MKeyboard:NoteOffAll()
	end

	local rDevices = propertyPanel:CreateRow('MIDI', langGet('mk.midi.device'))
	rDevices:Setup('Button', langGet('mk.midi.device.choose'))

	if midi then
		local rChannels = propertyPanel:CreateRow('MIDI', langGet('mk.midi.channels'))
		rChannels:Setup('Button', langGet('mk.midi.channels.setup'))

		rChannels.OnClick = function()
			self:ShowChannelsDialog()
		end

		rDevices.OnClick = function()
			self:ShowDevicesDialog()
		end

		if table.Count(midi.GetPorts()) == 0 then
			rDevices:SetValue(langGet('mk.midi.nodevices'))
			rDevices:SetEnabled(false)
		end

		local midiTranspose = propertyPanel:CreateRow('MIDI', langGet('mk.vkeys.transpose'))
		midiTranspose:Setup('Int', {min = -48, max = 48})
		midiTranspose:SetValue(MKeyboard.Settings.midiTranspose)

		midiTranspose.DataChanged = function(_, val)
			MKeyboard.Settings.midiTranspose = math.Round(val)
			MKeyboard:SaveSettings()
			MKeyboard:NoteOffAll()
		end
	else
		rDevices:SetValue(langGet('mk.midi.nomodule'))
		rDevices:SetEnabled(false)

		local rInstallHelp = propertyPanel:CreateRow('MIDI', 'Module installation')
		rInstallHelp:Setup('Button', langGet('mk.midi.guide'))

		rInstallHelp.OnClick = function()
			gui.OpenURL('https://steamcommunity.com/workshop/filedetails/discussion/2656563609/3199240042192880687/')
			self:ToggleExpandedBar()
		end
	end

	local pnlInstruments = createCategoryPanel(langGet('mk.instruments'),
		pnlParent, FILL, nil, langGet('mk.instruments.help'))

	self.instrList = vgui.Create('DListView', pnlInstruments)
	self.instrList:Dock(FILL)
	self.instrList:DockMargin(0, 8, 0, 0)
	self.instrList:AddColumn(langGet('mk.instruments'))
	self.instrList:SetMultiSelect(false)
	self.instrList:SetHideHeaders(true)
	self.instrList:SetSortable(false)

	for i, v in ipairs(MKeyboard.Instruments) do
		self.instrList:AddLine(i .. ' - ' .. v.name)
	end

	self.instrList:SelectItem( self.instrList:GetLine(MKeyboard.Settings.instrument) )

	self.instrList.OnRowSelected = function(_, index, _)
		MKeyboard.Settings.instrument = index
		MKeyboard:SaveSettings()
	end

	local pnlSheets = createCategoryPanel(langGet('mk.sheets'), pnlParent, RIGHT, wide * 0.3)

	self.sheetList = vgui.Create('DListView', pnlSheets)
	self.sheetList:Dock(FILL)
	self.sheetList:DockMargin(0, 8, 0, 0)
	self.sheetList:AddColumn(langGet('mk.sheets'))
	self.sheetList:SetMultiSelect(false)
	self.sheetList:SetHideHeaders(true)
	self.sheetList:SetSortable(false)

	self:UpdateLayout()
end

function HUD:Shutdown()
	self.expanded = false

	if IsValid(self.frameKeyboard) then
		self.frameKeyboard:Close()
	end

	if IsValid(self.frameDevices) then
		self.frameDevices:Close()
	end

	if IsValid(self.frameChannels) then
		self.frameChannels:Close()
	end
end

function HUD:UpdateLayout()
	self.whiteKeyCount = 0

	local layout = MKeyboard.Settings.layout
	local layoutKeys = MKeyboard.Layouts[layout].keys

	for idx, params in ipairs(layoutKeys) do
		if params[3] == 'w' then
			self.whiteKeyCount = self.whiteKeyCount + 1
		end
	end

	self.sheetList:Clear()

	local shouldSelect = self.sheetList:AddLine(langGet('mk.sheets.hidden'))
	shouldSelect._sheetIndex = 0

	for k, v in ipairs(MKeyboard.Sheets) do
		if v.layout == layout then
			local line = self.sheetList:AddLine(v.title)
			line._sheetIndex = k

			if k == MKeyboard.Settings.sheet then
				shouldSelect = line
			end
		end
	end

	self.sheetList:SelectItem(shouldSelect)

	self.sheetList.OnRowSelected = function(_, _, line)
		MKeyboard.Settings.sheet = line._sheetIndex
		MKeyboard:SaveSettings()
	end
end

function HUD:ChangeInstrument(to)
	local newInstrument = MKeyboard.Settings.instrument + to

	if newInstrument < 1 then
		newInstrument = #MKeyboard.Instruments
	end

	if newInstrument > #MKeyboard.Instruments then
		newInstrument = 1
	end

	MKeyboard.Settings.instrument = newInstrument

	local line = self.instrList:GetLine(newInstrument)

	self.instrList:ClearSelection()
	self.instrList:SelectItem(line)
	self.instrList.VBar:AnimateTo(line:GetY() - self.instrList:GetTall() * 0.5, 0.25, 0, -1)

	MKeyboard:SaveSettings()
end

function HUD:AddOctave(value)
	local newOctave = MKeyboard.Settings.octave + value
	local limits = MKeyboard.Layouts[MKeyboard.Settings.layout].octaveLimits

	if newOctave < limits.min then
		newOctave = limits.max
	end

	if newOctave > limits.max then
		newOctave = limits.min
	end

	MKeyboard.Settings.octave = newOctave
	MKeyboard.noteState = {}

	self:UpdateLayout()
	self.rowOctave:SetValue(newOctave)

	MKeyboard:SaveSettings()
end

function HUD:ToggleExpandedBar()
	self.expanded = not self.expanded

	-- I might have found a bug here. Basically, cant get the panel position
	-- after calling LerpPositions without playing the animation first
	-- local x = self.frameKeyboard:GetX()

	local x = (ScrW() - ScrW() * 0.7) * 0.5
	local tall = self.frameKeyboard:GetTall()

	if self.expanded then
		self.frameKeyboard:SetPos(x, ScrH() - tall)
		self.frameKeyboard:MakePopup()
	else
		self.frameKeyboard:SetPos(x, ScrH() - tall * 0.49)
		self.frameKeyboard:SetMouseInputEnabled(false)
		self.frameKeyboard:SetKeyboardInputEnabled(false)
	end
end

function HUD:SetMidiPortName(name)
	if name then
		if string.len(name) > 28 then
			name = string.sub(name, 1, 25) .. '...'
		end

		self.openPortName = string.format(langGet('mk.midi.connected'), name)
	else
		self.openPortName = nil
	end
end

function HUD:ShowDevicesDialog()
	if IsValid(self.frameDevices) then
		self.frameDevices:Close()
	end

	if not midi then return end

	local midiPorts = midi.GetPorts()
	if table.Count(midiPorts) == 0 then return end

	if midi.IsOpened() then
		MKeyboard.MIDI:Close()
		MKeyboard.MIDI.selectedPort = nil
	end

	self.frameDevices = vgui.Create('DFrame')
	self.frameDevices:SetSize(300, 130)
	self.frameDevices:SetTitle(langGet('mk.midi.device.choose'))
	self.frameDevices:SetVisible(true)
	self.frameDevices:SetDraggable(true)
	self.frameDevices:ShowCloseButton(true)
	self.frameDevices:SetDeleteOnClose(true)
	self.frameDevices:Center()
	self.frameDevices:MakePopup()

	local startTime = SysTime()
	local oldPaint = self.frameDevices.Paint

	self.frameDevices.Paint = function(s, sw, sh)
		Derma_DrawBackgroundBlur(s, startTime)
		oldPaint(s, sw, sh)
	end

	local labelHelp = vgui.Create('DLabel', self.frameDevices)
	labelHelp:SetPos(10, 40)
	labelHelp:SetSize(280, 40)
	labelHelp:SetText(string.format(langGet('mk.midi.found'), tostring(table.Count(midiPorts))))

	local comboDevices = vgui.Create('DComboBox', self.frameDevices)
	comboDevices:SetPos(10, 90)
	comboDevices:SetSize(280, 20)
	comboDevices:SetValue(langGet('mk.midi.select'))

	for k, v in pairs(midiPorts) do
		comboDevices:AddChoice('[' .. k .. '] ' .. v)
	end

	comboDevices.OnSelect = function(_, index, _)
		MKeyboard.MIDI.selectedPort = index - 1
		self.frameDevices:Close()
	end
end

function HUD:ShowChannelsDialog()
	if IsValid(self.frameChannels) then
		self.frameChannels:Close()
		return
	end

	local tall = math.min(610, ScrH() * 0.6)

	self.frameChannels = vgui.Create('DFrame')
	self.frameChannels:SetSize(400, tall)
	self.frameChannels:SetTitle(langGet('mk.channels'))
	self.frameChannels:SetVisible(true)
	self.frameChannels:SetSizable(true)
	self.frameChannels:SetDraggable(true)
	self.frameChannels:ShowCloseButton(true)
	self.frameChannels:SetDeleteOnClose(true)
	self.frameChannels:SetPos(ScrW() - self.frameChannels:GetWide(), 0)
	self.frameChannels:MakePopup()

	self.frameChannels.OnKeyCodePressed = function(_, key)
		MKeyboard:OnButton(key, true)
	end

	self.frameChannels.OnKeyCodeReleased = function(_, key)
		MKeyboard:OnButton(key, false)
	end

	local scrollChannels = vgui.Create('DScrollPanel', self.frameChannels)
	scrollChannels:Dock(FILL)

	local function paintChannelPanel(s, sw, sh)
		setDrawColor(0, 0, 0, 255)
		drawRect(0, 0, sw, sh)

		setDrawColor(50, 50, 50, 255)
		drawRect(4, 4, 8, sh - 8)

		self.channelState[s.channel] = Lerp(FrameTime() * 8, self.channelState[s.channel], 0)
		setDrawColor(themeColors[4].r, themeColors[4].g, themeColors[4].b, 255 * self.channelState[s.channel])
		drawRect(4, 4, 8, sh - 8)
	end

	local function selectChannelInst(s, _, _, idx)
		if idx == -1 then
			MKeyboard.Settings.channelInstruments[s.channel] = nil
		else
			MKeyboard.Settings.channelInstruments[s.channel] = idx
		end

		MKeyboard:SaveSettings()
	end

	for c = 0, 15 do
		self.channelState[c] = 0

		local panelChannel = vgui.Create('DPanel', scrollChannels)
		panelChannel:SetSize(wide, 32)
		panelChannel:Dock(TOP)
		panelChannel:DockMargin(0, 0, 0, 4)

		panelChannel.channel = c
		panelChannel.Paint = paintChannelPanel

		local lblIndex = vgui.Create('DLabel', panelChannel)
		lblIndex:SetFont('Trebuchet24')
		lblIndex:SetTextColor(themeColors[2])
		lblIndex:SetText('#' .. (c + 1))
		lblIndex:SetWide(50)
		lblIndex:Dock(LEFT)
		lblIndex:DockMargin(20, 0, 0, 0)

		local comboInstr = vgui.Create('DComboBox', panelChannel)
		comboInstr:SetSortItems(false)
		comboInstr:AddChoice(langGet('mk.channels.usecurrent'), -1, true)
		comboInstr:AddChoice(langGet('mk.channels.mute'), 0)
		comboInstr:AddSpacer()
		comboInstr:Dock(FILL)

		local myInstrument = MKeyboard.Settings.channelInstruments[c] or -1

		for idx, v in ipairs(MKeyboard.Instruments) do
			comboInstr:AddChoice(v.name, idx, idx == myInstrument)
		end

		comboInstr.channel = c
		comboInstr.OnSelect = selectChannelInst
	end
end