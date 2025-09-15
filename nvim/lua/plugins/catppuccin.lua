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
			transparent_background = false, -- disables setting the background color.
			float = {
				transparent = false, -- enable transparent floating windows
			},
		}
		vim.cmd.colorscheme "catppuccin-mocha"
	end,
}
