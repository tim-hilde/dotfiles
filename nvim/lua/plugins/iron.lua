return {
	"Vigemus/iron.nvim",
	config = function()
		local view = require "iron.view"
		local python_format = require("iron.fts.common").bracketed_paste_python

		local opts = {
			config = {
				-- Whether a repl should be discarded or not
				scratch_repl = true,
				repl_definition = {
					python = {
						command = { "jupyter-console", "--ZMQTerminalInteractiveShell.image_handler=None" },
						format = require("iron.fts.common").bracketed_paste_python,
						block_dividers = { "# %%", "#%%" },
					}, -- python = {
					-- 	command = { "ipython", "--no-autoindent" },
					-- 	format = python_format,
					-- },
				},
				-- How the repl window will be displayed
				repl_open_cmd = view.split.vertical.botright(0.5),
			},
			keymaps = {
				send_motion = "<leader>ic",
				visual_send = "<leader>ic",
				send_file = "<leader>if",
				send_line = "<leader>il",
				send_paragraph = "<leader>ip",
				send_until_cursor = "<leader>iu",
				send_mark = "<leader>im",
				cr = "<leader>i<cr>",
				interrupt = "<leader>i<space>",
				exit = "<leader>iq",
				clear = "<space>cl",
			},
			ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
		}
		require("iron.core").setup(opts)
	end,
}
