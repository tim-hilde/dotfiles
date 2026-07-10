local module = {}

local STATE_DIR = os.getenv("HOME") .. "/.cache/opencode-tmux"

local function tmuxPath()
	local candidates = { "/opt/homebrew/bin/tmux", "/usr/local/bin/tmux" }
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p) then
			return p
		end
	end
	return nil
end

local menubar = hs.menubar.new()
menubar:returnToMenuBar()

local FONT_SIZE = 14

local function isDark()
	local _, ok = hs.execute("defaults read -g AppleInterfaceStyle 2>/dev/null")
	return ok
end

local function renderText(text)
	local w = math.ceil(utf8.len(text) * 7)
	local c = hs.canvas.new({ x = 0, y = 0, w = w, h = 22 })
	local color = isDark() and { white = 1.0 } or { white = 0.0 }
	c:appendElements({
		type = "text",
		text = text,
		textFont = "SF Pro Text",
		textSize = FONT_SIZE,
		textColor = color,
		frame = { x = 0, y = 4, w = w, h = 17 },
		textAlignment = "left",
	})
	return c:imageFromCanvas()
end

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

	local counts = { working = 0, waiting = 0, done = 0 }
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

	local title = table.concat(parts, "  ")

	if title == "" then
		menubar:setIcon(nil)
	else
		menubar:setIcon(renderText(title))
	end
end

function module.start()
	update()
	hs.timer.doEvery(5, update):start()
end

module.start()

return module
