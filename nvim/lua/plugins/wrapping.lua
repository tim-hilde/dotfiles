return {
	"andrewferrier/wrapping.nvim",
	config = function()
		require("wrapping").setup {
			softener = { markdown = true },
		}
	end,
}
