-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- TIP: Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Leap
vim.keymap.set("n", "<leader>j", "<Plug>(leap)", { desc = "Leap" })

if vim.g.vscode then
	vim.keymap.set("n", "gr", ':call VSCodeNotify("editor.action.rename")<cr>')
else
	vim.keymap.set({ "n", "v" }, "<leader>f", function()
		require("conform").format { async = true, lsp_format = "fallback" }
	end, { desc = "[F]ormat buffer" })

	local wk = require "which-key"
	-- Diagnostic keymaps
	vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

	-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
	-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
	-- is not what someone will guess without a bit more experience.
	--
	-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
	-- or just use <C-\><C-n> to exit terminal mode
	vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

	-- Keybinds to make split navigation easier.
	--  Use CTRL+<hjkl> to switch between windows
	--
	--  See `:help wincmd` for a list of all window commands
	vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
	vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
	vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
	vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

	-- Toggle Neotree
	vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left toggle<CR>")

	-- Toogle bufferline
	vim.keymap.set("n", "<leader>tb", function()
		local showtabline = vim.o.showtabline
		if showtabline == 2 then
			vim.cmd "set showtabline=0"
		else
			vim.cmd "set showtabline=2"
		end
	end, { desc = "[T]oggle [b]ufferline" })

	-- Cicle through buffer
	wk.add {
		{ "<leader>1", '<cmd>lua require("bufferline").go_to(1, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>2", '<cmd>lua require("bufferline").go_to(2, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>3", '<cmd>lua require("bufferline").go_to(3, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>4", '<cmd>lua require("bufferline").go_to(4, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>5", '<cmd>lua require("bufferline").go_to(5, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>6", '<cmd>lua require("bufferline").go_to(6, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>7", '<cmd>lua require("bufferline").go_to(7, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>8", '<cmd>lua require("bufferline").go_to(8, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>9", '<cmd>lua require("bufferline").go_to(9, true)<CR>', noremap = true, silent = true, hidden = true },
		{ "<leader>$", '<cmd>lua require("bufferline").go_to(-1, true)<CR>', noremap = true, silent = true, hidden = true },
	}

	-- Search TODOs
	wk.add {
		{ "<leader>st", "<cmd>TodoTelescope<CR>", desc = "[S]earch [T]ODOS" },
	}

	-- Toggle terminal
	wk.add {
		{ "<leader>tt", "<cmd>ToggleTerm<CR>", desc = "[T]oggle [t]erminal" },
	}

	local Terminal = require("toggleterm.terminal").Terminal
	local lazygit = Terminal:new {
		cmd = "lazygit --use-config-file=$HOME/dotfiles/lazygit/config.yml",
		dir = "git_dir",
		direction = "float",
		float_opts = {
			border = "double",
		},
		hidden = true,
	}

	function _lazygit_toggle()
		lazygit:toggle()
	end

	vim.api.nvim_set_keymap("n", "<leader>tg", "<cmd>lua _lazygit_toggle()<CR>", { noremap = true, silent = true, desc = "[T]oggle lazy[g]it" })

	-- YankBank
	vim.keymap.set("n", "<leader>y", "<cmd>YankBank<CR>", { noremap = true, desc = "[Y]ankBank" })

	-- LSP Signature
	vim.keymap.set({ "n" }, "<leader>k", function()
		require("lsp_signature").toggle_float_win()
	end, { silent = true, noremap = true, desc = "[t]oggle signature" })

	-- BUILD SYSTEM
	vim.keymap.set("n", "<leader>cb", function()
		vim.cmd [[update!]]
		local filename = vim.fn.expand "%:t"
		local parentFolder = vim.fn.expand "%:p:h"
		local ft = vim.bo.filetype

		if ft == "yaml" and parentFolder:find "dotfiles/karabiner" then
			os.execute [[osascript -l JavaScript "$HOME/dotfiles/karabiner/build-karabiner-config.js"]]
		end
	end, { desc = "[c]ode [b]uild" })

	-- CodeCompanion
	vim.api.nvim_set_keymap("n", "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
	vim.api.nvim_set_keymap("v", "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
	vim.api.nvim_set_keymap("n", "<LocalLeader>tc", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true, desc = "[T]oggle [C]hat" })
	vim.api.nvim_set_keymap("v", "<LocalLeader>tc", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true, desc = "[T]oggle [C]hat" })
	vim.api.nvim_set_keymap("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

	-- Expand 'cc' into 'CodeCompanion' in the command line
	vim.cmd [[cab cc CodeCompanion]]
end
