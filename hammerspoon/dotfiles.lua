local config = require("config")
local utils = require("utils")

local dotfiles = {}

-- Get device name for file prefixing
local function getDeviceName()
	return hs.host.localizedName():gsub("%s+", "-"):lower()
end

-- Save brew file with device prefix
local function runBrewBundleDump()
	local deviceName = getDeviceName()
	local brewFilePath = string.format("~/dotfiles/brew/Brewfile-%s", deviceName)
	hs.execute(string.format("brew bundle dump --force --file='%s'", brewFilePath))
end

-- Sync dotfiles
local function syncDotfiles()
	local syncScriptPath = "~/dotfiles/sync-this-repo.sh"
	hs.task
		.new(syncScriptPath, function(exitCode, stdout, stderr)
			if exitCode ~= 0 then
				local output = (stdout .. "\n" .. stderr):gsub("^%s+", ""):gsub("%s+$", "")
				local msg = ("⚠️️ %s"):format(output)
				print(msg)
				hs.alert(msg, 5)
				utils.notify(msg)
			end
		end)
		:start()
end

-- Initialize dotfiles sync
syncDotfiles()
hs.timer
	.doEvery(config.syncIntervalMins * 30, function()
		local idleMins = hs.host.idleTime() / 30
		if idleMins < config.syncIntervalMins then
			syncDotfiles()
		end
	end)
	:start()

dotfiles.sync = syncDotfiles
dotfiles.brewDump = runBrewBundleDump

return dotfiles
