local config = require("config")

local clipboardHistory = {}

-- Function to update clipboard history
local function updateClipboardHistory(content)
	if content and content ~= "" then
		-- Remove if already exists to avoid duplicates
		for i, item in ipairs(clipboardHistory) do
			if item == content then
				table.remove(clipboardHistory, i)
				break
			end
		end

		-- Insert at beginning
		table.insert(clipboardHistory, 1, content)

		-- Keep only last 2 items
		if #clipboardHistory > 2 then
			clipboardHistory[3] = nil
		end
	end
end

-- Monitor clipboard changes
local clipboardWatcher = hs.pasteboard.watcher.new(function()
	local currentContent = hs.pasteboard.getContents()
	updateClipboardHistory(currentContent)
end)

clipboardWatcher:start()

-- Fast append functionality
local function fastAppendClipboard()
	-- Copy current selection
	hs.eventtap.keyStroke({ "cmd" }, "c")

	-- Small delay to ensure copy operation completes
	hs.timer.doAfter(0.1, function()
		local newContent = hs.pasteboard.getContents()

		if newContent and newContent ~= "" then
			local previousContent = clipboardHistory[2] or ""

			if previousContent ~= "" then
				-- Merge with newline separator
				local mergedContent = previousContent .. "\n" .. newContent
				hs.pasteboard.setContents(mergedContent)
			end
		end
	end)
end

-- Double tap detection for Cmd+C+C
local doubleTapTimer = nil
local firstTap = false

hs.hotkey.bind({ "cmd" }, "c", function()
	if firstTap then
		-- Second tap - trigger fast append
		if doubleTapTimer then
			doubleTapTimer:stop()
			doubleTapTimer = nil
		end
		firstTap = false
		fastAppendClipboard()
	else
		-- First tap - perform normal copy
		firstTap = true
		hs.eventtap.keyStroke({ "cmd" }, "c")

		-- Reset after 0.5 seconds
		doubleTapTimer = hs.timer.doAfter(0.5, function()
			firstTap = false
			doubleTapTimer = nil
		end)
	end
end)

-- Initialize with current clipboard content
local initialContent = hs.pasteboard.getContents()
if initialContent then
	updateClipboardHistory(initialContent)
end

return {}
