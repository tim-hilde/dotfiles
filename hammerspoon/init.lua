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
