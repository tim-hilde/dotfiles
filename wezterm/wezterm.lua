local wt = require 'wezterm'

local act = wt.action
local actFun = wt.action_callback

local config = wt.config_builder()


-- Auto switch dark mode
function get_appearance()
    if wt.gui then
      return wt.gui.get_appearance()
    end
    return 'Dark'
  end

  function scheme_for_appearance(appearance)
    if appearance:find 'Dark' then
      colors, metadata = wt.color.load_terminal_sexy_scheme("~/dotfiles/wezterm/colors/iterm dark.json")
      return colors
    else
      colors, metadata = wt.color.load_terminal_sexy_scheme("/Users/tim/dotfiles/wezterm/colors/iterm light.json")
      return colors
    end
  end

colors, metadata = wt.color.load_terminal_sexy_scheme("/Users/tim/dotfiles/wezterm/colors/iterm light.json")

  return {
    window_close_confirmation = "NeverPrompt",
	quit_when_all_windows_are_closed = true,

    -- FONT
    font = wt.font("JetBrainsMono Nerd Font Mono", {weight = "DemiBold"}),
    font_size = 12,
    bold_brightens_ansi_colors = "BrightAndBold",

    -- APPERANCE
    -- remove titlebar, but keep macOS traffic lights.
    window_decorations = "INTEGRATED_BUTTONS|RESIZE",
	native_macos_fullscreen_mode = false,



    -- Color theme depeinding on dark/light mode
    colors = scheme_for_appearance(get_appearance()),


    -- KEYBINDINGS
    keys = {
        { -- cmd+, -> open the config file
		key = ",",
		mods = "CMD",
		action = actFun(function() wt.open_with(wt.config_file) end),
        }
    },

    -- disable copy selection
    mouse_bindings = {
        {
          event = { Up = { streak = 1, button = "Left" } },
          mods = "NONE",
          action = wt.action.Nop,
        },
      },

	disable_default_key_bindings = false,
	send_composed_key_when_left_alt_is_pressed = true, -- fix @{}~ etc. on German keyboard
	send_composed_key_when_right_alt_is_pressed = true,
	use_dead_keys = true, -- do not expect another key after `^~`
}
