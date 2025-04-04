return {
	"catppuccin/nvim",
	priority = 1000,
	config = function()
		vim.cmd.colorscheme "catppuccin-mocha"
		require("catppuccin").setup { integrations = { blink_cmp = false } }
	end,
}
