return {
	"ray-x/lsp_signature.nvim",
	event = "InsertEnter",
	opts = {
		bind = true,
		handler_opts = {
			border = "rounded",
		},
		hint_enable = true,
		floating_window = false,
		hint_prefix = {
			above = "↙ ", -- when the hint is on the line above the current line
		},
	},
}
