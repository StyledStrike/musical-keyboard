local IsValid = IsValid

function MKeyboard.IsAMusicalKeyboard( ent )
    return IsValid( ent ) and (
        ent:GetClass() == "base_musical_keyboard" or
        scripted_ents.IsBasedOn( ent:GetClass(), "base_musical_keyboard" )
    )
end

function MKeyboard.CanSpawn( ply )
    if not IsValid( ply ) then return false end

    if not ply:CheckLimit( "musical_keyboards" ) then
        return false
    end

    return true
end

function MKeyboard.EntityFactory( ply, data )
    if not MKeyboard.CanSpawn( ply, data.Class ) then return end

    local ent = ents.Create( data.Class )
    if not IsValid( ent ) then return end

    ent:SetPos( data.Pos )
    ent:SetAngles( data.Angle )
    ent:SetCreator( ply )
    ent:Spawn()
    ent:Activate()

    ply:AddCount( "musical_keyboards", ent )
    cleanup.Add( ply, "musical_keyboards", ent )

    return ent
end
