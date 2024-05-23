-- Pull in the wezterm API
local wt = require 'wezterm'

-- This will hold the configuration.
local config = wt.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:

-- color_scheme = 'AdventureTime'
return {
    -- Keybindings
	disable_default_key_bindings = false,
	send_composed_key_when_left_alt_is_pressed = true, -- fix @{}~ etc. on German keyboard
	send_composed_key_when_right_alt_is_pressed = true,
	use_dead_keys = true, -- do not expect another key after `^~`
}
