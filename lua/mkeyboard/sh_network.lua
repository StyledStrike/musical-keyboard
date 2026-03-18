-- TODO: constants, read/write functions



-- Workaround for the button hooks that only run serverside on single-player
if not game.SinglePlayer() then return end

if SERVER then
    util.AddNetworkString( "mkeyboard.button_event" )

    hook.Add( "PlayerButtonDown", "MKeyboard.ButtonDownWorkaround", function( ply, button )
        net.Start( "mkeyboard.button_event", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( true )
        net.Send( ply )
    end )

    hook.Add( "PlayerButtonUp", "MKeyboard.ButtonUpWorkaround", function( ply, button )
        net.Start( "mkeyboard.button_event", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( false )
        net.Send( ply )
    end )
end

if CLIENT then
    net.Receive( "mkeyboard.button_event", function()
        local button = net.ReadUInt( 8 )
        local pressed = net.ReadBool()

        if IsValid( MKeyboard.entity ) then
            if pressed then
                MKeyboard:OnButtonPress( button )
            else
                MKeyboard:OnButtonRelease( button )
            end
        end
    end )
end
