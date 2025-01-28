local platform = require"zuzu.platform"

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

return M
