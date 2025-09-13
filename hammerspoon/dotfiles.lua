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
	-- Expand the home directory path
	local homeDir = os.getenv("HOME")
	local brewFilePath = string.format("%s/dotfiles/brew/Brewfile-%s", homeDir, deviceName)

	-- Use full path to brew (common locations)
	local brewPath = "/opt/homebrew/bin/brew" -- Apple Silicon Macs
	if not hs.fs.attributes(brewPath) then
		brewPath = "/usr/local/bin/brew" -- Intel Macs
	end

	local command = string.format("%s bundle dump --force --file='%s'", brewPath, brewFilePath)

	print(string.format("🔄 Running brew dump command: %s", command))

	local result, status, type, rc = hs.execute(command)

	if status then
		local msg = string.format("✅ Brew bundle dumped to Brewfile-%s", deviceName)
		print(msg)
		utils.notify(msg)
	else
		local msg = string.format("❌ Failed to dump brew bundle for %s (exit code: %s)", deviceName, rc)
		print(msg)
		hs.alert(msg, 5)
		utils.notify(msg)
	end
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

-- Initialize brew dump (run once on startup)
runBrewBundleDump()

-- Schedule weekly brew dump (every 7 days = 604800 seconds)
hs.timer
	.doEvery(604800, function()
		runBrewBundleDump()
	end)
	:start()

dotfiles.sync = syncDotfiles
dotfiles.brewDump = runBrewBundleDump

return dotfiles
