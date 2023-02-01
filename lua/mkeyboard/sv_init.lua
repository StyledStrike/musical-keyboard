resource.AddWorkshop( "2656563609" )

util.AddNetworkString( "mkeyboard.set_entity" )
util.AddNetworkString( "mkeyboard.notes" )

local function FindBroadcastTargets( pos, radius, ignore )
    -- make the radius squared, to compare with DistToSqr (faster) 
    radius = radius * radius

    local found = {}

    for _, v in ipairs( player.GetHumans() ) do
        if v ~= ignore and pos:DistToSqr( v:GetPos() ) < radius then
            table.insert( found, v )
        end
    end

    return found
end

local function IsAMusicalKeyboard( ent )
    return IsValid( ent ) and ent:GetClass() == "ent_musical_keyboard"
end

local function BroadcastNotes( notes, ent, automated, ignorePlayer )
    if #notes == 0 then return end

    -- only broadcast to nearby players, if any
    local targets = FindBroadcastTargets( ent:GetPos(), MKeyboard.NET_BROADCAST_DISTANCE, ignorePlayer )
    if #targets == 0 then return end

    net.Start( "mkeyboard.notes", false )
    net.WriteEntity( ent )
    net.WriteBool( automated )
    net.WriteUInt( #notes, 5 )

    for _, params in ipairs( notes ) do
        net.WriteUInt( params[1], 7 ) -- note
        net.WriteUInt( params[2], 7 ) -- velocity
        net.WriteUInt( params[3], 6 ) -- instrument
        net.WriteFloat( params[4] )   -- time offset
    end

    net.Send( targets )
end

concommand.Add( "keyboard_leave", function( ply, _, args )
    if #args < 1 then return end
    local ent = ents.GetByIndex( args[1] )

    if IsAMusicalKeyboard( ent ) and ent.Ply == ply then
        ent:RemovePlayer()
    end
end )

net.Receive( "mkeyboard.notes", function( _, ply )
    local ent = net.ReadEntity()

    -- make sure the client didnt send the wrong entity
    if not IsAMusicalKeyboard( ent ) then return end

    -- make sure the client is actually using this keyboard
    if ply ~= ent.Ply then return end

    local automated = net.ReadBool()
    local noteCount = net.ReadUInt( 5 )
    local notes = {}

    -- make sure the client isn't tricking us
    noteCount = math.Clamp( noteCount, 1, MKeyboard.NET_MAX_NOTES )

    -- read all notes, to make sure we have as
    -- many as the client told us
    for i = 1, noteCount do
        notes[i] = {
            net.ReadUInt( 7 ), -- note
            net.ReadUInt( 7 ), -- velocity
            net.ReadUInt( 6 ), -- instrument
            math.Clamp( net.ReadFloat(), 0, 1 ) -- time offset
        }
    end

    -- then broadcast the notes
    BroadcastNotes( notes, ent, automated, ply )
end )

-- Workaround for hooks that only run serverside on single-player
if game.SinglePlayer() then
    util.AddNetworkString( "mkeyboard.key" )

    hook.Add( "PlayerButtonDown", "mkeyboard_ButtonDownWorkaround", function( ply, button )
        net.Start( "mkeyboard.key", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( true )
        net.Send( ply )
    end )

    hook.Add( "PlayerButtonUp", "mkeyboard_ButtonUpWorkaround", function( ply, button )
        net.Start( "mkeyboard.key", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( false )
        net.Send( ply )
    end )
end