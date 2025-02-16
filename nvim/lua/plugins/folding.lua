return {
	{
		"kevinhwang91/nvim-ufo",
		dependencies = {
			"kevinhwang91/promise-async",
		},
		event = "BufReadPost",
		init = function()
			vim.o.foldenable = true
			vim.o.foldcolumn = "auto:9"
			vim.o.foldlevel = 99
			vim.o.foldlevelstart = 99
			vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
			vim.keymap.set("n", "zR", require("ufo").openAllFolds)
			vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
		end,
		opts = {
			provider_selector = function()
				return { "treesitter", "indent" }
			end,
		},
	},
	{
		-- fold using h/l
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {},
	},
}
