-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system { "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath }
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

local ui = {
	-- If you are using a Nerd Font: set icons to an empty table which will use the
	-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
	icons = vim.g.have_nerd_font and {} or {
		cmd = "⌘",
		config = "🛠",
		event = "📅",
		ft = "📂",
		init = "⚙",
		keys = "🗝",
		plugin = "🔌",
		runtime = "💻",
		require = "🌙",
		source = "📄",
		start = "🚀",
		task = "📌",
		lazy = "💤 ",
	},
}
if vim.g.vscode then
	require("lazy").setup({

		-- require "plugins.autocompletion",
		require "plugins.autoformat",
		require "plugins.autopairs",
		require "plugins.gitsigns",
		-- require "plugins.linting",
		-- require "plugins.lsp_signature",
		-- reqire "plugins.lsp",
		require "plugins.mini",
		require "plugins.puppeteer",
		require "plugins.vim-sleuth",
	}, ui)
else
	vim.g.puppeteer_disable_filetypes = { "", "neo-tree" }
	require("lazy").setup("plugins", {
		ui = ui,
		change_detection = {
			notify = false,
		},
	})
end
