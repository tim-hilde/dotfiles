return {
	"preservim/vim-markdown",
	ft = "markdown",
	init = function()
		vim.cmd [[set foldlevelstart=6]]
		vim.cmd [[set conceallevel=2]]
	end,
	dependencies = {
		"godlygeek/tabular",
	},
}
