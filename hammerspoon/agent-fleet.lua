local config = require("config")
local parse = require("agent-fleet-parse")

local agentFleet = {}

local SCRIPT_PATH = os.getenv("HOME") .. "/dotfiles/tmux/agent-fleet-list.sh"

local STATE_ICON = { waiting = "\u{f04c}", working = "\u{f04b}", done = "\u{f00c}" }
local STATE_COLOR = {
	waiting = { hex = "#f38ba8" }, -- Catppuccin Mocha red
	working = { hex = "#f9e2af" }, -- Catppuccin Mocha yellow
	done = { hex = "#a6e3a1" }, -- Catppuccin Mocha green
}
local STATE_RENDER_ORDER = { "working", "waiting", "done" }

-- Resolve tmux's absolute path once: hs.task needs a fixed launchPath and
-- Hammerspoon's own process PATH may not include Homebrew's bin dirs.
local function resolveBinary(name, candidates)
	for _, path in ipairs(candidates) do
		if hs.fs.attributes(path) then
			return path
		end
	end
	return name
end

local TMUX_PATH = resolveBinary("tmux", { "/opt/homebrew/bin/tmux", "/usr/local/bin/tmux" })

local menubarItem = hs.menubar.new()
local chooser = nil
local lastByPane = {}
local lastRecords = {}

local function hasAttachedClient()
	local output, ok = hs.execute(TMUX_PATH .. " list-clients -F '#{client_tty}' 2>/dev/null")
	return ok == true and output ~= nil and output:match("%S") ~= nil
end

local function runTmux(args)
	local task = hs.task.new(TMUX_PATH, nil, args)
	if task then
		task:start()
	end
end

-- Bring the given agent's pane to the foreground: select it within tmux,
-- then focus Ghostty. Falls back to launching Ghostty + tmux attach when no
-- client is currently attached (rare in the observed single-client setup).
local function jumpTo(record)
	local window = parse.windowOf(record)
	if hasAttachedClient() then
		runTmux({ "switch-client", "-t", record.session })
		if window then
			runTmux({ "select-window", "-t", record.session .. ":" .. window })
		end
		runTmux({ "select-pane", "-t", record.pane })
	else
		local task = hs.task.new(
			"/usr/bin/open",
			nil,
			{ "-na", "Ghostty", "--args", "-e", TMUX_PATH, "attach", "-t", record.session }
		)
		if task then
			task:start()
		end
	end
	hs.application.launchOrFocus("Ghostty")
end

local function renderMenubar(records)
	if not menubarItem then
		return
	end
	local counts = parse.countByState(records)
	if counts.working == 0 and counts.waiting == 0 and counts.done == 0 then
		menubarItem:setTitle("")
		return
	end
	local styled = hs.styledtext.new("")
	for _, state in ipairs(STATE_RENDER_ORDER) do
		if counts[state] > 0 then
			styled = styled
				.. hs.styledtext.new(string.format(" %s %d ", STATE_ICON[state], counts[state]), {
					color = STATE_COLOR[state],
					font = { name = "JetBrainsMono Nerd Font Mono", size = 13 },
				})
		end
	end
	menubarItem:setTitle(styled)
end

local function notifyTransition(transition)
	local record = transition.record
	local icon = STATE_ICON[transition.kind]
	local verb = transition.kind == "waiting" and "needs you" or "done"
	hs.notify
		.new(function()
			jumpTo(record)
		end, {
			title = record.project,
			informativeText = string.format("%s %s: %s", icon, verb, record.title),
			autoWithdraw = true,
		})
		:send()
end

local function choicesFromRecords(records)
	local choices = {}
	for _, record in ipairs(records) do
		table.insert(choices, {
			text = string.format("%s — %s", record.project, record.title ~= "" and record.title or "(untitled)"),
			subText = string.format(
				"%s %s · %s · %s",
				STATE_ICON[record.state] or "",
				record.state,
				record.target,
				record.pane
			),
			record = record,
		})
	end
	return choices
end

local function chooserSelected(choice)
	if choice and choice.record then
		jumpTo(choice.record)
	end
end

local function openPicker()
	if not chooser then
		return
	end
	chooser:choices(choicesFromRecords(lastRecords))
	chooser:show()
end

local function refresh()
	local task = hs.task.new(SCRIPT_PATH, function(exitCode, stdout)
		if exitCode ~= 0 then
			return
		end
		local records = parse.sortRecords(parse.parseRecords(stdout or ""))
		lastRecords = records
		renderMenubar(records)

		local transitions, currentByPane = parse.diffTransitions(lastByPane, records)
		for _, transition in ipairs(transitions) do
			notifyTransition(transition)
		end
		lastByPane = currentByPane
	end, {})
	if task then
		task:start()
	end
end

chooser = hs.chooser.new(chooserSelected)
hs.hotkey.bind(config.agentFleet.hotkeyMods, config.agentFleet.hotkeyKey, openPicker)

local pollTimer = hs.timer.doEvery(config.agentFleet.pollIntervalSecs, refresh)
pollTimer:start()

-- pathwatcher requires the directory to exist; on a machine with no
-- opencode-tmux state yet, skip it and rely on the poll timer only.
if hs.fs.attributes(config.agentFleet.stateDir) then
	local stateWatcher = hs.pathwatcher.new(config.agentFleet.stateDir, function()
		hs.timer.doAfter(0.2, refresh)
	end)
	stateWatcher:start()
end

refresh()

agentFleet.refresh = refresh
agentFleet.openPicker = openPicker

return agentFleet
