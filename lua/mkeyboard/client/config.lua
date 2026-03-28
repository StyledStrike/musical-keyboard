local Config = MKeyboard.Config

function Config:Reset()
    -- User selection
    self.selectedLayoutId = "compact"
    self.selectedInstrumentIndex = 1
    self.selectedSheetIndex = 0 -- 0 for none

    -- Interface options
    self.drawButtonLabels = true
    self.sortSheetsAlphabetically = false

    -- Options for playing with a PC keyboard
    self.keyboardVelocity = 127
    self.keyboardTranspose = 0

    -- Options for playing with a MIDI device
    local defaultPresetName = "#preset.default"

    self.midiTranspose = 0
    self.midiChannelMapPresets = { [defaultPresetName] = {} }
    self.midiSelectedChannelMapPresetName = defaultPresetName
end

function Config:Save( immediate )
    timer.Remove( "MKeyboard.SaveConfig" )

    if not immediate then
        -- Don't spam when this function gets called in quick succession
        timer.Create( "MKeyboard.SaveConfig", 1, 1, function()
            self:Save( true )
        end )

        return
    end

    local data = util.TableToJSON( {
        selectedLayoutId = self.selectedLayoutId,
        selectedInstrumentIndex = self.selectedInstrumentIndex,
        selectedSheetIndex = self.selectedSheetIndex,

        drawButtonLabels = self.drawButtonLabels,
        sortSheetsAlphabetically = self.sortSheetsAlphabetically,

        keyboardVelocity = self.keyboardVelocity,
        keyboardTranspose = self.keyboardTranspose,

        midiTranspose = self.midiTranspose,
        midiChannelMapPresets = self.midiChannelMapPresets,
        midiSelectedChannelMapPresetName = self.midiSelectedChannelMapPresetName

    }, true )

    MKeyboard.SaveDataFile( "musical_keyboard_user_config.json", data )
end

local SetNumber = MKeyboard.SetNumber

function Config:Load()
    self:Reset()

    local data = MKeyboard.JSONToTable( MKeyboard.LoadDataFile( "musical_keyboard_user_config.json" ) )

    local LoadBool = function( k, default )
        self[k] = Either( data[k] == nil, default, data[k] == true )
    end

    if type( data.selectedLayoutId ) == "string" then
        local layout = MKeyboard:GetLayoutById( data.selectedLayoutId )

        if layout then
            self.selectedLayoutId = data.selectedLayoutId
        end
    end

    SetNumber( self, "selectedInstrumentIndex", data.selectedInstrumentIndex,
        1, #MKeyboard.instruments, self.selectedInstrumentIndex )

    SetNumber( self, "selectedSheetIndex", data.selectedSheetIndex,
        0, #MKeyboard.sheets, self.selectedSheetIndex )

    LoadBool( "drawButtonLabels", self.drawButtonLabels )
    LoadBool( "sortSheetsAlphabetically", self.sortSheetsAlphabetically )

    SetNumber( self, "keyboardVelocity", data.keyboardVelocity, 1, 127, self.keyboardVelocity )
    SetNumber( self, "keyboardTranspose", data.keyboardTranspose, -48, 48, self.keyboardTranspose )

    SetNumber( self, "midiTranspose", data.midiTranspose, -48, 48, self.midiTranspose )

    if type( data.midiChannelMapPresets ) == "table" then
        for name, mappings in pairs( data.midiChannelMapPresets ) do
            if type( name ) == "string" and type( mappings ) == "table" then
                self:AddMidiChannelMapPreset( name, mappings )
            end
        end
    end

    if
        type( data.midiSelectedChannelMapPresetName ) == "string" and
        self.midiChannelMapPresets[data.midiSelectedChannelMapPresetName]
    then
        self.midiSelectedChannelMapPresetName = data.midiSelectedChannelMapPresetName
    end
end

function Config:AddMidiChannelMapPreset( name, mappings )
    local channelInstrumentMap = {}
    local instrumentCount = #MKeyboard.instruments

    for channel = MKeyboard.MIDI_CHANNEL_ID_MIN, MKeyboard.MIDI_CHANNEL_ID_MAX do
        SetNumber( channelInstrumentMap, channel, mappings[channel], -1, instrumentCount, -1 )
    end

    self.midiChannelMapPresets[name] = channelInstrumentMap
end

function Config:GetInstrumentFromCurrentChannelMap( channelIndex )
    local channelInstrumentMap = self.midiChannelMapPresets[self.midiSelectedChannelMapPresetName]
    if not channelInstrumentMap then return end

    local instrumentIndex = channelInstrumentMap[channelIndex]
    if not instrumentIndex then return end

    -- "0" means "Mute this channel"
    if instrumentIndex == 0 then return end

    -- "-1" means "Use the instrument from the Virtual Keyboard"
    if instrumentIndex == -1 then
        return Config.selectedInstrumentIndex
    end

    return instrumentIndex
end
