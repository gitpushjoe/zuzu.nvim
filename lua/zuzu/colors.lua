local platform = require("zuzu.platform")

local M = {}

M.reset = platform.choose("\\033[0m", "BrightWhite")

M.black = platform.choose("\\033[30m", "DarkBlack")
M.bright_black = platform.choose("\\033[90m", "Black")

M.red = platform.choose("\\033[31m", "DarkRed")
M.bright_red = platform.choose("\\033[91m", "Red")

M.green = platform.choose("\\033[32m", "DarkGreen")
M.bright_green = platform.choose("\\033[92m", "Green")

M.yellow = platform.choose("\\033[33m", "DarkYellow")
M.bright_yellow = platform.choose("\\033[93m", "Yellow")

M.blue = platform.choose("\\033[34m", "DarkBlue")
M.bright_blue = platform.choose("\\033[94m", "Blue")

M.purple = platform.choose("\\033[35m", "DarkPurple")
M.bright_purple = platform.choose("\\033[95m", "Purple")

M.cyan = platform.choose("\\033[36m", "DarkCyan")
M.bright_cyan = platform.choose("\\033[96m", "Cyan")

M.white = platform.choose("\\033[37m", "BrightWhite")
M.bright_white = platform.choose("\\033[97m", "White")

M.unix2ps = function(color)
	return ({
		["\\033[30m"] = "#000000",
		["\\033[90m"] = "#808080",
		["\\033[31m"] = "#800000",
		["\\033[91m"] = "#FF0000",
		["\\033[32m"] = "#008000",
		["\\033[92m"] = "#00FF00",
		["\\033[33m"] = "#808000",
		["\\033[93m"] = "#FFFF00",
		["\\033[34m"] = "#000080",
		["\\033[94m"] = "#0000FF",
		["\\033[35m"] = "#800080",
		["\\033[95m"] = "#FF00FF",
		["\\033[36m"] = "#008080",
		["\\033[96m"] = "#00FFFF",
		["\\033[37m"] = "#C0C0C0",
		["\\033[97m"] = "#FFFFFF",
	})[color] or color
end

return M
