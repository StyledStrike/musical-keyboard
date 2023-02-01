MKeyboard.keys = nil
MKeyboard.whiteKeys = 0
MKeyboard.layoutName = ""

local settings = MKeyboard.settings

local function UpdateKeyState( key, override )
    if override then
        key.state = override

    elseif key[3] then
        key.state = "black"

    else
        key.state = "white"
    end
end

local keyNameOverride = {
    [KEY_SEMICOLON] = ";"
}

function MKeyboard:SetLayout( index )
    local whiteKeys = 0
    local layout = self.layouts[index]

    for _, key in ipairs( layout.keys ) do
        local label = keyNameOverride[key[1]] or input.GetKeyName( key[1] )
        key.label = language.GetPhrase( label or "NONE" )

        -- if this is a black key...
        if key[3] then
            key.state = "black"
        else
            key.state = "white"
            whiteKeys = whiteKeys + 1
        end
    end

    self.keys = layout.keys
    self.whiteKeys = whiteKeys
    self.layoutName = layout.name
    self.settings.layout = index

    local limits = layout.octaveLimits
    settings.octave = math.Clamp( settings.octave, limits.min, limits.max )

    self:UpdateInterface()
end

--- Find the normal and "require shift" keys using their button code.
function MKeyboard:FindKeys( button )
    local normal, shifted

    for _, key in ipairs( self.keys ) do
        if key[1] == button or key[5] == button then
            if key[4] then
                shifted = key
            else
                normal = key
            end
        end
    end

    return normal, shifted
end

--- Find a key by note.
function MKeyboard:FindKeyByNote( note )
    for _, key in ipairs( self.keys ) do
        if key[2] == note then
            return key
        end
    end
end

--- Call this function when the user presses a button.
function MKeyboard:ButtonPress( button )
    if self.blockInputTimer > RealTime() then return end

    local normal, shifted = self:FindKeys( button )

    if input.IsKeyDown( KEY_LSHIFT ) then
        if shifted then
            shifted.pressed = true
            UpdateKeyState( shifted, "manual" )
            self:OnNoteOn( shifted[2] + settings.octave * 12 )
        end
    else
        if normal then
            normal.pressed = true
            UpdateKeyState( normal, "manual" )
            self:OnNoteOn( normal[2] + settings.octave * 12 )
        end
    end
end

--- Call this function when the user releases a button.
function MKeyboard:ButtonRelease( button )
    if self.shortcuts[button] then
        self.shortcuts[button]()

        return
    end

    -- always releasing both normal and shifted keys
    -- is very useful here, to handle a key that was pressed
    -- with shift previously but does not have shift pressed now
    local normal, shifted = self:FindKeys( button )

    if shifted and shifted.pressed then
        shifted.pressed = false
        UpdateKeyState( shifted )
    end

    if normal and normal.pressed then
        normal.pressed = false
        UpdateKeyState( normal )
    end
end

--- Programmatically press a note.
function MKeyboard:PressNote( note, velocity, instrument, isMidi )
    local key = self:FindKeyByNote( note - settings.octave * 12 )

    if key then
        key.pressed = true
        UpdateKeyState( key, "midi" )
    end

    self:OnNoteOn( note, velocity, instrument, isMidi )
end

--- Programmatically release a note
function MKeyboard:ReleaseNote( note )
    local key = self:FindKeyByNote( note - settings.octave * 12 )

    if key then
        key.pressed = false
        UpdateKeyState( key )
    end
end

--- Programmatically release all notes
function MKeyboard:ReleaseAllNotes()
    for _, key in ipairs( self.keys ) do
        key.pressed = false
        UpdateKeyState( key )
    end
end

local setColor = surface.SetDrawColor
local drawRect = surface.DrawRect
local drawRoundedBox = draw.RoundedBoxEx
local drawSimpleText = draw.SimpleText

local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local TEXT_ALIGN_BOTTOM = TEXT_ALIGN_BOTTOM
local TEXT_ALIGN_RIGHT = TEXT_ALIGN_RIGHT

local colors = MKeyboard.colors

local function DrawBlackKey( x, y, w, h, label, state )
    if not state then
        drawRoundedBox( 4, x, y, w, h, colors.disabled, false, false, true, true )

        return
    end

    drawRoundedBox( 4, x, y, w, h, colors[state], false, false, true, true )

    if settings.drawKeyLabels then
        drawSimpleText( label, "MKeyboard_Key", x + w * 0.5, y + h - 2, colors.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
    end
end

local function DrawWhiteKey( x, y, w, h, label, state )
    if not state then
        setColor( colors.disabled:Unpack() )
        drawRect( x, y, w, h )

        return
    end

    setColor( colors[state]:Unpack() )
    drawRect( x, y, w, h )

    if settings.drawKeyLabels then
        drawSimpleText( label, "MKeyboard_Key", x + w * 0.5, y + h - 2, colors.black, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
    end
end

local mathCeil = math.ceil
local ScrW = ScrW

function MKeyboard:Draw( x, y, h )
    local keyW = mathCeil( ScrW() * 0.014 )
    local w = keyW * self.whiteKeys

    x = x - ( w * 0.5 )

    -- draw border
    local borderSize = mathCeil( ScrW() * 0.002 )
    local infoSize = mathCeil( ScrW() * 0.016 )

    setColor( 0, 0, 0, 240 )
    drawRect( x - borderSize, y - infoSize - borderSize, w + borderSize * 2, h + infoSize + borderSize * 2 )

    -- draw octave status
    local octave = settings.octave

    if octave ~= 0 then
        surface.SetFont( "MKeyboard_Key" )
        local offsetX = surface.GetTextSize( self.layoutName )

        surface.SetTextPos( x + offsetX + borderSize * 2, y - infoSize + borderSize )
        surface.SetTextColor( 255, 208, 22 )
        surface.DrawText( octave > 0 and "+" .. octave or octave )
    end

    -- draw layout & instrument name
    local instrumentData = self.instruments[settings.instrument]

    draw.SimpleText( self.layoutName, "MKeyboard_Key", x + borderSize, y - infoSize + borderSize, colors.white )
    draw.SimpleText( instrumentData.name, "MKeyboard_Key", x + w - borderSize, y - infoSize + borderSize, colors.white, TEXT_ALIGN_RIGHT )

    -- draw keys
    local minNote = instrumentData.firstNote
    local maxNote = instrumentData.lastNote
    local noteOffset = octave * 12

    local deferKey

    for _, key in ipairs( self.keys ) do
        local note = key[2] + noteOffset

        -- if this is a black key...
        if key[3] then
            -- draw it on top of the next one
            deferKey = key
        else
            if note < minNote or note > maxNote then
                DrawWhiteKey( x, y, keyW * 0.95, h, key.label )
            else
                DrawWhiteKey( x, y, keyW * 0.95, h, key.label, key.state )
            end

            if deferKey then
                if note < minNote or note > maxNote then
                    DrawBlackKey( x - keyW * 0.3, y, keyW * 0.6, h * 0.6, deferKey.label )
                else
                    DrawBlackKey( x - keyW * 0.3, y, keyW * 0.6, h * 0.6, deferKey.label, deferKey.state )
                end

                deferKey = nil
            end

            x = x + keyW
        end
    end
end
