local platform = require("zuzu.platform")

local M = {}

M.reset = platform.choose("\\033[0m", "BrightWhite")

M.black = platform.choose("\\033[30m", "Black")
M.bright_black = platform.choose("\\033[90m", "BrightBlack")

M.red = platform.choose("\\033[31m", "Red")
M.bright_red = platform.choose("\\033[91m", "BrightRed")

M.green = platform.choose("\\033[32m", "Green")
M.bright_green = platform.choose("\\033[92m", "BrightGreen")

M.yellow = platform.choose("\\033[33m", "Yellow")
M.bright_yellow = platform.choose("\\033[93m", "BrightYellow")

M.blue = platform.choose("\\033[34m", "Blue")
M.bright_blue = platform.choose("\\033[94m", "BrightBlue")

M.purple = platform.choose("\\033[35m", "Purple")
M.bright_purple = platform.choose("\\033[95m", "BrightPurple")

M.cyan = platform.choose("\\033[36m", "Cyan")
M.bright_cyan = platform.choose("\\033[96m", "BrightCyan")

M.white = platform.choose("\\033[37m", "White")
M.bright_white = platform.choose("\\033[97m", "BrightWhite")

M.unix2ps = function(color)
	return ({
		["\\033[0m"] = "White", -- Default
		["\\033[30m"] = "Black", -- Black
		["\\033[90m"] = "#808080", -- BrightBlack
		["\\033[31m"] = "Red", -- Red
		["\\033[91m"] = "#FF5555", -- BrightRed
		["\\033[32m"] = "Green", -- Green
		["\\033[92m"] = "#55FF55", -- BrightGreen
		["\\033[33m"] = "Yellow", -- Yellow
		["\\033[93m"] = "#FFFF55", -- BrightYellow
		["\\033[34m"] = "Blue", -- Blue
		["\\033[94m"] = "#5555FF", -- BrightBlue
		["\\033[35m"] = "Purple", -- Purple
		["\\033[95m"] = "#FF55FF", -- BrightPurple
		["\\033[36m"] = "Cyan", -- Cyan
		["\\033[96m"] = "#55FFFF", -- BrightCyan
		["\\033[37m"] = "White", -- White
		["\\033[97m"] = "White", -- BrightWhite maps to White
	})[color] or color
end

return M
