local config = require("config")
local utils = require("utils")

-- Initialize reload configuration
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Load modules
require("dotfiles")
require("clipboard")
require("agent-fleet")

utils.notify("Hammerspoon configuration loaded")

-- Force a GC pass right after load so that any timer/watcher whose reference
-- was accidentally dropped breaks immediately (loud, at reload time) instead of
-- silently much later. See Hammerspoon issue #3300.
_gcTimer = hs.timer.doAfter(0, function()
	_gcTimer = nil
	collectgarbage()
	collectgarbage()
end)
