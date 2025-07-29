return {
	"catppuccin/nvim",
	priority = 1000,
	config = function()
		vim.cmd.colorscheme "catppuccin-mocha"
		require("catppuccin").setup {
			auto_integrations = true,
			integrations = {
				markview = true,
				noice = true,
				notify = true,
			},
		}
	end,
}
