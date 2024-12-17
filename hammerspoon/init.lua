local config = {
	syncIntervalMins = 30,
}

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

local function syncOneRepo()
	local syncScriptPath = "~/dotfiles/.sync-this-repo.sh"
	hs.task
		.new(syncScriptPath, function(exitCode, stdout, stderr)
			if exitCode ~= 0 then
				local output = (stdout .. "\n" .. stderr):gsub("^%s+", ""):gsub("%s+$", "")
				local msg = ("⚠️️ %s %s Sync: %s"):format(output)
				print(msg)
				hs.alert(msg, 5)
				notify(msg)
			end
		end)
		:start()
end

timer_repo_syn = hs.timer
	.doEvery(config.syncIntervalMins * 60, function()
		local idleMins = hs.host.idleTime() / 60
		if idleMins < config.syncIntervalMins then
			syncAllGitRepos(false)
		end
	end)
	:start()
