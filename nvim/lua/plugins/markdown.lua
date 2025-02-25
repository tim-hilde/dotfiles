return {
	{
		"OXY2DEV/markview.nvim",
		lazy = true, -- Recommended
		ft = { "markdown", "codecompanion" }, -- If you decide to lazy-load anyway

		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			markdown = {
				list_items = {
					shift_width = 2,
				},
			},
		},
	},
	-- {
	-- 	"preservim/vim-markdown",
	-- 	ft = { "markdown", "codecompanion" },
	-- 	init = function()
	-- 		vim.cmd [[set foldlevelstart=6]]
	-- 		vim.cmd [[set conceallevel=2]]
	-- 		vim.cmd [[let g:vim_markdown_auto_insert_bullets = 0]]
	-- 	end,
	-- 	dependencies = {
	-- 		"godlygeek/tabular",
	-- 	},
	-- },
}
