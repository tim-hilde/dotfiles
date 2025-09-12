local config = require("config")

local clipboard = {}

-- Double-tap Cmd+C state
local lastCmdCTime = 0

-- Double-tap Cmd+C to merge clipboard content
hs.hotkey.bind({ "cmd" }, "c", function()
	local currentTime = hs.timer.secondsSinceEpoch()
	local timeSinceLastC = currentTime - lastCmdCTime

	if timeSinceLastC <= config.doubleTapThreshold then
		-- Double-tap detected - merge text
		hs.eventtap.keyStroke({ "cmd" }, "c") -- Copy selected text
		hs.timer.doAfter(0.1, function()
			local currentText = hs.pasteboard.getContents()
			local previousText = hs.pasteboard.getHistory()[2] or ""
			local mergedText = previousText .. "\n" .. currentText
			hs.pasteboard.setContents(mergedText)
		end)
	else
		-- Normal Cmd+C
		hs.eventtap.keyStroke({ "cmd" }, "c")
	end

	lastCmdCTime = currentTime
end)

--return clipboard
