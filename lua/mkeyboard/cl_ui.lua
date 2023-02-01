local mathCeil = math.ceil
local ScrW, ScrH = ScrW, ScrH

local drawRect = surface.DrawRect
local drawSimpleText = draw.SimpleText

local colors = MKeyboard.colors
local settings = MKeyboard.settings

MKeyboard.expanded = false

function MKeyboard:DrawSheet( index, x, y )
    local borderSize = mathCeil( ScrW() * 0.002 )
    local titleBarSize = ScrH() * 0.028
    local data = self.sheets[index]

    surface.SetFont( "MKeyboard_Sheet" )

    local sheetW, sheetH = surface.GetTextSize( data.sequence )
    local w, h = math.max( ScrW() * 0.3, sheetW + borderSize * 2 ), sheetH + titleBarSize * 0.5
    local oldClipping = DisableClipping( true )

    x = x - w * 0.5
    y = y - h

    surface.SetDrawColor( 0, 0, 0, 254 )
    drawRect( x, y, w, h )

    draw.DrawText( data.sequence, "MKeyboard_Sheet", x + w * 0.5, y + titleBarSize, nil, TEXT_ALIGN_CENTER )
    drawSimpleText( data.title, "MKeyboard_Title", x + w * 0.5, y + borderSize, colors.white, TEXT_ALIGN_CENTER )

    DisableClipping( oldClipping )
end

local function CreatePanel( title, parent, dock, wide, help )
    local dockPadding = ScrH() * 0.01
    local dSkin = derma.GetDefaultSkin()

    local pnl = vgui.Create( "DPanel", parent )
    pnl:DockPadding( dockPadding, dockPadding, dockPadding, dockPadding )
    pnl:DockMargin( 4, 0, 4, 0 )
    pnl:Dock( dock )

    if wide then
        pnl:SetWide( wide )
    end

    local pnlHeader = vgui.Create( "DPanel", pnl )
    pnlHeader:Dock( TOP )
    pnlHeader:SetPaintBackground( false )

    local lblTitle = vgui.Create( "DLabel", pnlHeader )
    lblTitle:SetFont( "MKeyboard_Key" )
    lblTitle:SetText( title )
    lblTitle:SizeToContents()
    lblTitle:Dock( LEFT )
    lblTitle:SetTextColor( dSkin.Colours.Label.Dark )

    if help then
        local lblHelp = vgui.Create( "DLabel", pnlHeader )
        lblHelp:SetFont( "MKeyboard_Key" )
        lblHelp:SetText( help )
        lblHelp:SizeToContents()
        lblHelp:Dock( RIGHT )
        lblHelp:SetTextColor( dSkin.Colours.Label.Dark )
    end

    return pnl
end

