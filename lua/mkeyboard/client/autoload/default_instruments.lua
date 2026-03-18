MKeyboard:RegisterInstrument( "Honky Tonk", "sound/musical_keyboard/instruments/honky_tonk", {
    { note = 24, fileName = "C1.wav" },
    { note = 31, fileName = "G1.wav" },
    { note = 36, fileName = "C2.wav" },
    { note = 43, fileName = "G2.wav" },
    { note = 48, fileName = "C3.wav" },
    { note = 55, fileName = "G3.wav" },
    { note = 60, fileName = "C4.wav" },
    { note = 67, fileName = "G4.wav" },
    { note = 72, fileName = "C5.wav" },
    { note = 79, fileName = "G5.wav" },
    { note = 84, fileName = "C6.wav" },
    { note = 91, fileName = "G6.wav" },
    { note = 96, fileName = "C7.wav" },
    { note = 103, fileName = "G7.wav" }
}, {
    volume = 0.35,
    releaseTime = 0.2
} )

MKeyboard:RegisterInstrument( "Electric Piano", "sound/musical_keyboard/instruments/electric_piano", {
    { note = 36, fileName = "C2.wav", loopStart = 2.659048, loopEnd = 3.516349 },
    { note = 40, fileName = "E2.wav", loopStart = 2.638186, loopEnd = 3.500884 },
    { note = 44, fileName = "G-2.wav", loopStart = 2.626168, loopEnd = 3.397619 },
    { note = 48, fileName = "C3.wav", loopStart = 3.835465, loopEnd = 4.646780 },
    { note = 52, fileName = "E3.wav", loopStart = 2.771474, loopEnd = 3.628095 },
    { note = 56, fileName = "G-3.wav", loopStart = 2.573129, loopEnd = 3.397619 },
    { note = 60, fileName = "C4.wav", loopStart = 2.321859, loopEnd = 3.156122 },
    { note = 64, fileName = "E4.wav", loopStart = 2.275896, loopEnd = 3.105147 },
    { note = 68, fileName = "G-4.wav", loopStart = 2.561066, loopEnd = 3.397619 },
    { note = 72, fileName = "C5.wav", loopStart = 2.776916, loopEnd = 3.614989 },
    { note = 76, fileName = "E5.wav", loopStart = 2.275918, loopEnd = 3.105147 },
    { note = 80, fileName = "G-5.wav", loopStart = 2.568299, loopEnd = 3.397619 },
    { note = 84, fileName = "C6.wav", loopStart = 2.413288, loopEnd = 3.246599 },
    { note = 88, fileName = "E6.wav", loopStart = 2.272132, loopEnd = 3.105147 },
    { note = 92, fileName = "G-6.wav", loopStart = 2.564082, loopEnd = 3.397619 },
    { note = 96, fileName = "C7.wav", loopStart = 2.182857, loopEnd = 3.016168 }
}, {
    volume = 0.25
} )

MKeyboard:RegisterInstrument( "New Age", "sound/musical_keyboard/instruments/new_age", {
    { note = 36, fileName = "C2.wav", loopStart = 1.911791, loopEnd = 4.069683 },
    { note = 48, fileName = "C3.wav", loopStart = 1.621134, loopEnd = 4.185964 },
    { note = 60, fileName = "C4.wav", loopStart = 2.051111, loopEnd = 3.959025 },
    { note = 72, fileName = "C5.wav", loopStart = 1.395170, loopEnd = 4.170136 },
    { note = 84, fileName = "C6.wav", loopStart = 1.777007, loopEnd = 3.984444 },
}, {
    volume = 0.45
} )

MKeyboard:RegisterInstrument( "Choir Aahs", "sound/musical_keyboard/instruments/choir_aahs", {
    { note = 51, fileName = "D-3.wav", loopStart = 1.209750, loopEnd = 2.061156 },
    { note = 54, fileName = "F-3.wav", loopStart = 0.672531, loopEnd = 2.282875 },
    { note = 57, fileName = "A3.wav", loopStart = 0.906000, loopEnd = 2.782812 },
    { note = 60, fileName = "C4.wav", loopStart = 1.424000, loopEnd = 3.015000 },
    { note = 63, fileName = "D-4.wav", loopStart = 1.377406, loopEnd = 3.146000 },
    { note = 66, fileName = "F-4.wav", loopStart = 1.068688, loopEnd = 3.034375 },
    { note = 69, fileName = "A4.wav", loopStart = 0.914312, loopEnd = 2.608875 },
    { note = 72, fileName = "C5.wav", loopStart = 1.301688, loopEnd = 2.557719 },
    { note = 75, fileName = "D-5.wav", loopStart = 1.052000, loopEnd = 2.460469 },
    { note = 78, fileName = "F-5.wav", loopStart = 0.560969, loopEnd = 2.750875 },
    { note = 81, fileName = "A5.wav", loopStart = 0.656969, loopEnd = 2.424594 },
    { note = 84, fileName = "C6.wav", loopStart = 0.562250, loopEnd = 1.660187 },
    { note = 87, fileName = "D-6.wav", loopStart = 0.734000, loopEnd = 2.293594 },
    { note = 90, fileName = "F-6.wav", loopStart = 0.468813, loopEnd = 1.725281 },
    { note = 93, fileName = "A6.wav", loopStart = 0.831469, loopEnd = 2.320781 },
}, {
    releaseTime = 0.6,
    volume = 0.33
} )

local function AddInstrumentWithNoteRange( name, basePath, startNote, endNote, extension, params )
    local samples = {}

    for note = startNote, endNote do
        samples[#samples + 1] = { note = note, fileName = note .. extension }
    end

    MKeyboard:RegisterInstrument( name, basePath, samples, params )
end

AddInstrumentWithNoteRange( "Standard Drums", "sound/musical_keyboard/instruments/drums_standard", 26, 87, ".mp3", {
    volume = 0.4
} )

