local module = {}

local STATE_DIR = os.getenv("HOME") .. "/.cache/opencode-tmux"

local function tmuxPath()
	local candidates = {"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p) then
			return p
		end
	end
	return nil
end

local menubar = hs.menubar.new()
menubar:returnToMenuBar()

local function update()
	local tmux = tmuxPath()
	if not tmux then
		return
	end

	local out, ok = hs.execute(tmux .. " list-panes -a -F '#{pane_id}'")
	if not ok then
		return
	end

	local live = {}
	for pane in out:gmatch("[^\r\n]+") do
		live[pane:gsub("^%%", "")] = true
	end

	local counts = {working = 0, waiting = 0, done = 0}
	local attr = hs.fs.attributes(STATE_DIR)

	if attr and attr.mode == "directory" then
		for file in hs.fs.dir(STATE_DIR) do
			if not file:match("%.json$") then
				goto continue
			end

			local paneId = file:gsub("%.json$", "")
			if not live[paneId] then
				goto continue
			end

			local f = io.open(STATE_DIR .. "/" .. file, "r")
			if not f then
				goto continue
			end
			local raw = f:read("*a")
			f:close()
			if not raw then
				goto continue
			end

			local ok2, data = pcall(hs.json.decode, raw)
			if not ok2 or type(data) ~= "table" then
				goto continue
			end

			local state = data.state
			local pid = data.pid
			if not state or not pid then
				goto continue
			end

			local _, killOk = hs.execute("kill -0 " .. tostring(pid))
			if not killOk then
				goto continue
			end

			if counts[state] ~= nil then
				counts[state] = counts[state] + 1
			end

			::continue::
		end
	end

	local parts = {}
	if counts.working > 0 then
		table.insert(parts, "\u{25B6} " .. counts.working)
	end
	if counts.waiting > 0 then
		table.insert(parts, "\u{23F8} " .. counts.waiting)
	end
	if counts.done > 0 then
		table.insert(parts, "\u{2713} " .. counts.done)
	end

	menubar:setTitle(table.concat(parts, "  "))
end

local function schedule()
	local ok, err = pcall(update)
	if not ok then
		print("[agent-fleet] " .. tostring(err))
	end
	hs.timer.doAfter(5, schedule)
end

function module.start()
	schedule()
end

module.start()

return module
