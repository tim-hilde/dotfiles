local config = require("config")

local clipboard = {}

-- Double-tap Cmd+C state
local lastCmdCTime = 0
local previousClipboard = ""

-- Double-tap Cmd+C to merge clipboard content

hs.hotkey.bind({ "cmd" }, "c", function()
	local currentTime = hs.timer.secondsSinceEpoch()
	local timeSinceLastC = currentTime - lastCmdCTime

	if timeSinceLastC <= config.doubleTapThreshold and timeSinceLastC > 0.05 then
		-- Double-tap detected - merge text
		-- First copy the selected text
		hs.eventtap.keyStroke({ "cmd" }, "c", 0)

		hs.timer.doAfter(0.1, function()
			local currentText = hs.pasteboard.getContents() or ""
			if currentText ~= "" and previousClipboard ~= "" then
				local mergedText = previousClipboard .. "\n" .. currentText
				hs.pasteboard.setContents(mergedText)
				hs.alert.show("Text merged!")
			end
		end)

		lastCmdCTime = 0 -- Reset to prevent further double-taps
	else
		-- Normal Cmd+C - store current clipboard for potential merge
		-- Let the original event pass through first
		hs.timer.doAfter(0.05, function()
			previousClipboard = hs.pasteboard.getContents() or ""
		end)
		lastCmdCTime = currentTime
		-- Don't intercept, let the original event through
		return false
	end
end)

return clipboard
