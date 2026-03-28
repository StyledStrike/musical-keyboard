local colors = StyledTheme.colors
local ScaleSize = StyledTheme.ScaleSize
local Config = MKeyboard.Config

local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local DrawSimpleText = draw.SimpleText

local PANEL = {}

local function CreateDockedPanel( title, parent, dock, width )
    local panel = vgui.Create( "Panel", parent )
    panel:DockPadding( 0, 0, 0, 0 )
    panel:Dock( dock )

    if width then
        panel:SetWide( width )
    end

    local panelHeader = vgui.Create( "Panel", panel )
    panelHeader:SetTall( ScaleSize( 26 ) )
    panelHeader:Dock( TOP )

    panelHeader.Paint = function( _, w, h )
        SetColor( colors.panelDisabledBackground )
        DrawRect( 0, 0, w, h )
    end

    local labelTitle = vgui.Create( "DLabel", panelHeader )
    labelTitle:SetText( title )
    labelTitle:SetFont( "MKeyboard_Small" )
    labelTitle:SetTextColor( colors.labelText )
    labelTitle:SetContentAlignment( 4 )
    labelTitle:SizeToContents()
    labelTitle:Dock( FILL )
    labelTitle:DockMargin( ScaleSize( 4 ), 0, 0, 0 )

    return panel
end

