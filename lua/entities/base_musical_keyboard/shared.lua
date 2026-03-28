ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName = "Musical Keyboard"
ENT.Author = "StyledStrike"
ENT.Contact = "StyledStrike#8032"
ENT.Purpose = "Play a variety of instruments"
ENT.Instructions = "Press E to use the instrument, use your keyboard or a MIDI device (if available) to play."

ENT.Category = "#spawnmenu.category.fun_games"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Editable = true

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "HRTFEnabled", {
        KeyName = "hrtfenabled",
        Edit = { order = 1, type = "Boolean" }
    } )

    local irOptions = {}

    if CLIENT then
        for index, ir in ipairs( MKeyboard.impulseResponses ) do
            irOptions[ir.name] = index
        end

        irOptions["None"] = 0
    end

    self:NetworkVar( "Int", "ImpulseResponseIndex", {
        KeyName = "inpulseresponseindex",
        Edit = { order = 2, type = "Combo", values = irOptions }
    } )

    if CLIENT then
        self:NetworkVarNotify( "HRTFEnabled", self.OnUserVarChanged )
        self:NetworkVarNotify( "ImpulseResponseIndex", self.OnUserVarChanged )
    end
end
