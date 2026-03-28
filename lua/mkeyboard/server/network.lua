util.AddNetworkString( "mkeyboard.set_current_keyboard" )
util.AddNetworkString( "mkeyboard.notes" )

local MAX_DISTANCE_SQR = MKeyboard.MAX_PROCESSING_DISTANCE * MKeyboard.MAX_PROCESSING_DISTANCE

local function GetNearbyPlayers( pos, ignorePly )
    local targets = {}
    local count = 0

    for _, ply in ipairs( player.GetHumans() ) do
        if ply ~= ignorePly and pos:DistToSqr( ply:GetPos() ) < MAX_DISTANCE_SQR then
            count = count + 1
            targets[count] = ply
        end
    end

    return targets
end

MKeyboard.GetNearbyPlayers = GetNearbyPlayers

local netCooldown = {}

net.Receive( "mkeyboard.notes", function( _, ply )
    local id = ply:SteamID()
    local t = RealTime()

    if netCooldown[id] and netCooldown[id] > t then
        MKeyboard.Print( "%s <%s> sent network commands too fast!", ply:Nick(), id )
        return
    end

    netCooldown[id] = t + MKeyboard.TRANSMIT_BUFFER_INTERVAL * 0.25

    local entity = net.ReadEntity()

    if not MKeyboard.IsAMusicalKeyboard( entity ) then return end
    if ply ~= entity.activePlayer then return end

    local targets = GetNearbyPlayers( entity:GetPos(), ply )
    if #targets < 1 then return end

    local events = MKeyboard.ReadEvents()

    net.Start( "mkeyboard.notes", false )
    net.WriteEntity( entity )
    MKeyboard.WriteEvents( events )
    net.Send( targets )
end )

hook.Add( "PlayerDisconnected", "MKeyboard.NetCleanup", function( ply )
    netCooldown[ply:SteamID()] = nil
end )
