return {
	{
		"michaelrommel/nvim-silicon",
		lazy = true,
		cmd = "Silicon",
		main = "nvim-silicon",
		opts = {
			font = "JetBrainsMono Nerd Font Mono=50",
			theme = "Catppuccin Mocha",
			background = nil,
			to_clipboard = true,
			line_pad = 16,
			-- here a function is used to return the actual source code line number
			line_offset = function(args)
				return args.line1
			end,
			num_separator = "  ",
			window_title = function()
				return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ":t")
			end,
		},
	},
}
