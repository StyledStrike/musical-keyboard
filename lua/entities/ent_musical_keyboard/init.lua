AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local function MakeKeyboardSpawner( ply, data )
    if IsValid( ply ) and not ply:CheckLimit( "musical_keyboards" ) then return end

    local ent = ents.Create( data.Class )
    if not IsValid( ent ) then return end

    ent:SetPos( data.Pos )
    ent:SetAngles( data.Angle )
    ent:Spawn()
    ent:Activate()

    ply:AddCount( "musical_keyboards", ent )

    return ent
end

duplicator.RegisterEntityClass( "ent_musical_keyboard", MakeKeyboardSpawner, "Data" )

function ENT:SpawnFunction( ply, tr )
    if tr.Hit then
        return MakeKeyboardSpawner( ply, {
            Pos = tr.HitPos,
            Angle = Angle( 0, ply:EyeAngles().y + 90, 0 ),
            Class = self.ClassName
        } )
    end
end

function ENT:Initialize()
    self:SetModel( "models/styledstrike/musical_keyboard.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self:DrawShadow( true )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then phys:Wake() end
end

function ENT:Use( ply )
    self:SetPlayer( ply )
end

function ENT:SetPlayer( ply )
    if not IsValid( self.Ply ) then
        net.Start( "mkeyboard.set_entity", false )
        net.WriteEntity( self )
        net.Send( ply )

        self.Ply = ply
    end
end

function ENT:RemovePlayer()
    if IsValid( self.Ply ) then
        net.Start( "mkeyboard.set_entity", false )
        net.WriteEntity( nil )
        net.Send( self.Ply )

        self.Ply = nil
    end
end