function MKeyboard:CreateInterface()
    if not self.selectedMidiPort then
        self:ShowDevicesDialog()
    end

    local wide = ScrW() * 0.7
    local tall = ScrH() * 0.5

    self.frameKeyboard = vgui.Create( "DFrame" )
    self.frameKeyboard:SetPos( ( ScrW() - wide ) * 0.5, ScrH() - tall * 0.5 )
    self.frameKeyboard:SetSize( wide, tall )
    self.frameKeyboard:SetTitle( "" )
    self.frameKeyboard:SetDeleteOnClose( true )
    self.frameKeyboard:SetDraggable( false )
    self.frameKeyboard:SetSizable( false )
    self.frameKeyboard:ShowCloseButton( false )
    self.frameKeyboard:LerpPositions( 1, true )

    -- passthrough button events while this panel is focused
    self.frameKeyboard.OnKeyCodePressed = function( _, key )
        self:ButtonPress( key )
    end

    self.frameKeyboard.OnKeyCodeReleased = function( _, key )
        self:ButtonRelease( key )
    end

    local helpMessage = {
        [false] = language.GetPhrase( "mk.help.open" ),
        [true] = language.GetPhrase( "mk.help.close" )
    }

    self.frameKeyboard.Paint = function( _, sw, sh )
        self:Draw( sw * 0.5, sh * 0.1, sh * 0.22 )
        draw.RoundedBoxEx( 8, 0, sh * 0.4, sw, sh * 0.6, colors.bg, true, true, false, false )

        if self.midiPortName then
            drawSimpleText( self.midiPortName, "MKeyboard_Title", sw - ( sw * 0.01 ), sh * 0.43,
                colors.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP )

            drawSimpleText( helpMessage[self.expanded], "MKeyboard_Title", sw * 0.01, sh * 0.43,
                colors.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
        else
            drawSimpleText( helpMessage[self.expanded], "MKeyboard_Title", sw * 0.5, sh * 0.43,
                colors.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        end

        if settings.sheet > 0 then
            self:DrawSheet( settings.sheet, sw * 0.5, 0 )
        end
    end

    local pnlParent = vgui.Create( "DPanel", self.frameKeyboard )
    pnlParent:SetPos( wide * 0.01, tall * 0.52 )
    pnlParent:SetSize( wide * 0.98, tall * 0.45 )
    pnlParent:DockPadding( 0, 0, 0, 0 )
    pnlParent:SetPaintBackground( false )

    ---------- Settings Panel ----------

    local pnlSettings = CreatePanel( language.GetPhrase( "mk.settings" ), pnlParent, LEFT, wide * 0.3 )

    local settingsScroll = vgui.Create( "DScrollPanel", pnlSettings )
    settingsScroll:Dock( FILL )
    settingsScroll:DockMargin( 0, 8, 0, 0 )

    local function addRow( label, propertyClass )
        local parent = vgui.Create( "DPanel", settingsScroll )
        parent:SetWide( wide * 0.3 )
        parent:SetTall( 22 )
        parent:DockPadding( 4, 0, 4, 0 )
        parent:DockMargin( 0, 0, 0, 2 )
        parent:Dock( TOP )

        local dLabel = vgui.Create( "DLabel", parent )
        dLabel:SetText( language.GetPhrase( label ) )
        dLabel:SetTextColor( colors.black )
        dLabel:SetWide( parent:GetWide() )
        dLabel:Dock( FILL )

        if not propertyClass then
            dLabel:SetTextColor( colors.white )
            parent:SetBackgroundColor( colors.bg )
            parent:SetTall( 28 )

            return
        end

        local property = vgui.Create( propertyClass, parent )

        if propertyClass == "DNumSlider" then
            property.TextArea:SetWide( 30 )

            function property:PerformLayout()
                self.Label:SetWide( 0 )
            end
        end

        property:Dock( RIGHT )
        property:SetWide( 150 )

        return property
    end

    addRow( "mk.vkeys" )

    -- layouts list
    local rLayouts = addRow( "mk.layout", "DComboBox" )

    for k, v in ipairs( self.layouts ) do
        rLayouts:AddChoice( v.name, nil, k == settings.layout )
    end

    rLayouts.OnSelect = function( _, index )
        settings.layout = index
        settings.sheet = 0

        self:SetLayout( settings.layout )
        self:SaveSettings()
    end

    -- should draw labels
    local rDrawLabels = addRow( "mk.vkeys.labels", "DImageButton" )
    rDrawLabels:SetImage( settings.drawKeyLabels and "icon16/accept.png" or "icon16/cancel.png" )
    rDrawLabels:SetStretchToFit( false )
    rDrawLabels:SetPaintBackground( true )

    rDrawLabels.DoClick = function()
        settings.drawKeyLabels = not settings.drawKeyLabels
        self:SaveSettings()

        rDrawLabels:SetIcon( settings.drawKeyLabels and "icon16/accept.png" or "icon16/cancel.png" )
    end

    -- velocity
    local rVelocity = addRow( "mk.vkeys.velocity", "DNumSlider" )
    rVelocity:SetMin( 0 )
    rVelocity:SetMax( 127 )
    rVelocity:SetDecimals( 0 )
    rVelocity:SetValue( settings.velocity )
    rVelocity.Label:SetTextColor( colors.black )

    rVelocity.OnValueChanged = function( _, value )
        settings.velocity = math.ceil( value )
    end

    -- octave
    local rOctave = addRow( "mk.vkeys.octave", "DNumSlider" )
    rOctave:SetMin( -5 )
    rOctave:SetMax( 5 )
    rOctave:SetDecimals( 0 )
    rOctave:SetValue( settings.octave )
    rOctave.Label:SetTextColor( colors.black )
    rOctave.Label:SetWide( 30 )
    rOctave.Slider:SetWide( 300 )

    self.rOctave = rOctave

    rOctave.OnValueChanged = function( _, value )
        if value < 0 then
            settings.octave = math.ceil( value )
        else
            settings.octave = math.floor( value )
        end
    end

    addRow( "MIDI" )

    -- MIDI devices
    local rDevices = addRow( "mk.midi.device", "DButton" )
    rDevices:SetText( language.GetPhrase( "mk.midi.device.choose" ) )

    if self.isMidiAvailable then
        if table.Count( midi.GetPorts() ) == 0 then
            rDevices:SetText( language.GetPhrase( "mk.midi.nodevices" ) )
            rDevices:SetEnabled( false )
        end

        rDevices.DoClick = function()
            self:ShowDevicesDialog()
        end

        local rChannels = addRow( "mk.midi.channels", "DButton" )
        rChannels:SetText( language.GetPhrase( "mk.midi.channels.setup" ) )

        rChannels.DoClick = function()
            self:ShowChannelsDialog()
        end

        local rTranspose = addRow( "mk.vkeys.transpose", "DNumSlider" )
        rTranspose:SetMin( -48 )
        rTranspose:SetMax( 48 )
        rTranspose:SetDecimals( 0 )
        rTranspose:SetValue( settings.midiTranspose )
        rTranspose.Label:SetTextColor( colors.black )
        rTranspose.Label:SetWide( 30 )
        rTranspose.Slider:SetWide( 300 )

        rTranspose.OnValueChanged = function( _, value )
            if value < 0 then
                settings.midiTranspose = math.ceil( value )
            else
                settings.midiTranspose = math.floor( value )
            end

            self:SaveSettings()
            self:ReleaseAllNotes()
        end

    else
        rDevices:SetText( language.GetPhrase( "mk.midi.nomodule" ) )
        rDevices:SetEnabled( false )

        local rInstallHelp = addRow( "mk.midi.guide", "DButton" )
        rInstallHelp:SetText( language.GetPhrase( "mk.midi.guide" ) )

        rInstallHelp.DoClick = function()
            gui.OpenURL( self.URL_MIDI_GUIDE )
            self:ToggleMenu()
        end
    end

    ---------- Instruments Panel ----------

    local pnlInstruments = CreatePanel(
        language.GetPhrase( "mk.instruments" ),
        pnlParent, FILL, nil, language.GetPhrase( "mk.instruments.help" )
    )

    self.instrList = vgui.Create( "DListView", pnlInstruments )
    self.instrList:Dock( FILL )
    self.instrList:DockMargin( 0, 8, 0, 0 )
    self.instrList:AddColumn( language.GetPhrase( "mk.instruments" ) )
    self.instrList:SetMultiSelect( false )
    self.instrList:SetHideHeaders( true )
    self.instrList:SetSortable( false )

    for i, v in ipairs( self.instruments ) do
        self.instrList:AddLine( i .. " - " .. v.name )
    end

    self.instrList:SelectItem( self.instrList:GetLine( settings.instrument ) )

    self.instrList.OnRowSelected = function( _, index )
        settings.instrument = index
        self:SaveSettings()
    end

    ---------- Layouts Panel ----------

    local pnlSheets = CreatePanel( language.GetPhrase( "mk.sheets" ), pnlParent, RIGHT, wide * 0.3 )

    self.sheetList = vgui.Create( "DListView", pnlSheets )
    self.sheetList:Dock( FILL )
    self.sheetList:DockMargin( 0, 8, 0, 0 )
    self.sheetList:AddColumn( language.GetPhrase( "mk.sheets" ) )
    self.sheetList:SetMultiSelect( false )
    self.sheetList:SetHideHeaders( true )
    self.sheetList:SetSortable( false )

    self:SetLayout( settings.layout )
end

function MKeyboard:CloseInterface()
    self.expanded = false

    if IsValid( self.frameKeyboard ) then
        self.frameKeyboard:Close()
    end

    if IsValid( self.frameDevices ) then
        self.frameDevices:Close()
    end

    if IsValid( self.frameChannels ) then
        self.frameChannels:Close()
    end
end

function MKeyboard:UpdateInterface()
    local layoutIndex = settings.layout

    self.sheetList:Clear()

    local selectedItem = self.sheetList:AddLine( language.GetPhrase( "mk.sheets.hidden" ) )
    selectedItem._sheetIndex = 0

    for k, v in ipairs( self.sheets ) do
        if v.layout == layoutIndex then
            local line = self.sheetList:AddLine( v.title )
            line._sheetIndex = k

            if k == settings.sheet then
                selectedItem = line
            end
        end
    end

    self.sheetList:SelectItem( selectedItem )

    self.sheetList.OnRowSelected = function( _, _, line )
        settings.sheet = line._sheetIndex
        self:SaveSettings()
    end

    local octaveLimits = self.layouts[layoutIndex].octaveLimits

    self.rOctave:SetMin( octaveLimits.min )
    self.rOctave:SetMax( octaveLimits.max )
    self.rOctave:SetValue( settings.octave )
end

function MKeyboard:ToggleMenu()
    self.expanded = not self.expanded

    -- I might have found a bug here. Basically, cant get the panel position
    -- after calling LerpPositions without playing the animation first
    -- local x = self.frameKeyboard:GetX()

    local x = ( ScrW() - ScrW() * 0.7 ) * 0.5
    local tall = self.frameKeyboard:GetTall()

    if self.expanded then
        self.frameKeyboard:SetPos( x, ScrH() - tall )
        self.frameKeyboard:MakePopup()
    else
        self.frameKeyboard:SetPos( x, ScrH() - tall * 0.49 )
        self.frameKeyboard:SetMouseInputEnabled( false )
        self.frameKeyboard:SetKeyboardInputEnabled( false )
    end
end

function MKeyboard:ChangeInstrument( to )
    local newInstrument = settings.instrument + to

    if newInstrument < 1 then
        newInstrument = #self.instruments

    elseif newInstrument > #self.instruments then
        newInstrument = 1
    end

    settings.instrument = newInstrument

    local line = self.instrList:GetLine( newInstrument )

    self.instrList:ClearSelection()
    self.instrList:SelectItem( line )
    self.instrList.VBar:AnimateTo( line:GetY() - self.instrList:GetTall() * 0.5, 0.25, 0, -1 )

    self:SaveSettings()
end

function MKeyboard:AddOctave( value )
    local newOctave = settings.octave + value
    local limits = self.layouts[settings.layout].octaveLimits

    if newOctave < limits.min then
        newOctave = limits.max

    elseif newOctave > limits.max then
        newOctave = limits.min
    end

    settings.octave = newOctave

    self.rOctave:SetValue( settings.octave )
    self:ReleaseAllNotes()
    self:SaveSettings()
end

function MKeyboard:ShowDevicesDialog()
    if IsValid( self.frameDevices ) then
        self.frameDevices:Close()
    end

    if not self.isMidiAvailable then return end

    local midiPorts = midi.GetPorts()
    if table.Count( midiPorts ) == 0 then return end

    if midi.IsOpened() then
        self:MidiClose()
    end

    self.selectedMidiPort = nil

    self.frameDevices = vgui.Create( "DFrame" )
    self.frameDevices:SetSize( 300, 130 )
    self.frameDevices:SetTitle( language.GetPhrase( "mk.midi.device.choose" ) )
    self.frameDevices:SetVisible( true )
    self.frameDevices:SetDraggable( true )
    self.frameDevices:ShowCloseButton( true )
    self.frameDevices:SetDeleteOnClose( true )
    self.frameDevices:Center()
    self.frameDevices:MakePopup()

    local startTime = SysTime()
    local oldPaint = self.frameDevices.Paint

    self.frameDevices.Paint = function( s, sw, sh )
        Derma_DrawBackgroundBlur( s, startTime )
        oldPaint( s, sw, sh )
    end

    local labelHelp = vgui.Create( "DLabel", self.frameDevices )
    labelHelp:SetPos( 10, 40 )
    labelHelp:SetSize( 280, 40 )

    labelHelp:SetText( string.format(
        language.GetPhrase( "mk.midi.found" ),
        tostring( table.Count( midiPorts ) )
    ) )

    local comboDevices = vgui.Create( "DComboBox", self.frameDevices )
    comboDevices:SetPos( 10, 90 )
    comboDevices:SetSize( 280, 20 )
    comboDevices:SetValue( language.GetPhrase( "mk.midi.select" ) )

    for k, v in pairs( midiPorts ) do
        comboDevices:AddChoice( "[" .. k .. "] " .. v )
    end

    comboDevices.OnSelect = function( _, index )
        self.selectedMidiPort = index - 1
        self.frameDevices:Close()
    end
end

function MKeyboard:ShowChannelsDialog()
    if IsValid( self.frameChannels ) then
        self.frameChannels:Close()
        return
    end

    local tall = math.min( 610, ScrH() * 0.6 )

    self.frameChannels = vgui.Create( "DFrame" )
    self.frameChannels:SetSize( 400, tall )
    self.frameChannels:SetTitle( language.GetPhrase( "mk.channels" ) )
    self.frameChannels:SetVisible( true )
    self.frameChannels:SetSizable( true )
    self.frameChannels:SetDraggable( true )
    self.frameChannels:ShowCloseButton( true )
    self.frameChannels:SetDeleteOnClose( true )
    self.frameChannels:SetPos( ScrW() - self.frameChannels:GetWide(), 0 )
    self.frameChannels:MakePopup()

    -- passthrough button events while this panel is focused
    self.frameChannels.OnKeyCodePressed = function( _, key )
        self:ButtonPress( key )
    end

    self.frameChannels.OnKeyCodeReleased = function( _, key )
        self:ButtonRelease( key )
    end

    local scrollChannels = vgui.Create( "DScrollPanel", self.frameChannels )
    scrollChannels:Dock( FILL )

    local function paintChannelPanel( s, sw, sh )
        surface.SetDrawColor( 0, 0, 0, 255 )
        drawRect( 0, 0, sw, sh )

        surface.SetDrawColor( 50, 50, 50, 255 )
        drawRect( 4, 4, 8, sh - 8 )

        self.channelState[s.channel] = Lerp( FrameTime() * 8, self.channelState[s.channel], 0 )
        surface.SetDrawColor( colors.midi.r, colors.midi.g, colors.midi.b, 255 * self.channelState[s.channel] )
        drawRect( 4, 4, 8, sh - 8 )
    end

    local function selectChannelInst( s, _, _, idx )
        if idx == -1 then
            settings.channelInstruments[s.channel] = nil
        else
            settings.channelInstruments[s.channel] = idx
        end

        MKeyboard:SaveSettings()
    end

    for c = 0, 15 do
        self.channelState[c] = 0

        local panelChannel = vgui.Create( "DPanel", scrollChannels )
        panelChannel:SetSize( wide, 32 )
        panelChannel:Dock( TOP )
        panelChannel:DockMargin( 0, 0, 0, 4 )

        panelChannel.channel = c
        panelChannel.Paint = paintChannelPanel

        local lblIndex = vgui.Create( "DLabel", panelChannel )
        lblIndex:SetFont( "Trebuchet24" )
        lblIndex:SetTextColor( colors.white )
        lblIndex:SetText( "#" .. ( c + 1 ) )
        lblIndex:SetWide( 50 )
        lblIndex:Dock( LEFT )
        lblIndex:DockMargin( 20, 0, 0, 0 )

        local comboInstr = vgui.Create( "DComboBox", panelChannel )
        comboInstr:SetSortItems( false )
        comboInstr:AddChoice( language.GetPhrase( "mk.channels.usecurrent" ), -1, true )
        comboInstr:AddChoice( language.GetPhrase( "mk.channels.mute" ), 0 )
        comboInstr:AddSpacer()
        comboInstr:Dock( FILL )

        local myInstrument = settings.channelInstruments[c] or -1

        for idx, v in ipairs( MKeyboard.instruments ) do
            comboInstr:AddChoice( v.name, idx, idx == myInstrument )
        end

        comboInstr.channel = c
        comboInstr.OnSelect = selectChannelInst
    end
end