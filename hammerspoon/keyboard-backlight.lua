local config = require("config")

local keyboardBacklight = {}

local binaryPath = os.getenv("HOME") .. "/.local/bin/keychron-backlight"
local level = config.keyboardBacklightLevel
local lastDark = nil

local function isDarkMode()
	return hs.execute("defaults read -g AppleInterfaceStyle 2>/dev/null"):gsub("%s+", "") == "Dark"
end

local function apply()
	local dark = isDarkMode()
	if dark == lastDark then
		return
	end
	lastDark = dark

	local task, err = hs.task
		.new(binaryPath, function(exitCode, _, stderr)
			if exitCode ~= 0 then
				print(("[keyboard-backlight] exit %d: %s"):format(exitCode, (stderr or ""):gsub("%s+$", "")))
			end
		end, { dark and tostring(level) or "off" })
		:start()
	if not task then
		print("[keyboard-backlight] failed to start helper: " .. tostring(err))
	end
end

keyboardBacklight.watcher = hs.distributednotifications.new(apply, "AppleInterfaceThemeChangedNotification")
keyboardBacklight.watcher:start()

apply()

return keyboardBacklight
