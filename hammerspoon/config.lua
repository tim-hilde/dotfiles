local config = {
	syncIntervalMins = 30,
	doubleTapThreshold = 0.5,
	agentFleet = {
		hotkeyMods = { "cmd", "alt", "ctrl" },
		hotkeyKey = "o",
		pollIntervalSecs = 2,
		stateDir = os.getenv("HOME") .. "/.cache/opencode-tmux",
	},
}

return config
