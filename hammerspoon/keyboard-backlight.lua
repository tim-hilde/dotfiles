local config = require("config")

local keyboardBacklight = {}

local binaryPath = os.getenv("HOME") .. "/.local/bin/keychron-backlight"
local level = config.keyboardBacklightLevel
local lastDark = nil

local function isDarkMode()
	return hs.execute("defaults read -g AppleInterfaceStyle 2>/dev/null"):gsub("%s+", "") == "Dark"
end

local function isLocked()
	local props = hs.caffeinate.sessionProperties()
	return props ~= nil and props.CGSSessionScreenIsLocked == true
end

local function apply()
	if isLocked() then
		return
	end
	local dark = isDarkMode()
	if dark == lastDark then
		return
	end
	lastDark = dark

	local task = hs.task.new(binaryPath, function(exitCode, _, stderr)
		if exitCode ~= 0 then
			print(("[keyboard-backlight] exit %d: %s"):format(exitCode, (stderr or ""):gsub("%s+$", "")))
		end
	end, { dark and tostring(level) or "off" })

	if not (task and task:start()) then
		print("[keyboard-backlight] failed to start " .. binaryPath .. " (build: swiftc -O -o ~/.local/bin/keychron-backlight ~/dotfiles/hammerspoon/bin/keychron-backlight.swift)")
	end
end

keyboardBacklight.watcher = hs.distributednotifications.new(apply, "AppleInterfaceThemeChangedNotification")
keyboardBacklight.watcher:start()

keyboardBacklight.lockWatcher = hs.caffeinate.watcher.new(function(event)
	if event == hs.caffeinate.watcher.screensDidUnlock then
		apply()
	end
end)
keyboardBacklight.lockWatcher:start()

apply()

return keyboardBacklight
