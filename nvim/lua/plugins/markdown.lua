return {
	"preservim/vim-markdown",
	ft = { "markdown", "codecompanion" },
	init = function()
		vim.cmd [[set foldlevelstart=6]]
		vim.cmd [[set conceallevel=2]]
		vim.cmd [[let g:vim_markdown_auto_insert_bullets = 0]]
	end,
	dependencies = {
		"godlygeek/tabular",
	},
}
