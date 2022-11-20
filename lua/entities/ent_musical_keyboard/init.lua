AddCSLuaFile( 'cl_init.lua' )
AddCSLuaFile( 'shared.lua' )
include( 'shared.lua' )

function ENT:SpawnFunction( ply, tr )
    if not tr.Hit then return end

    local ent = ents.Create( self.ClassName )
    ent:SetPos( tr.HitPos )
    ent:SetAngles( Angle( 0, ply:EyeAngles().y + 90, 0 ) )
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Initialize()
    self:SetModel( 'models/styledstrike/musical_keyboard.mdl' )
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
        net.Start( 'mkeyboard.set_entity', false )
        net.WriteEntity( self )
        net.Send( ply )

        self.Ply = ply
    end
end

function ENT:RemovePlayer()
    if IsValid( self.Ply ) then
        net.Start( 'mkeyboard.set_entity', false )
        net.WriteEntity( nil )
        net.Send( self.Ply )

        self.Ply = nil
    end
end