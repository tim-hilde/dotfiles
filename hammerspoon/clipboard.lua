local config = require("config")

local clipboard = {}

-- Double-tap Cmd+C state
local lastCmdCTime = 0

-- Double-tap Cmd+C to merge clipboard content

hs.hotkey.bind({ "cmd" }, "c", function()
	local currentTime = hs.timer.secondsSinceEpoch()
	local timeSinceLastC = currentTime - lastCmdCTime

	if timeSinceLastC <= config.doubleTapThreshold and timeSinceLastC > 0.05 then
		-- Doppel-C erkannt - Text zusammenführen
		-- Zuerst den ausgewählten Text kopieren
		hs.eventtap.keyStroke({ "cmd" }, "c", 0)

		hs.timer.doAfter(0.1, function()
			local clipboardHistory = hs.pasteboard.getHistory()
			if #clipboardHistory >= 2 then
				local currentText = clipboardHistory[1] or ""
				local previousText = clipboardHistory[2] or ""
				if currentText ~= "" and previousText ~= "" then
					local mergedText = previousText .. "\n" .. currentText
					hs.pasteboard.setContents(mergedText)
					hs.alert.show("Text merged!")
				end
			end
		end)

		lastCmdCTime = 0 -- Reset um weitere Doppel-Taps zu vermeiden
	else
		-- Normales Cmd+C - das Original-Event durchlassen
		lastCmdCTime = currentTime
		-- Das Event nicht abfangen, sondern weiterleiten
		return false -- Lässt das ursprüngliche Event durch
	end
end)

return clipboard
