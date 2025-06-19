return {
	"catppuccin/nvim",
	priority = 1000,
	config = function()
		vim.cmd.colorscheme "catppuccin-mocha"
		require("catppuccin").setup {
			integrations = {
				markview = true,
				noice = true,
				notify = true,
			},
		}
	end,
}
