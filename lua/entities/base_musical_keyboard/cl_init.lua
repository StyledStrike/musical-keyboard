include( "shared.lua" )

function ENT:Initialize()
    self.rangedEmitter = MKeyboard.CreateRangedEmitter( self )
end

function ENT:OnRemove( fullUpdate )
    if fullUpdate then return end

    if self.rangedEmitter then
        self.rangedEmitter:Destroy()
        self.rangedEmitter = nil
    end
end

function ENT:Think()
    self:SetNextClientThink( CurTime() )

    if self.rangedEmitter then
        self.rangedEmitter:Think()
    end

    return true
end

function ENT:OnUserVarChanged( name, _, value )
    local rangedEmitter = self.rangedEmitter
    if not rangedEmitter then return end

    local emitter = rangedEmitter.emitter
    if not emitter then return end

    if name == "HRTFEnabled" then
        emitter:SetHRTFEnabled( value == true )

    elseif name == "ImpulseResponseIndex" then
        local ir = MKeyboard.impulseResponses[value]
        emitter:SetImpulseResponseAudioFile( ir ~= nil and ir.fileName )
    end
end

local BLACK_KEYS = {
    [1] = true, [3] = true, [6] = true, [8] = true, [10] = true
}

local KEY_OFFSETS = {
    [2] = 0.2,
    [4] = 0.4,
    [5] = -0.1,
    [7] = 0.1,
    [9] = 0.4,
    [11] = 0.6
}

local NOTE_COLORS = MKeyboard.NOTE_COLORS
local NOTE_MIN, NOTE_MAX = 33, 120

local Remap = math.Remap
local DrawBox = render.DrawBox
local pos, min, max = Vector(), Vector(), Vector()

function ENT:Draw()
    self:DrawModel()

    local rangedEmitter = self.rangedEmitter
    if not rangedEmitter then return end

    local activeNotes = rangedEmitter.activeNotes
    if not activeNotes then return end

    render.SetColorMaterial()

    local ang = self:GetAngles()
    local relativeNote
    local x, w, h, l

    for note, colorIndex in pairs( activeNotes ) do
        if note >= NOTE_MIN and note <= NOTE_MAX then
            relativeNote = note % 12
            x = -1.1
            w = 1.6
            h = -0.2
            l = 8

            if BLACK_KEYS[relativeNote] then
                x = -0.6
                w = 1
                h = 0.1
                l = 5
            end

            x = x + ( KEY_OFFSETS[relativeNote] or 0 )
            pos[1] = -Remap( note, NOTE_MIN, NOTE_MAX, -37, 36.7 )

            min:SetUnpacked( x, -1.5, -1 )
            max:SetUnpacked( x + w, l, h )

            DrawBox( self:LocalToWorld( pos ), ang, min, max, NOTE_COLORS[colorIndex] )
        end
    end
end
