MKeyboard.settings = MKeyboard.settings or {
    layout = 1,
    instrument = 1,
    sheet = 0,

    velocity = 127,
    transpose = 0,
    midiTranspose = 0,
    drawKeyLabels = true,

    midiCurrentPreset = nil,
    midiChannelPresets = {}
}

MKeyboard.channelInstruments = {}

local function ValidateInteger( n, min, max )
    return math.Round( math.Clamp( tonumber( n ), min, max ) )
end

function MKeyboard:LoadSettings()
    local rawData = file.Read( self.SETTINGS_FILE, "DATA" )
    if not rawData then return end

    local data = util.JSONToTable( rawData ) or {}
    local instrumentCount = #self.instruments
    local settings = self.settings

    -- Last layout that was used on the keyboard
    if data.layout then
        settings.layout = ValidateInteger( data.layout, 1, #self.layouts )
    end

    -- Last instrument that was used on the keyboard
    if data.instrument then
        settings.instrument = ValidateInteger( data.instrument, 1, instrumentCount )
    end

    -- Last selected sheet
    if data.sheet then
        settings.sheet = ValidateInteger( data.sheet, 0, #self.sheets )
    end

    -- Last used velocity
    if data.velocity then
        settings.velocity = ValidateInteger( data.velocity, 1, 127 )
    end

    -- Last used transpose
    if data.transpose then
        settings.transpose = ValidateInteger( data.transpose, -48, 48 )
    end

    -- Last transpose that was used with midi
    if data.midiTranspose then
        settings.midiTranspose = ValidateInteger( data.midiTranspose, -48, 48 )
    end

    -- Draw labels for keys
    settings.drawKeyLabels = Either( isbool( data.drawKeyLabels ), tobool( data.drawKeyLabels ), true )

    -- Presets for links between MIDI channels and instruments
    settings.midiChannelPresets = {}

    if data.midiChannelPresets and type( data.midiChannelPresets ) == "table" then
        for name, channelInstruments in pairs( data.midiChannelPresets ) do
            if type( name ) == "string" and type( data ) == "table" then
                self:SetMIDIChannelPreset( name, channelInstruments )
            end
        end
    end

    settings.midiCurrentPreset = Either( type( data.midiCurrentPreset ) == "string", data.midiCurrentPreset, nil )

    if settings.midiCurrentPreset then
        self:SetCurrentChannelPreset()
    end

    -- Create preset from a old data format
    if data.channelInstruments and type( data.channelInstruments ) == "table" then
        local name = language.GetPhrase( "musicalk.channels" )

        self:SetMIDIChannelPreset( name, data.channelInstruments )
        self:SetCurrentChannelPreset( name )
    end
end

function MKeyboard:SaveSettings()
    local settings = self.settings

    file.Write(
        self.SETTINGS_FILE,
        util.TableToJSON( {
            layout              = settings.layout,
            instrument          = settings.instrument,
            sheet               = settings.sheet,

            velocity            = settings.velocity,
            transpose           = settings.transpose,
            midiTranspose       = settings.midiTranspose,
            drawKeyLabels       = settings.drawKeyLabels,

            midiCurrentPreset   = settings.midiCurrentPreset,
            midiChannelPresets  = settings.midiChannelPresets
        }, true )
    )
end

function MKeyboard:SetMIDIChannelPreset( name, channelInstruments )
    channelInstruments = channelInstruments or {}

    local preset = {}
    local itemCount = 0
    local instrumentCount = #self.instruments

    for channelIndex, instrumentIndex in pairs( channelInstruments ) do
        channelIndex = ValidateInteger( channelIndex, self.FIRST_MIDI_CHANNEL, self.LAST_MIDI_CHANNEL )
        instrumentIndex = ValidateInteger( instrumentIndex, 1, instrumentCount )

        itemCount = itemCount + 1
        preset[channelIndex] = instrumentIndex
    end

    self.settings.midiChannelPresets[name] = Either( itemCount > 0, preset, nil )
end

function MKeyboard:SetCurrentChannelPreset( name )
    name = name or self.settings.midiCurrentPreset

    local channelInstruments = {}
    local preset = Either( name == nil, {}, self.settings.midiChannelPresets[name] or {} )

    for channelIndex, instrumentIndex in pairs( preset ) do
        channelInstruments[channelIndex] = instrumentIndex
    end

    self.settings.midiCurrentPreset = name
    self.channelInstruments = channelInstruments
end
