MKeyboard.Layouts = {}

function MKeyboard:RegisterLayout(name, keys, octaveLimits)
	self.Layouts[#self.Layouts + 1] = {
		name = name,
		keys = keys,
		octaveLimits = octaveLimits
	}
end

-- ##### Default keyboard layouts ##### --

MKeyboard:RegisterLayout('Compact', {
	-- key, note, type, label
	{KEY_A, 60, 'w', 'a'},
	{KEY_W, 61, 'b', 'w'},
	{KEY_S, 62, 'w', 's'},
	{KEY_E, 63, 'b', 'e'},
	{KEY_D, 64, 'w', 'd'},
	{KEY_F, 65, 'w', 'f'},
	{KEY_T, 66, 'b', 't'},
	{KEY_G, 67, 'w', 'g'},
	{KEY_Y, 68, 'b', 'y'},
	{KEY_H, 69, 'w', 'h'},
	{KEY_U, 70, 'b', 'u'},
	{KEY_J, 71, 'w', 'j'},
	{KEY_K, 72, 'w', 'k'},
	{KEY_O, 73, 'b', 'o'},
	{KEY_L, 74, 'w', 'l'},
	{KEY_P, 75, 'b', 'p'},
	{KEY_SEMICOLON, 76, 'w', ';'},
	{KEY_APOSTROPHE, 77, 'w', '\''}
}, {
	min = -3, max = 2
})

MKeyboard:RegisterLayout('Expanded', {
	-- key, note, type, label, require SHIFT
	{KEY_1, 36, 'w', '1'},
	{KEY_1, 37, 'b', '!', true},
	{KEY_2, 38, 'w', '2'},
	{KEY_2, 39, 'b', '@', true},
	{KEY_3, 40, 'w', '3'},
	{KEY_4, 41, 'w', '4'},
	{KEY_4, 42, 'b', '$', true},
	{KEY_5, 43, 'w', '5'},
	{KEY_5, 44, 'b', '%', true},
	{KEY_6, 45, 'w', '6'},
	{KEY_6, 46, 'b', '^', true},
	{KEY_7, 47, 'w', '7'},
	{KEY_8, 48, 'w', '8'},
	{KEY_8, 49, 'b', '*', true},
	{KEY_9, 50, 'w', '9'},
	{KEY_9, 51, 'b', '(', true},
	{KEY_0, 52, 'w', '0'},

	{KEY_Q, 53, 'w', 'q'},
	{KEY_Q, 54, 'b', 'Q', true},
	{KEY_W, 55, 'w', 'w'},
	{KEY_W, 56, 'b', 'W', true},
	{KEY_E, 57, 'w', 'e'},
	{KEY_E, 58, 'b', 'E', true},
	{KEY_R, 59, 'w', 'r'},
	{KEY_T, 60, 'w', 't'},
	{KEY_T, 61, 'b', 'T', true},
	{KEY_Y, 62, 'w', 'y'},
	{KEY_Y, 63, 'b', 'Y', true},
	{KEY_U, 64, 'w', 'u'},
	{KEY_I, 65, 'w', 'i'},
	{KEY_I, 66, 'b', 'I', true},
	{KEY_O, 67, 'w', 'o'},
	{KEY_O, 68, 'b', 'O', true},
	{KEY_P, 69, 'w', 'p'},
	{KEY_P, 70, 'b', 'P', true},

	{KEY_A, 71, 'w', 'a'},
	{KEY_S, 72, 'w', 's'},
	{KEY_S, 73, 'b', 'S', true},
	{KEY_D, 74, 'w', 'd'},
	{KEY_D, 75, 'b', 'D', true},
	{KEY_F, 76, 'w', 'f'},
	{KEY_G, 77, 'w', 'g'},
	{KEY_G, 78, 'b', 'G', true},
	{KEY_H, 79, 'w', 'h'},
	{KEY_H, 80, 'b', 'H', true},
	{KEY_J, 81, 'w', 'j'},
	{KEY_J, 82, 'b', 'J', true},
	{KEY_K, 83, 'w', 'k'},
	{KEY_L, 84, 'w', 'l'},
	{KEY_L, 85, 'b', 'L', true},

	{KEY_Z, 86, 'w', 'z'},
	{KEY_Z, 87, 'b', 'Z', true},
	{KEY_X, 88, 'w', 'x'},
	{KEY_C, 89, 'w', 'c'},
	{KEY_C, 90, 'b', 'C', true},
	{KEY_V, 91, 'w', 'v'},
	{KEY_V, 92, 'b', 'V', true},
	{KEY_B, 93, 'w', 'b'},
	{KEY_B, 94, 'b', 'B', true},
	{KEY_N, 95, 'w', 'n'},
	{KEY_M, 96, 'w', 'm'}
}, {
	min = -2, max = 1
})

MKeyboard:RegisterLayout('FL Style', {
	-- key, note, type, label, require SHIFT, alternative key
	{KEY_Z, 24, 'w', 'z'},
	{KEY_S, 25, 'b', 's'},
	{KEY_X, 26, 'w', 'x'},
	{KEY_D, 27, 'b', 'd'},
	{KEY_C, 28, 'w', 'c'},
	{KEY_V, 29, 'w', 'v'},
	{KEY_G, 30, 'b', 'g'},
	{KEY_B, 31, 'w', 'b'},
	{KEY_H, 32, 'b', 'h'},
	{KEY_N, 33, 'w', 'n'},
	{KEY_J, 34, 'b', 'j'},
	{KEY_M, 35, 'w', 'm'},

	{KEY_Q, 36, 'w', 'q', false, KEY_COMMA, ','},
	{KEY_2, 37, 'b', '2', false, KEY_L, 'l'},
	{KEY_W, 38, 'w', 'w', false, KEY_PERIOD, '.'},
	{KEY_3, 39, 'b', '3', false, KEY_SEMICOLON, ';'},
	{KEY_E, 40, 'w', 'e', false, KEY_SLASH, '/'},
	{KEY_R, 41, 'w', 'r'},
	{KEY_5, 42, 'b', '5'},
	{KEY_T, 43, 'w', 't'},
	{KEY_6, 44, 'b', '6'},
	{KEY_Y, 45, 'w', 'y'},
	{KEY_7, 46, 'b', '7'},
	{KEY_U, 47, 'w', 'u'},
	{KEY_I, 48, 'w', 'i'},
	{KEY_9, 49, 'b', '9'},
	{KEY_O, 50, 'w', 'o'},
	{KEY_0, 51, 'b', '0'},
	{KEY_P, 52, 'w', 'p'},
	{KEY_LBRACKET, 53, 'w', '['},
	{KEY_EQUAL, 54, 'b', '='},
	{KEY_RBRACKET, 55, 'w', ']'}
}, {
	min = 0, max = 3
})