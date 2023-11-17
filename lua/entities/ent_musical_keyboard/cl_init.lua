include( "shared.lua" )

local RealTime = RealTime
local Vector = Vector

local blackKeys = {
    [1] = true, [3] = true, [6] = true, [8] = true, [10] = true
}

local keyColors = {
    Color( 255, 148, 77 ),
    Color( 171, 0, 197 )
}

local offsetKeys = {
    [2] = 0.2,
    [4] = 0.4,
    [5] = -0.1,
    [7] = 0.1,
    [9] = 0.4,
    [11] = 0.6
}

local Remap = math.Remap

function ENT:Initialize()
    self.drawNotes = {}
end

function ENT:EmitNote( note, velocity, level, instrument, automated )
    local instr = MKeyboard.instruments[instrument]

    if not instr then return end
    if note < instr.firstNote or note > instr.lastNote then return end

    sound.Play( string.format( instr.path, note ), self:GetPos(), level, 100, velocity / 127 )

    local idx = note % 12
    local len = 8
    local height = -0.2
    local width = 1.6
    local x = -1.1

    if blackKeys[idx] then
        len = 5
        height = 0.1
        width = 1
        x = -0.6
    end

    if offsetKeys[idx] then
        x = x + offsetKeys[idx]
    end

    self.drawNotes[note] = {
        x = Remap( note, 21, 108, -37, 36.7 ),
        t = RealTime() + 0.2,
        min = Vector( x, -1.5, -1 ),
        max = Vector( x + width, len, height ),
        colorIndex = automated and 2 or 1
    }
end

function ENT:Draw()
    self:DrawModel()

    local t = RealTime()
    local ang = self:GetAngles()

    render.SetColorMaterial()

    for note, p in pairs( self.drawNotes ) do
        if t > p.t then
            self.drawNotes[note] = nil
        else
            local clr = keyColors[p.colorIndex]
            local alpha = 255 * ( ( p.t - t ) / 0.2 )

            render.DrawBox(
                self:LocalToWorld( Vector( -p.x, 0, 0 ) ),
                ang, p.min, p.max,
                Color( clr.r, clr.g, clr.b, alpha )
            )
        end
    end
end