function PANEL:Init()
    local frameW, frameH = ScaleSize( 1200 ), ScaleSize( 500 )

    self:NoClipping( true )
    self:SetSize( frameW, frameH )
    self:SetTitle( "" )
    self:SetDeleteOnClose( true )
    self:SetDraggable( false )
    self:SetSizable( false )
    self:ShowCloseButton( false )

    self.pianoPanel = vgui.Create( "MKeyboard_PianoRoll", self )
    self.statusPanel = vgui.Create( "Panel", self )
    self.dockPanel = vgui.Create( "Panel", self )

    local menuOpenTips = {
        [false] = language.GetPhrase( "musicalk.help.open" ),
        [true] = language.GetPhrase( "musicalk.help.close" )
    }

    self.statusPanel.Paint = function( _, w, h )
        if self.statusText then
            DrawSimpleText( self.statusText, "MKeyboard_Large", w - ( w * 0.01 ), h * 0.5, colors.labelText, 2, 1 )
            DrawSimpleText( menuOpenTips[self.isExpanded], "MKeyboard_Large", w * 0.01, h * 0.5, colors.labelText, 0, 1 )
        else
            DrawSimpleText( menuOpenTips[self.isExpanded], "MKeyboard_Large", w * 0.5, h * 0.5, colors.labelText, 1, 1 )
        end
    end

    self:SetExpanded( false, true )
    self:SetStatusText( nil )

    self.selectedLayoutIndex = 1
    self.layoutShiftedButtonNotes = {}
    self.layoutUnshiftedButtonNotes = {}

    -- Create the docked bottom panels
    self.settingsPanel = CreateDockedPanel( "#musicalk.settings", self.dockPanel, LEFT, ScaleSize( 350 ) )
    self.instrumentsPanel = CreateDockedPanel( "#musicalk.instruments", self.dockPanel, FILL )
    self.sheetsPanel = CreateDockedPanel( "#musicalk.sheets", self.dockPanel, RIGHT, ScaleSize( 350 ) )

    local margin = ScaleSize( 10 )

    self.settingsPanel:DockMargin( margin, 0, margin * 0.5, margin )
    self.instrumentsPanel:DockMargin( margin * 0.5, 0, margin * 0.5, margin )
    self.sheetsPanel:DockMargin( margin * 0.5, 0, margin, margin )

    --[[
        Populate the Settings panel
    ]]

    local settingsScroll = vgui.Create( "DScrollPanel", self.settingsPanel )
    settingsScroll:Dock( FILL )

    self.settingsScroll = settingsScroll
    StyledTheme.Apply( settingsScroll )

    local ROW_HEIGHT = ScaleSize( 24 )

    local PaintSeparator = function( _, w, h )
        SetColor( 0, 0, 0, 255 )
        DrawRect( 0, 0, w, h )
    end

    local AddSeparator = function( text, negateTopScrollMargin )
        local sideMargin = -StyledTheme.dimensions.scrollPadding
        local topMargin = negateTopScrollMargin and sideMargin or ScaleSize( 4 )

        local parent = vgui.Create( "Panel", settingsScroll )
        parent:SetTall( ROW_HEIGHT )
        parent:DockMargin( sideMargin, topMargin, sideMargin, ScaleSize( 4 ) )
        parent:Dock( TOP )
        parent.Paint = PaintSeparator

        local label = vgui.Create( "DLabel", parent )
        label:SetText( text )
        label:SetContentAlignment( 5 )
        label:Dock( FILL )

        StyledTheme.Apply( label )
        label:SetFont( "StyledTheme_Tiny" )
    end

    AddSeparator( "#musicalk.vkeys", true )

    -- Layouts list
    local layoutOptions, selectedLayoutIndex = {}, 0

    for index, layout in ipairs( MKeyboard.layouts ) do
        layoutOptions[#layoutOptions + 1] = layout.name
        
        if layout.id == Config.selectedLayoutId then
            selectedLayoutIndex = index
        end
    end

    local comboKbLayout, labelKbLayout, panelKbLayout = StyledTheme.CreateFormCombo( settingsScroll, "#musicalk.layout", layoutOptions, selectedLayoutIndex, function( index )
        local layout = MKeyboard.layouts[index]
        if layout then self:SetKeyboardLayout( layout.id ) end
    end )

    panelKbLayout:SetTall( ROW_HEIGHT )
    labelKbLayout:SetWide( ScaleSize( 160 ) )
    labelKbLayout:SetFont( "MKeyboard_Small" )
    comboKbLayout:SetFont( "MKeyboard_Small" )

    local FormSliderLayout = function( s )
        s.Label:SetWide( ScaleSize( 160 ) )
    end

    -- Keyboard piano velocity
    local sliderKeyboardVelocity = StyledTheme.CreateFormSlider( settingsScroll, "#musicalk.vkeys.velocity", Config.keyboardVelocity, 0, 127, 0, function( value )
        Config.keyboardVelocity = value
        Config:Save()
    end )

    sliderKeyboardVelocity.PerformLayout = FormSliderLayout
    sliderKeyboardVelocity.Label:SetFont( "MKeyboard_Small" )

    -- Keyboard piano transpose
    local sliderKeyboardTranspose = StyledTheme.CreateFormSlider( settingsScroll, "#musicalk.vkeys.transpose", Config.keyboardTranspose, -48, 48, 0, function( value )
        self:SetKeyboardTranspose( value )
    end )

    self.sliderKeyboardTranspose = sliderKeyboardTranspose
    sliderKeyboardTranspose.PerformLayout = FormSliderLayout
    sliderKeyboardTranspose.Label:SetFont( "MKeyboard_Small" )

    -- Should labels be visible on the piano roll?
    local toggleLabels = StyledTheme.CreateFormToggle( settingsScroll, "#musicalk.vkeys.labels", Config.drawButtonLabels, function( value )
        Config.drawButtonLabels = value
        Config:Save()
    end )

    toggleLabels:SetTall( ROW_HEIGHT )
    toggleLabels:SetFont( "MKeyboard_Small" )

    -- Should sheets be sorted alphabetically?
    local toggleSortSheets = StyledTheme.CreateFormToggle( settingsScroll, "#musicalk.vkeys.sorting", Config.sortSheetsAlphabetically, function( value )
        Config.sortSheetsAlphabetically = value
        Config:Save()

        self:UpdateSheetsList()
    end )

    toggleSortSheets:SetTall( ROW_HEIGHT )
    toggleSortSheets:SetFont( "MKeyboard_Small" )

    -- MIDI settings
    AddSeparator( "MIDI" )

    self:UpdateMIDIDeviceSection()

    --[[
        Populate the Instruments panel
    ]]

    local ListLineUpdateColors = function( s )
        s:SetTextStyleColor( colors.labelText )
    end
    
    local instrumentsList = vgui.Create( "DListView", self.instrumentsPanel )
    instrumentsList:AddColumn( "#musicalk.instruments" )
    instrumentsList:SetDataHeight( ScaleSize( 22 ) )
    instrumentsList:SetHideHeaders( true )
    instrumentsList:SetMultiSelect( false )
    instrumentsList:SetSortable( false )
    instrumentsList:Dock( FILL )

    self.instrumentsList = instrumentsList
    StyledTheme.Apply( instrumentsList, "DScrollPanel" )

    for index, instrument in ipairs( MKeyboard.instruments ) do
        local line = instrumentsList:AddLine( index .. " - " .. instrument.name )
        line.Columns[1].UpdateColours = ListLineUpdateColors
        line.Columns[1]:SetFont( "MKeyboard_Small" )
    end

    instrumentsList:SelectItem( instrumentsList:GetLine( Config.selectedInstrumentIndex ) )

    instrumentsList.OnRowSelected = function( _, index )
        self:SetKeyboardInstrument( index )
    end

    --[[
        Populate the Sheets panel
    ]]

    local sheetsList = vgui.Create( "DListView", self.sheetsPanel )
    sheetsList:AddColumn( "#musicalk.sheets" )
    sheetsList:SetDataHeight( ScaleSize( 22 ) )
    sheetsList:SetHideHeaders( true )
    sheetsList:SetMultiSelect( false )
    sheetsList:SetSortable( false )
    sheetsList:Dock( FILL )

    StyledTheme.Apply( sheetsList, "DScrollPanel" )

    self.sheetsList = sheetsList
    self:UpdateSheetsList()

    sheetsList.OnRowSelected = function( _, _, line )
        Config.selectedSheetIndex = line._sheetIndex
        Config:Save()
    end
end

function PANEL:OnNotePressed( _channelIndex, _note, _velocity, _instrumentIndex, _isAutomated ) end
function PANEL:OnNoteReleased( _channelIndex, _note ) end
function PANEL:OnReleaseAllNotes() end

function PANEL:OnRemove()

    if IsValid( self.frameDevices ) then
        self.frameDevices:Close()
    end

    if IsValid( self.frameChannels ) then
        self.frameChannels:Close()
    end
end

function PANEL:PerformLayout( w, h )
    local pianoH = h * 0.3
    local statusH = h * 0.1

    self.pianoPanel:SetSize( w, pianoH )
    self.statusPanel:SetSize( w, statusH )
    self.dockPanel:SetSize( w, h - pianoH - statusH )

    self.pianoPanel:SetPos( 0, 0 )
    self.statusPanel:SetPos( 0, pianoH )
    self.dockPanel:SetPos( 0, pianoH + statusH )
end

function PANEL:ToggleExpanded()
    self:SetExpanded( not self.isExpanded )
end

function PANEL:SetStatusText( statusText )
    self.statusText = statusText
end

function PANEL:SetKeyboardLayout( layoutId )
    layoutId = layoutId or Config.selectedLayoutId

    local layout, index = MKeyboard:GetLayoutById( layoutId )
    if not layout then return end

    Config.selectedLayoutId = layoutId
    Config:Save()

    -- Update button-to-note lookup tables
    local shiftedButtonNotes = {}
    local unshiftedButtonNotes = {}

    for _, v in ipairs( layout.keys ) do
        -- v.button, v.altButton,  v.requiresShift

        if v.requiresShift then
            shiftedButtonNotes[v.button] = v.note

            if v.altButton then
                shiftedButtonNotes[v.altButton] = v.note
            end
        else
            unshiftedButtonNotes[v.button] = v.note

            if v.altButton then
                unshiftedButtonNotes[v.altButton] = v.note
            end
        end
    end

    self.selectedLayoutIndex = index
    self.layoutShiftedButtonNotes = shiftedButtonNotes
    self.layoutUnshiftedButtonNotes = unshiftedButtonNotes

    self.pianoPanel:SetButtonLayout( Config.selectedLayoutId, Config.keyboardTranspose )
    self.pianoPanel.layoutName = language.GetPhrase( layout.name )

    self:UpdateSheetsList()
    self:OnReleaseAllNotes()
end

function PANEL:UpdateSheetsList()
    local ListLineUpdateColors = function( s )
        s:SetTextStyleColor( colors.labelText )
    end

    self.sheetsList:Clear()

    local layout = MKeyboard.layouts[self.selectedLayoutIndex]
    local layoutId = layout and layout.id

    local noneLine = self.sheetsList:AddLine( StyledTheme.GetUpperLanguagePhrase( "none" ) )
    noneLine._sheetIndex = 0
    noneLine.Columns[1]:SetFont( "MKeyboard_Small" )
    noneLine.Columns[1].UpdateColours = ListLineUpdateColors

    local selectedLine = noneLine
    local iterator = Config.sortSheetsAlphabetically and SortedPairsByMemberValue or ipairs

    for index, sheet in iterator( MKeyboard.sheets, "title" ) do
        if sheet.layoutId == layoutId then
            local line = self.sheetsList:AddLine( sheet.title )
            line._sheetIndex = index
            line.Columns[1]:SetFont( "MKeyboard_Small" )
            line.Columns[1].UpdateColours = ListLineUpdateColors

            if index == Config.selectedSheetIndex then
                selectedLine = line
            end
        end
    end

    self.sheetsList:SelectItem( selectedLine )
end

function PANEL:UpdateMIDIDeviceSection()
    if IsValid( self.buttonSelectMidiDevice ) then
        self.buttonSelectMidiDevice:Remove()
    end

    if IsValid( self.buttonSetupMidiChannels ) then
        self.buttonSetupMidiChannels:Remove()
    end

    if IsValid( self.buttonSetupMidiChannels ) then
        self.buttonSetupMidiChannels:Remove()
    end

    if IsValid( self.sliderMidiTranspose ) then
        self.sliderMidiTranspose:Remove()
    end

    local ROW_HEIGHT = ScaleSize( 24 )

    local buttonSelectMidiDevice = StyledTheme.CreateFormButton( self.settingsScroll, "#none", function() end )
    buttonSelectMidiDevice:SetFont( "MKeyboard_Small" )
    buttonSelectMidiDevice:SetTall( ROW_HEIGHT )
    self.buttonSelectMidiDevice = buttonSelectMidiDevice

    if not MKeyboard.MIDI then
        buttonSelectMidiDevice:SetEnabled( true )
        buttonSelectMidiDevice:SetText( "#musicalk.midi.guide" )

        buttonSelectMidiDevice.DoClick = function()
            MKeyboard:Leave()
            gui.OpenURL( MKeyboard.URL_MIDI_GUIDE )
        end

        return
    end

    if #MKeyboard.MIDI.GetDevices() == 0 then
        buttonSelectMidiDevice:SetEnabled( false )
        buttonSelectMidiDevice:SetText( "#musicalk.midi.nodevices" )

        return
    end

    buttonSelectMidiDevice:SetText( "#musicalk.midi.device.choose" )

    buttonSelectMidiDevice.DoClick = function()
        self:OpenMIDIDevicesDialog()
    end

    local buttonSetupMidiChannels = StyledTheme.CreateFormButton( self.settingsScroll, "#musicalk.midi.channels.setup", function()
        self:OpenMIDIChannelsDialog()
    end )

    buttonSetupMidiChannels:SetFont( "MKeyboard_Small" )
    buttonSetupMidiChannels:SetTall( ROW_HEIGHT )
    self.buttonSetupMidiChannels = buttonSetupMidiChannels

    -- MIDI velocity
    local sliderMidiTranspose = StyledTheme.CreateFormSlider( self.settingsScroll, "#musicalk.vkeys.transpose", Config.midiTranspose, -48, 48, 0, function( value )
        Config.midiTranspose = value
        Config:Save()

        self:OnReleaseAllNotes()
    end )

    sliderMidiTranspose.Label:SetFont( "MKeyboard_Small" )
    self.sliderMidiTranspose = sliderMidiTranspose

    sliderMidiTranspose.PerformLayout = function( s )
        s.Label:SetWide( ScaleSize( 160 ) )
    end
end

function PANEL:SetKeyboardInstrument( instrumentIndex )
    instrumentIndex = instrumentIndex or Config.selectedInstrumentIndex

    local instrument = MKeyboard.instruments[instrumentIndex]
    if not instrument then return end

    Config.selectedInstrumentIndex = instrumentIndex
    Config:Save()

    self.pianoPanel.instrumentName = instrument.name
    self:OnReleaseAllNotes()
end

function PANEL:SetKeyboardTranspose( transpose )
    transpose = math.Clamp( transpose or Config.keyboardTranspose, -48, 48 )

    Config.keyboardTranspose = transpose
    Config:Save()

    self.pianoPanel:SetButtonLayout( Config.selectedLayoutId, Config.keyboardTranspose )
    self.sliderKeyboardTranspose:SetValue( transpose )
    self:OnReleaseAllNotes()
end

function PANEL:SwitchInstrument( offset )
    local newInstrument = Config.selectedInstrumentIndex + offset

    if newInstrument < 1 then
        newInstrument = #MKeyboard.instruments

    elseif newInstrument > #MKeyboard.instruments then
        newInstrument = 1
    end

    self:SetKeyboardInstrument( newInstrument )

    local line = self.instrumentsList:GetLine( newInstrument )

    self.instrumentsList:ClearSelection()
    self.instrumentsList:SelectItem( line )
    self.instrumentsList.VBar:AnimateTo( line:GetY() - self.instrumentsList:GetTall() * 0.5, 0.25, 0, -1 )
end

function PANEL:SetExpanded( isExpanded, doNotAnimate )
    self.isExpanded = isExpanded
    self:InvalidateLayout( true )

    if isExpanded then
        self:MakePopup()
    else
        self:SetMouseInputEnabled( false )
        self:SetKeyboardInputEnabled( false )
    end

    local w, h = self:GetSize()
    local x = ( ScrW() - w ) * 0.5
    local y = ScrH() - ( isExpanded and h or self.pianoPanel:GetTall() + self.statusPanel:GetTall() )

    if doNotAnimate then
        self:SetPos( x, y )
    else
        self:Stop()
        self:MoveTo( x, y, 0.3, 0, 0.5 )
    end
end

function PANEL:PressNote( channelIndex, note, velocity, instrumentIndex, isAutomated  )
    instrumentIndex = instrumentIndex or Config.selectedInstrumentIndex
    self:OnNotePressed( channelIndex, note, velocity, instrumentIndex, isAutomated )
end

function PANEL:ReleaseNote( channelIndex, note )
    self:OnNoteReleased( channelIndex, note )
end

function PANEL:OnKeyboardPressButton( button )
    local note = input.IsShiftDown() and self.layoutShiftedButtonNotes[button] or self.layoutUnshiftedButtonNotes[button]
    if not note then return end

    note = note + Config.keyboardTranspose

    self:PressNote( 1, note, Config.keyboardVelocity )
end

function PANEL:OnKeyboardReleaseButton( button )
    local note = self.layoutShiftedButtonNotes[button]

    if note then
        self:ReleaseNote( 1, note + Config.keyboardTranspose )
    end

    note = self.layoutUnshiftedButtonNotes[button]

    if note then
        self:ReleaseNote( 1, note + Config.keyboardTranspose )
    end
end

function PANEL:Paint( w, h )
    local pianoH = self.pianoPanel:GetTall()

    draw.RoundedBoxEx( ScaleSize( 8 ), 0, pianoH, w, h - pianoH, colors.panelBackground, true, true, false, false )

    if Config.selectedSheetIndex > 0 then
        self:PaintSheet( Config.selectedSheetIndex )
    end
end

local DrawRoundedBoxEx = draw.RoundedBoxEx

function PANEL:PaintSheet( sheedIndex )
    local data = MKeyboard.sheets[sheedIndex]
    if not data then return end

    surface.SetFont( "StyledTheme_Small" )

    local sequence = data.getSequence()
    local sheetW, sheetH = surface.GetTextSize( sequence )

    local padding = ScaleSize( 6 )
    local titleH = ScaleSize( 30 )

    local w = math.max( ScrW() * 0.3, sheetW + padding * 2 )
    local h = sheetH + titleH + padding * 2

    local borderRadius = ScaleSize( 8 )
    local x, y = ( self:GetWide() - w ) * 0.5, - h

    DrawRoundedBoxEx( borderRadius, x, y, w, h, colors.entryBackground, true, true, true, true )
    DrawRoundedBoxEx( borderRadius, x, y, w, titleH, colors.entryBorder, true, true, false, false )

    draw.DrawText( sequence, "StyledTheme_Small", x + w * 0.5, y + titleH + padding, colors.labelText, 1 )
    DrawSimpleText( data.title, "MKeyboard_Large", x + w * 0.5, y + titleH * 0.5, colors.labelText, 1, 1 )
end

function PANEL:OpenMIDIDevicesDialog()
    if IsValid( self.frameDevices ) then
        self.frameDevices:Close()
    end

    if not MKeyboard.MIDI then return end

    local devices = MKeyboard.MIDI.GetDevices()
    if #devices < 1 then return end

    MKeyboard.MIDI:Close()

    local hint = string.format(
        language.GetPhrase( "musicalk.midi.found" ),
        tostring( #devices )
    )

    self.frameDevices = vgui.Create( "DFrame" )
    self.frameDevices:SetTitle( hint )
    self.frameDevices:SetSize( ScaleSize( 500 ), ScaleSize( 200 ) )
    self.frameDevices:SetVisible( true )
    self.frameDevices:SetDraggable( true )
    self.frameDevices:ShowCloseButton( true )
    self.frameDevices:SetDeleteOnClose( true )
    self.frameDevices:SetBackgroundBlur( true )
    self.frameDevices:Center()
    self.frameDevices:MakePopup()

    StyledTheme.Apply( self.frameDevices )

    local combo = vgui.Create( "DComboBox", self.frameDevices )
    combo:SetSortItems( false )
    combo:Dock( TOP )
    combo:DockMargin( 0, ScaleSize( 10 ), 0, 0 )

    for _, device in ipairs( devices ) do
        combo:AddChoice( device.name )
    end

    StyledTheme.Apply( combo )

    local buttonSelect = vgui.Create( "DButton", self.frameDevices )
    buttonSelect:SetText( "#musicalk.midi.device.choose"  )
    buttonSelect:SetEnabled( false )
    buttonSelect:Dock( TOP )
    buttonSelect:DockMargin( 0, ScaleSize( 10 ), 0, 0 )

    StyledTheme.Apply( buttonSelect )

    local selectedPort

    buttonSelect.DoClick = function()
        self.frameDevices:Close()
        MKeyboard.MIDI:SelectPort( selectedPort )
    end

    combo.OnSelect = function( _, index )
        buttonSelect:SetEnabled( true )
        selectedPort = devices[index].port
    end

    self.frameDevices:InvalidateLayout( true )
    self.frameDevices:SizeToChildren( false, true )
end

function PANEL:OpenMIDIChannelsDialog()
    if IsValid( self.frameChannels ) then
        self.frameChannels:Close()
    end

    local frameW, frameH = ScaleSize( 400 ), ScaleSize( 600 )

    self.frameChannels = vgui.Create( "DFrame" )
    self.frameChannels:SetSize( frameW, frameH )
    self.frameChannels:SetTitle( "#musicalk.channels" )
    self.frameChannels:SetVisible( true )
    self.frameChannels:SetSizable( true )
    self.frameChannels:SetDraggable( true )
    self.frameChannels:ShowCloseButton( true )
    self.frameChannels:SetDeleteOnClose( true )
    self.frameChannels:SetPos( ScrW() - frameW, frameH * 0.5 )
    self.frameChannels:MakePopup()

    StyledTheme.Apply( self.frameChannels )

    -- Passthrough button events while this panel is focused
    self.frameChannels.OnKeyCodePressed = function( _, key )
        self:OnKeyCodePressed( key )
    end

    self.frameChannels.OnKeyCodeReleased = function( _, key )
        self:OnKeyCodeReleased( key )
    end

    -- Update the combo boxes with the instruments
    -- from the current channel mapping preset.
    local channelCombos = {}

    local UpdateCombos = function()
        local name = Config.midiSelectedChannelMapPresetName
        local channelInstrumentMap = Config.midiChannelMapPresets[name] or {}

        for channelIndex = MKeyboard.MIDI_CHANNEL_ID_MIN, MKeyboard.MIDI_CHANNEL_ID_MAX do
            local combo = channelCombos[channelIndex]
            combo._isBeingModifiedByCode = true

            if channelInstrumentMap[channelIndex] then
                combo:ChooseOptionID( channelInstrumentMap[channelIndex] + 2 )
            else
                combo:ChooseOptionID( -1 )
            end

            combo._isBeingModifiedByCode = nil
        end
    end

    -- Channel mapping presets list
    local panelPresets = vgui.Create( "Panel", self.frameChannels )
    panelPresets:SetTall( ScaleSize( 32 ) )
    panelPresets:Dock( TOP )
    panelPresets:DockMargin( 0, 0, 0, 2 )

    local comboPresets = vgui.Create( "DComboBox", panelPresets )
    comboPresets:SetSortItems( false )
    comboPresets:Dock( FILL )

    StyledTheme.Apply( comboPresets )

    local UpdateDeleteButton

    comboPresets.OnSelect = function( s, _, name )
        if s._isBeingModifiedByCode then return end

        Config.midiSelectedChannelMapPresetName = name
        Config:Save()

        UpdateCombos()
        UpdateDeleteButton()
    end

    -- Update the list of available channel mapping presets
    local UpdatePresetList = function()
        comboPresets:Clear()
        comboPresets._isBeingModifiedByCode = true

        for name, _ in SortedPairs( Config.midiChannelMapPresets, false ) do
            comboPresets:AddChoice( name, nil, name == Config.midiSelectedChannelMapPresetName )
        end

        comboPresets._isBeingModifiedByCode = nil
    end

    local buttonDeletePreset = vgui.Create( "DImageButton", panelPresets )
    buttonDeletePreset:SetWide( ScaleSize( 22 ) )
    buttonDeletePreset:SetTooltip( "#preset.delete" )
    buttonDeletePreset:SetImage( "icon16/delete.png" )
    buttonDeletePreset:SetStretchToFit( false )
    buttonDeletePreset:Dock( RIGHT )

    StyledTheme.Apply( buttonDeletePreset, "DButton" )

    UpdateDeleteButton = function()
        buttonDeletePreset:SetEnabled( Config.midiSelectedChannelMapPresetName ~= "#preset.default" )
    end

    buttonDeletePreset.DoClick = function()
        local name = Config.midiSelectedChannelMapPresetName
        if name == "#preset.default" then return end

        if name and name ~= "" then
            Config.midiChannelMapPresets[name] = nil
            Config.midiSelectedChannelMapPresetName = "#preset.default"
        end

        Config:Save()

        UpdatePresetList()
        UpdateCombos()
        UpdateDeleteButton()
    end

    local buttonAddPreset = vgui.Create( "DImageButton", panelPresets )
    buttonAddPreset:SetWide( ScaleSize( 22 ) )
    buttonAddPreset:SetTooltip( "#preset.add" )
    buttonAddPreset:SetImage( "icon16/add.png" )
    buttonAddPreset:SetStretchToFit( false )
    buttonAddPreset:Dock( RIGHT )

    StyledTheme.Apply( buttonAddPreset, "DButton" )

    buttonAddPreset.DoClick = function()
        Derma_StringRequest( "#preset.saveas_title", "#preset.saveas_desc", "", function( name )
            if not name or name:Trim() == "" then
                presets.BadNameAlert()
                return
            end

            Config:AddMidiChannelMapPreset( name, {} )
            Config.midiSelectedChannelMapPresetName = name
            Config:Save()

            UpdatePresetList()
            UpdateCombos()
            UpdateDeleteButton()
        end )
    end

    -- Channels list
    local scrollChannels = vgui.Create( "DScrollPanel", self.frameChannels )
    scrollChannels:Dock( FILL )

    StyledTheme.Apply( scrollChannels )

    local FrameTime = FrameTime
    local channelState = MKeyboard.MIDI.channelState
    local automatedColor = MKeyboard.NOTE_COLORS.automated
    local channelAlpha = {}

    local function PaintChannel( s, w, h )
        SetColor( 0, 0, 0, 255 )
        DrawRect( 0, 0, w, h )

        SetColor( 50, 50, 50, 255 )
        DrawRect( 4, 4, 8, h - 8 )

        local channelIndex = s._channelIndex
        channelAlpha[channelIndex] = channelState[channelIndex] and 1 or Lerp( FrameTime() * 30, channelAlpha[channelIndex], 0 )

        SetColor( automatedColor.r, automatedColor.g, automatedColor.b, 255 * channelAlpha[channelIndex] )
        DrawRect( 4, 4, 8, h - 8 )
    end

    local function OnSelectInstrument( s, _, _, instrumentIndex )
        if s._isBeingModifiedByCode then return end

        instrumentIndex = tonumber( instrumentIndex )

        local name = Config.midiSelectedChannelMapPresetName
        local channelInstrumentMap = Config.midiChannelMapPresets[name]
        if not channelInstrumentMap then return end

        channelInstrumentMap[s._channelIndex] = instrumentIndex
        Config:Save()
    end

    for channelIndex = MKeyboard.MIDI_CHANNEL_ID_MIN, MKeyboard.MIDI_CHANNEL_ID_MAX do
        channelAlpha[channelIndex] = 0

        local panelChannel = vgui.Create( "DPanel", scrollChannels )
        panelChannel:SetTall( ScaleSize( 36 ) )
        panelChannel:Dock( TOP )
        panelChannel:DockMargin( 0, 0, 0, 4 )

        panelChannel._channelIndex = channelIndex
        panelChannel.Paint = PaintChannel

        local labelIndex = vgui.Create( "DLabel", panelChannel )
        labelIndex:SetFont( "Trebuchet24" )
        labelIndex:SetText( tostring( channelIndex ) )
        labelIndex:SetWide( 50 )
        labelIndex:Dock( LEFT )
        labelIndex:DockMargin( 20, 0, 0, 0 )

        StyledTheme.Apply( labelIndex )

        local combo = vgui.Create( "DComboBox", panelChannel )
        combo:SetSortItems( false )
        combo:AddChoice( "#musicalk.channels.use_current_instrument", -1 )
        combo:AddChoice( "#musicalk.channels.mute", 0 )
        combo:AddSpacer()
        combo:Dock( FILL )

        StyledTheme.Apply( combo )

        for instrumentIndex, instrument in ipairs( MKeyboard.instruments ) do
            combo:AddChoice( instrument.name, instrumentIndex )
        end

        combo._channelIndex = channelIndex
        combo.OnSelect = OnSelectInstrument
        channelCombos[channelIndex] = combo
    end

    UpdateCombos()
    UpdatePresetList()
    UpdateDeleteButton()
end

vgui.Register( "MKeyboard_Frame", PANEL, "DFrame" )
