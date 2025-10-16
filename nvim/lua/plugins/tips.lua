return {
	"saxon1964/neovim-tips",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	opts = {},
	init = function()
		-- OPTIONAL: Change to your liking or drop completely
		-- The plugin does not provide default key mappings, only commands
		local map = vim.keymap.set
		map("n", "<leader>nto", ":NeovimTips<CR>", { desc = "Neovim tips", noremap = true, silent = true })
		map("n", "<leader>nth", ":help neovim-tips<CR>", { desc = "Neovim tips help", noremap = true, silent = true })
		map("n", "<leader>ntr", ":NeovimTipsRandom<CR>", { desc = "Show random tip", noremap = true, silent = true })
	end,
}
