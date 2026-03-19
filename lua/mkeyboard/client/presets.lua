
function MKeyboard:RegisterInstrument( name, basePath, samples, params )
    assert( type( name ) == "string", "'name' must be a string!" )
    assert( type( basePath ) == "string", "'basePath' must be a string!" )
    assert( type( samples ) == "table", "'samples' must be a table!" )

    if params ~= nil then
        assert( type( params ) == "table", "'params' must be a table!" )
    end

    -- The sampling logic requires the notes to be in ascending order
    table.SortByMember( samples, "note", true )

    local instrument = {
        name = name,
        basePath = basePath,
        samples = samples,
        params = params
    }

    -- Replace instrument with the same name (if it exists)
    local _, index = self:GetInstrumentByName( name )

    if not index then
        index = #self.instruments + 1
    end

    self.instruments[index] = instrument
end

function MKeyboard:GetInstrumentByName( name )
    for index, instrument in ipairs( self.instruments ) do
        if instrument.name == name then
            return instrument, index
        end
    end
end

function MKeyboard:RegisterLayout( id, name, keys, noteOffset )
    assert( type( id ) == "string", "'id' must be a string!" )
    assert( type( name ) == "string", "'name' must be a string!" )
    assert( type( keys ) == "table", "'keys' must be a table!" )

    local layout = {
        id = id,
        name = name,
        keys = keys
    }

    if noteOffset then
        for _, key in pairs( layout.keys ) do
            key.note = key.note + noteOffset
        end
    end

    -- Replace layout with the same ID (if it exists)
    local _, index = self:GetLayoutById( id )

    if not index then
        index = #self.layouts + 1
    end

    self.layouts[index] = layout
end

function MKeyboard:GetLayoutById( id )
    for index, layout in ipairs( self.layouts ) do
        if layout.id == id then
            return layout, index
        end
    end
end

function MKeyboard:RegisterSheet( title, layoutId, getSequence )
    assert( type( title ) == "string", "'title' must be a string!" )
    assert( type( layoutId ) == "string", "'layoutId' must be a string!" )
    assert( type( getSequence ) == "function", "'getSequence' must be a function!" )

    local sheet = {
        title = title,
        layoutId = layoutId,
        getSequence = getSequence
    }

    -- Replace sheet with the same title (if it exists)
    local _, index = self:GetSheetByTitle( title )

    if not index then
        index = #self.sheets + 1
    end

    self.sheets[index] = sheet
end

function MKeyboard:GetSheetByTitle( title )
    for index, sheet in ipairs( self.sheets ) do
        if sheet.title == title then
            return sheet, index
        end
    end
end

function MKeyboard:RegisterImpulseResponse( name, fileName )
    assert( type( name ) == "string", "'name' must be a string!" )
    assert( type( fileName ) == "string", "'fileName' must be a string!" )

    local ir = {
        name = name,
        fileName = fileName,
    }

    -- Replace impulse response with the same name (if it exists)
    local _, index = self:GetImpulseResponseByName( name )

    if not index then
        index = #self.impulseResponses + 1
    end

    self.impulseResponses[index] = ir
end

function MKeyboard:GetImpulseResponseByName( name )
    for index, ir in ipairs( self.impulseResponses ) do
        if ir.name == name then
            return ir, index
        end
    end
end

MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.cavern", "cavern.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.church", "church.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.cinema_room", "cinema_room.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.hall_large", "hall_large.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.hall_small", "hall_small.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.hillside", "hillside.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.music_room", "music_room.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.scoring_stage", "scoring_stage.wav" )
MKeyboard:RegisterImpulseResponse( "#mkeyboard.ir.studio", "studio.wav" )
