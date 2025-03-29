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

-- HJKL as amplified versions of hjkl
vim.keymap.set("n", "J", "6j")
vim.keymap.set("n", "K", "6k")
vim.keymap.set("n", "H", "^")
vim.keymap.set("n", "L", "$")

vim.keymap.set("n", "<leader>M", "J", { desc = "[M]erge lines" }) -- mnemonic: [M]erge
vim.keymap.set("n", "<leader>J", ":TSJToggle<CR>", { desc = "[J]oin lines" })

local wk = require "which-key"

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format { async = true, lsp_format = "fallback" }
end, { desc = "[F]ormat buffer" })

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
vim.keymap.set("n", "<leader>l", function()
	require("quicker").toggle { loclist = false }
end, { desc = "Open qlist" })

-- Hover Documentation
vim.keymap.set(
	"n",
	"<leader>h",
	vim.lsp.buf.hover,
	-- function() require("pretty_hover").hover() end,
	{ desc = "[H]over documentation" }
)

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

vim.keymap.set("n", "<C-D>", "<C-D>zz", { noremap = true })
vim.keymap.set("x", "<C-U>", "<C-U>zz", { noremap = true })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<CMD>TmuxNavigateLeft<CR>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-j>", "<CMD>TmuxNavigateDown<CR>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<CMD>TmuxNavigateUp<CR>", { desc = "Move focus to the upper window" })
vim.keymap.set("n", "<C-l>", "<CMD>TmuxNavigateRight<CR>", { desc = "Move focus to the right window" })

-- Toggle Neotree
vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left toggle<CR>")

-- Toogle Oil
vim.keymap.set("n", "<leader>to", "<CMD>Oil --float<CR>", { desc = "[T]oggle [O]il" })

-- Tabby

vim.keymap.set("n", "<C-w>ta", ":$tabnew<CR>", { noremap = true, desc = "[A]dd" })
vim.keymap.set("n", "<C-w>tc", ":tabclose<CR>", { noremap = true, desc = "[C]lose" })
vim.keymap.set("n", "<C-w>to", ":tabonly<CR>", { noremap = true, desc = "[O]nly" })
-- move current tab to previous position
vim.keymap.set("n", "<C-w>tmp", ":-tabmove<CR>", { noremap = true, desc = "[P]revious" })
-- move current tab to next position
vim.keymap.set("n", "<C-w>tmn", ":+tabmove<CR>", { noremap = true, desc = "[N]ext" })
-- Tabby rename_tab <tabname>
vim.keymap.set("n", "<C-w>tr", function()
	local name = vim.fn.input "New name: "
	require("tabby").tab_rename(name)
end, { noremap = true, desc = "[R]ename" })
-- Tabby pick_window
vim.keymap.set("n", "<C-w>tp", ":Tabby pick_window<CR>", { noremap = true, desc = "[P]ick" })
-- Tabby jump_to_tab
vim.keymap.set("n", "<C-w>tj", ":Tabby jump_to_tab<CR>", { noremap = true, desc = "[J]ump" })

-- Zen mode
vim.keymap.set("n", "<leader>tz", function()
	require("zen-mode").toggle {
		window = {
			width = 0.85, -- width will be 85% of the editor width
		},
	}
end, { desc = "[T]oggle [Z]enMode" })
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

-- Clipboard
vim.keymap.set("n", "<leader>tn", "<cmd>Telescope neoclip<CR>", { noremap = true, desc = "[T]oggle [n]eoclip" })

-- LSP Signature
vim.keymap.set({ "n" }, "<leader>tl", function()
	require("lsp_signature").toggle_float_win()
end, { silent = true, noremap = true, desc = "[t]oggle signature" })

vim.keymap.set("", "<leader>tl", function()
	vim.diagnostic.config {
		virtual_lines = not vim.diagnostic.config().virtual_lines,
		virtual_text = not vim.diagnostic.config().virtual_text,
	}
end, { desc = "[T]oggle diagnostic [l]ines" })

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
vim.api.nvim_set_keymap("n", "<leader>cc", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<LocalLeader>tc", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true, desc = "[T]oggle [C]hat" })
vim.api.nvim_set_keymap("v", "<LocalLeader>tc", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true, desc = "[T]oggle [C]hat" })
vim.api.nvim_set_keymap("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

-- Expand 'cc' into 'CodeCompanion' in the command line
vim.cmd [[cab cc CodeCompanion]]

-- Autosession
vim.keymap.set("n", "<leader>war", "<cmd>SessionSearch<CR>", { desc = "[W]orkplace [A]utosession Sea[r]ch" })
vim.keymap.set("n", "<leader>was", "<cmd>SessionSave<CR>", { desc = "[W]orkplace [S]ession [S]ave" })
vim.keymap.set("n", "<leader>ta", "<cmd>SessionToggleAutoSave<CR>", { desc = "[T]oggle session [a]utosave" })

-- IRON REPL
vim.keymap.set("n", "<leader>ti", ":IronRepl<CR>", { desc = "[T]oggle [I]ronRepl" })

-- OPEN links
vim.keymap.set("n", "gx", "<esc>:URLOpenUnderCursor<cr>", { desc = "Go to link" })

-- Harpoon
vim.keymap.set("n", "<leader>px", function()
	require("harpoon"):list():add()
end, { desc = "Add to harpoon" })
vim.keymap.set("n", "<leader>pm", function()
	require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
end, { desc = "Harpoon marks" })

vim.keymap.set("n", "<leader>ph", function()
	require("harpoon"):list():select(1)
end, { desc = "Harpoon 1" })
vim.keymap.set("n", "<leader>pj", function()
	require("harpoon"):list():select(2)
end, { desc = "Harpoon 2" })
vim.keymap.set("n", "<leader>pk", function()
	require("harpoon"):list():select(3)
end, { desc = "Harpoon 3" })
vim.keymap.set("n", "<leader>pl", function()
	require("harpoon"):list():select(4)
end, { desc = "Harpoon 4" })

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<leader>pp", function()
	require("harpoon"):list():prev()
end, { desc = "Previous harpoon" })
vim.keymap.set("n", "<leader>pn", function()
	require("harpoon"):list():next()
end, { desc = "Next harpoon" })

-- Toggle call hierachy
vim.keymap.set("n", "<leader>ch", vim.lsp.buf.outgoing_calls, { desc = "[C]ode [H]ierarchy" })

vim.keymap.del("n", "grr")
vim.keymap.del("n", "grn")
vim.keymap.del("n", "gri")
vim.keymap.del("n", "gra")
