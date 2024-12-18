local config = {
	syncIntervalMins = 30,
}

local function notify(msg)
	hs.notify.show("Hammerspoon", "", msg)
end

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Save brew file
local function runBrewBundleDump()
	hs.execute("brew bundle dump --force --file='~/dotfiles/brew/Brewfile'")
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
				notify(msg)
			end
		end)
		:start()
end
syncDotfiles()
hs.timer
	.doEvery(config.syncIntervalMins * 60, function()
		local idleMins = hs.host.idleTime() / 60
		if idleMins < config.syncIntervalMins then
			syncDotfiles()
		end
	end)
	:start()
