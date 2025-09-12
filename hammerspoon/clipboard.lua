-- Hammerspoon Script: Clipboard Merge (Alfred-Style)
-- Funktionalität: Cmd+C doppelt drücken um Text an vorherigen Clipboard-Inhalt anzuhängen

local clipboardHistory = {}
local maxHistorySize = 50
local lastCopyTime = 0
local doubleTapThreshold = 0.5 -- Sekunden zwischen den Cmd+C Drücken
local isWaitingForSecondTap = false

-- Funktion zum Hinzufügen von Text zur Clipboard-Historie
local function addToHistory(text)
	if text and text ~= "" and text ~= clipboardHistory[1] then
		table.insert(clipboardHistory, 1, text)
		if #clipboardHistory > maxHistorySize then
			table.remove(clipboardHistory, maxHistorySize + 1)
		end
	end
end

-- Funktion zum Mergen von Clipboard-Inhalten
local function mergeClipboardContent()
	local currentClipboard = hs.pasteboard.getContents()

	if currentClipboard and #clipboardHistory >= 1 then
		local previousClipboard = clipboardHistory[1]

		-- Merge: Vorheriger Text + Neue Zeile + Aktueller Text
		local mergedText = previousClipboard .. "\n" .. currentClipboard

		-- Zurück in die Zwischenablage
		hs.pasteboard.setContents(mergedText)

		-- Historie aktualisieren
		addToHistory(mergedText)

		-- Bestätigung anzeigen
		hs.alert.show("📋 Clipboard merged", 1)

		print("Merged clipboard content:")
		print("Previous: " .. previousClipboard)
		print("Current: " .. currentClipboard)
		print("Result: " .. mergedText)
	else
		hs.alert.show("⚠️ No previous clipboard content to merge", 1.5)
	end
end

-- Timer für Double-Tap Detection
local doubleTapTimer = nil

-- Event-Handler für Cmd+C
local function handleCmdC()
	local currentTime = hs.timer.secondsSinceEpoch()
	local timeSinceLastCopy = currentTime - lastCopyTime

	if timeSinceLastCopy <= doubleTapThreshold and isWaitingForSecondTap then
		-- Zweiter Tap innerhalb der Threshold-Zeit
		isWaitingForSecondTap = false
		if doubleTapTimer then
			doubleTapTimer:stop()
			doubleTapTimer = nil
		end

		-- Warten bis der Copy-Vorgang abgeschlossen ist
		hs.timer.doAfter(0.1, function()
			mergeClipboardContent()
		end)
	else
		-- Erster Tap oder zu spät für Double-Tap
		isWaitingForSecondTap = true
		lastCopyTime = currentTime

		-- Timer für Reset nach Threshold
		if doubleTapTimer then
			doubleTapTimer:stop()
		end

		doubleTapTimer = hs.timer.doAfter(doubleTapThreshold, function()
			isWaitingForSecondTap = false
			doubleTapTimer = nil
		end)

		-- Normaler Copy-Vorgang - nach kurzer Verzögerung zur Historie hinzufügen
		hs.timer.doAfter(0.1, function()
			local clipboardContent = hs.pasteboard.getContents()
			if clipboardContent then
				addToHistory(clipboardContent)
			end
		end)
	end
end

-- Event-Watcher für Tastenkombinationen
local cmdCWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	-- Prüfen ob GENAU Cmd+C gedrückt wurde (C = keyCode 8, nur cmd flag)
	if keyCode == 8 and flags.cmd and not flags.shift and not flags.alt and not flags.ctrl then
		handleCmdC()
	end

	-- IMMER das Event weiterleiten, niemals blockieren
	return false
end)

-- Script initialisieren und starten
local function initClipboardMerge()
	-- Aktuelle Zwischenablage als vorherigen Inhalt setzen
	local currentContent = hs.pasteboard.getContents()
	if currentContent then
		previousClipboard = currentContent
	end

	cmdCWatcher:start()
	hs.alert.show("✅ Clipboard Merge activated\nDouble-tap Cmd+C to merge")
	print("Clipboard Merge Script started")
end

-- Auto-Start beim Laden des Scripts
initClipboardMerge()

-- Reload-Notification
hs.alert.show("🔄 Hammerspoon Clipboard Merge loaded")
return {}
