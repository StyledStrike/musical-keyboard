local ScaleSize = StyledTheme.ScaleSize
local colors = StyledTheme.colors
local Config = MKeyboard.Config

local PANEL = {}

function PANEL:Init()
    self:NoClipping( true )

    self.allKeys = {}
    self.whiteKeyNotes = {}
    self.noteButtons = {}
    self.noteAltButtons = {}

    self.enabledRange = {
        min = 36,
        max = 72
    }

    self.layoutName = nil
    self.instrumentName = nil
    self.lastCursorNote = nil

    self.padding = ScaleSize( 8 )
    self.headerHeight = ScaleSize( 28 )
    self.keyWidth = ScaleSize( 28 )
    self.cMarkerH = math.max( 1, ScaleSize( 4 ) )
    self.canvasPadding = ScaleSize( 16 )

    self.pianoRollW = 1
    self.canvasTotalW = 1
    self.canvasScroll = 0
    self.canvasTargetScroll = 0
end

local Clamp = math.Clamp

--- Set the range of "enabled" notes.
--- Notes outside this range will be grayed out.
function PANEL:SetEnabledRange( min, max )
    self.enabledRange.min = min
    self.enabledRange.max = max

    self:ScrollToNote( math.floor( max - ( max - min ) * 0.5 ) )
end

local keyNameOverride = {
    [KEY_SEMICOLON] = ";"
}

local function GetButtonName( button )
    return language.GetPhrase( keyNameOverride[button] or input.GetKeyName( button ) or "?" )
end

--- Set which button layout should be displayed, with a optional "offset" (transposed notes)
function PANEL:SetButtonLayout( layoutId, transpose )
    transpose = math.floor( transpose or 0 )

    local layout = MKeyboard:GetLayoutById( layoutId )
    assert( layout ~= nil, "Tried to set buttons from a inexistant layout ID '" .. layoutId .. "'" )

    local noteButtons = self.noteButtons
    local noteAltButtons = self.noteAltButtons

    table.Empty( noteButtons )
    table.Empty( noteAltButtons )

    local note, minNote, maxNote = 0, 127, 0

    for _, v in ipairs( layout.keys ) do
        note = v.note + transpose
        noteButtons[note] = GetButtonName( v.button )

        if v.altButton then
            noteAltButtons[note] = GetButtonName( v.altButton )
        end

        if note < minNote then minNote = note end
        if note > maxNote then maxNote = note end
    end

    self:SetEnabledRange( minNote, maxNote )
end

function PANEL:ScrollToNote( note, setNow )
    note = Clamp( note, 0, 127 )

    local key = self.allKeys[note]

    if key then
        self.canvasTargetScroll = key.x - self.pianoRollW * 0.5

        if setNow then
            self.canvasScroll = self.canvasTargetScroll
        end
    end
end

function PANEL:PerformLayout( w, _h )
    self.pianoRollW = w - self.padding * 2

    local allKeys = self.allKeys
    local keyWidth = self.keyWidth
    local whiteKeyNotes = self.whiteKeyNotes
    local blackKeyW = keyWidth * 0.7

    local OCTAVE_BLACK_KEYS = MKeyboard.OCTAVE_BLACK_KEYS
    local x, isBlackKey, whiteCount = 0, false, 0

    for note = 0, 127 do
        isBlackKey = OCTAVE_BLACK_KEYS[note % 12]

        allKeys[note] = {
            x = isBlackKey and x - blackKeyW * 0.5 or x,
            isBlackKey = isBlackKey,
            isCKey = ( note % 12 ) == 0
        }

        if not isBlackKey then
            x = x + keyWidth
            whiteCount = whiteCount + 1
            whiteKeyNotes[whiteCount] = note
        end
    end

    self.canvasTotalW = x
    self:SetEnabledRange( self.enabledRange.min, self.enabledRange.max )
end

local DrawRect = surface.DrawRect
local DrawSimpleText = draw.SimpleText
local DrawRoundedBoxEx = draw.RoundedBoxEx

function PANEL:Paint( w, h )
    local padding = self.padding

    DrawRoundedBoxEx( ScaleSize( 8 ), padding, padding, w - padding * 2, h - padding * 2, colors.entryBackground, true, true, false, false )

    local headerHeight = self.headerHeight

    if self.layoutName then
        DrawSimpleText( self.layoutName, "StyledTheme_Small", padding * 1.5, padding + headerHeight * 0.5, colors.labelText, 0, 1 )
    end

    local offset = 0
    local transpose = Config.keyboardTranspose

    if transpose ~= 0 then
        offset = DrawSimpleText( transpose > 0 and "+" .. transpose or transpose, "StyledTheme_Small",
            w - padding * 1.5, padding + headerHeight * 0.5, colors.labelTextDisabled, 2, 1 )

        offset = offset + padding
    end

    if self.instrumentName then
        DrawSimpleText( self.instrumentName, "StyledTheme_Small",
            w - offset - padding * 1.5, padding + headerHeight * 0.5, colors.labelText, 2, 1 )
    end

    self:PaintPianoRoll( padding, padding + headerHeight, h - headerHeight - padding * 2 )
end

function PANEL:GetActiveNotes()
    return {}
end

local function IsInRange( note, range )
    return note >= range.min and note <= range.max
end

local cursor = {
    x = 0,
    y = 0,

    hoveredNote = nil,
    hoverX = 0,
    hoverY = 0,
    hoverW = 0,
    hoverH = 0
}

