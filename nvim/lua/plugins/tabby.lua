return {
	"nanozuki/tabby.nvim",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("tabby").setup {
			preset = "tab_only",
			lualine_theme = "catppuccin",
			nerdfont = true,
		}
	end,
}
