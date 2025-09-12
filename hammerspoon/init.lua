local config = require("config")
local utils = require("utils")

-- Load modules
require("dotfiles")
require("clipboard")

-- Initialize reload configuration
hs.loadSpoon("ReloadConfiguration")
hs.loadSpoon("Pasteboard")
spoon.ReloadConfiguration:start()

utils.notify("Hammerspoon configuration loaded")
