return {
	"catppuccin/nvim",
	priority = 1000,
	config = function()
		require("catppuccin").setup {
			auto_integrations = true,
			integrations = {
				markview = true,
				noice = true,
				notify = true,
			},
			transparent_background = true, -- disables setting the background color.
			float = {
				transparent = true, -- enable transparent floating windows
				solid = false, -- use solid styling for floating windows, see |winborder|
			},
			show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
			term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
			dim_inactive = {
				enabled = false, -- dims the background color of inactive window
				shade = "dark",
				percentage = 0.15, -- percentage of the shade to apply to the inactive window
			},
		}
		vim.cmd.colorscheme "catppuccin-mocha"
	end,
}
