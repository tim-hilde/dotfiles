-- Nice and simple folding:
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldtext = ""
vim.opt.foldcolumn = "0"
vim.opt.fillchars:append { fold = " " }

-- Default to treesitter folding
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- Prefer LSP folding if client supports it
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client:supports_method "textDocument/foldingRange" then
			local win = vim.api.nvim_get_current_win()
			vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
		end
	end,
})
return {
	{
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {
			keepFoldsAcrossSessions = false,
			pauseFoldsOnSearch = true,
			fodltext = {
				enabled = true,
				template = "   %s lines", -- `%s` gets the number of folded lines
			},
			foldKeymaps = {
				setup = true, -- modifies `h` and `l`
				hOnlyOpensOnFirstColumn = true,
			},
		},
	},
}
