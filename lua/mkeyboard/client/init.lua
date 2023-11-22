MKeyboard.instruments = MKeyboard.instruments or {}
MKeyboard.layouts = MKeyboard.layouts or {}
MKeyboard.sheets = MKeyboard.sheets or {}

function MKeyboard:RegisterInstrument( name, path, noteMin, noteMax )
    self.instruments[#self.instruments + 1] = {
        name = name,
        path = path,
        noteMin = noteMin,
        noteMax = noteMax
    }
end

function MKeyboard:RegisterLayout( id, label, keys )
    self.layouts[#self.layouts + 1] = {
        id = id,
        label = label,
        keys = keys
    }
end

function MKeyboard:RegisterSheet( title, layoutId, sequence )
    if not self.sheets[layoutId] then
        self.sheets[layoutId] = {}
    end

    local layoutSheets = self.sheets[layoutId]

    layoutSheets[#layoutSheets + 1] = {
        title = title,
        sequence = sequence
    }
end


