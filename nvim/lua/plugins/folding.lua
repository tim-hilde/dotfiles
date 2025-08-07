vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

return {
	{
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {
			pauseFoldsOnSearch = true,
			foldtext = {
				enabled = true,
				template = "   %s lines", -- `%s` gets the number of folded lines
			},
			foldKeymaps = {
				setup = true, -- modifies `h` and `l`
				hOnlyOpensOnFirstColumn = true,
			},
			autoFold = {
				enabled = false,
				kinds = { "comment", "imports" }, ---@type lsp.FoldingRangeKind[]
			},
		},
	},
}
