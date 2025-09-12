local config = require("config")
local utils = require("utils")

-- Initialize reload configuration
hs.loadSpoon("ReloadConfiguration")
hs.loadSpoon("Pasteboard")
spoon.ReloadConfiguration:start()

-- Load modules
require("dotfiles")
require("clipboard")

utils.notify("Hammerspoon configuration loaded")