local function TestCursorInKey( note, boxX, boxY, boxW, boxH )
    if cursor.x > boxX and cursor.y > boxY and cursor.x < boxX + boxW and cursor.y < boxY + boxH then
        cursor.hoveredNote = note
        cursor.hoverX = boxX
        cursor.hoverY = boxY
        cursor.hoverW = boxW
        cursor.hoverH = boxH
    end
end

local SetDrawColor = surface.SetDrawColor
local SetScissorRect = render.SetScissorRect
local MidiNoteIterator = MKeyboard.MidiNoteIterator

local NOTE_COLORS = MKeyboard.NOTE_COLORS

function PANEL:PaintPianoRoll( x, y, h )
    local pianoW = self.pianoRollW
    
    cursor.x, cursor.y = self:ScreenToLocal( input.GetCursorPos() )
    cursor.hoveredNote = nil

    local clipX, clipY = self:LocalToScreen( x, y )
    SetScissorRect( clipX, clipY, clipX + pianoW, clipY + h, true )

    self.canvasTargetScroll = Clamp( self.canvasTargetScroll, 0, self.canvasTotalW - pianoW )
    self.canvasScroll = Lerp( FrameTime() * 6, self.canvasScroll, self.canvasTargetScroll )
    x = x - self.canvasScroll

    local allKeys = self.allKeys
    local whiteKeyNotes = self.whiteKeyNotes
    local activeNotes = self:GetActiveNotes() or {}

    local noteButtons = self.noteButtons
    local noteAltButtons = self.noteAltButtons

    local enabledRange = self.enabledRange
    local drawButtonLabels = Config.drawButtonLabels

    local cMarkerH = self.cMarkerH
    local keyWidth = self.keyWidth
    local key, inEnabledRange, activeNote

    local startNote = math.floor( -x / keyWidth ) + 1
    local endNote = startNote + math.floor( pianoW / keyWidth ) + 1

    startNote = whiteKeyNotes[startNote]
    endNote = whiteKeyNotes[endNote]

    local boxX, boxY, boxW, boxH

    for note in MidiNoteIterator( false, startNote, endNote ) do
        key = allKeys[note]
        inEnabledRange = IsInRange( note, enabledRange )
        activeNote = activeNotes[note]

        if activeNote then
            SetDrawColor( NOTE_COLORS[activeNote] )

        elseif inEnabledRange then
            SetDrawColor( 255, 255, 255, 255 )
        else
            SetDrawColor( 120, 120, 120, 255 )
        end

        boxX, boxY, boxW, boxH = x + key.x, y, keyWidth - 1, h
        DrawRect( boxX, boxY, boxW, boxH )
        TestCursorInKey( note, boxX, boxY, boxW, boxH )

        if key.isCKey then
            SetDrawColor( colors.accent )
            DrawRect( boxX, y + h - cMarkerH, boxW, cMarkerH )
        end

        if drawButtonLabels and noteButtons[note] then
            DrawSimpleText( noteButtons[note], "MKeyboard_Small", x + key.x + keyWidth * 0.5, y + h * 0.95, colors.entryBackground, 1, 4 )
        end

        if drawButtonLabels and noteAltButtons[note] then
            DrawSimpleText( noteAltButtons[note], "MKeyboard_Small", x + key.x + keyWidth * 0.5, y + h * 0.75, colors.entryBackground, 1, 4 )
        end
    end

    local blackKeyW = keyWidth * 0.7
    local blackHeyH = h * 0.6

    for note in MidiNoteIterator( true, startNote, endNote ) do
        key = allKeys[note]
        inEnabledRange = IsInRange( note, enabledRange )
        activeNote = activeNotes[note]

        if activeNote then
            SetDrawColor( NOTE_COLORS[activeNote] )

        elseif inEnabledRange then
            SetDrawColor( 0, 0, 0, 255 )
        else
            SetDrawColor( 80, 80, 80, 255 )
        end

        boxX, boxY, boxW, boxH = x + key.x, y, blackKeyW, blackHeyH

        DrawRect( boxX, boxY, boxW, boxH )
        TestCursorInKey( note, boxX, boxY, boxW, boxH )

        if drawButtonLabels and noteButtons[note] then
            DrawSimpleText( noteButtons[note], "MKeyboard_Small", x + key.x + blackKeyW * 0.5, y + h * 0.55, colors.labelText, 1, 4 )
        end

        if drawButtonLabels and noteAltButtons[note] then
            DrawSimpleText( noteAltButtons[note], "MKeyboard_Small", x + key.x + blackKeyW * 0.5, y + h * 0.35, colors.labelText, 1, 4 )
        end
    end

    local cursorNote = nil

    if cursor.hoveredNote then
        if vgui.CursorVisible() and input.IsButtonDown( 107 ) then -- MOUSE_LEFT
            cursorNote = cursor.hoveredNote
        else
            SetDrawColor( 0, 0, 0, 100 )
            DrawRect( cursor.hoverX, cursor.hoverY, cursor.hoverW, cursor.hoverH )
        end
    end

    if self.lastCursorNote ~= cursorNote then
        local parent = self:GetParent()

        if self.lastCursorNote and parent.ReleaseNote then
            parent:ReleaseNote( 1, self.lastCursorNote )
        end

        self.lastCursorNote = cursorNote

        if cursorNote then
            parent:PressNote( 1, cursorNote, 127, nil, false  )
        end
    end

    SetScissorRect( 0, 0, 0, 0, false )
end

vgui.Register( "MKeyboard_PianoRoll", PANEL, "DPanel" )
