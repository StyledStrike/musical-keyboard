util.AddNetworkString( "mkeyboard.notes" )
util.AddNetworkString( "mkeyboard.set_current_keyboard" )



concommand.Add( "musical_keyboard_leave", function( ply, _, args )
    if #args < 1 then return end

    local ent = ents.GetByIndex( args[1] )

    if MKeyboard.IsAMusicalKeyboard( ent ) and ent.activePlayer == ply then
        ent:RemovePlayer()
    end
end )

hook.Add( "CanUndo", "MKeyboard.BlockUndo", function( ply, undo )
    if not undo.Entities then return end

    local ent = undo.Entities[1]

    if MKeyboard.IsAMusicalKeyboard( ent ) and ply == ent.activePlayer then
        return false
    end
end )
