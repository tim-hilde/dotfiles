return {
	"ray-x/lsp_signature.nvim",
	event = "InsertEnter",
	opts = function()
		require("lsp_signature").on_attach {
			bind = true,
			handler_opts = {
				border = "rounded",
			},
			hint_enable = true,
			floating_window = false,
			toggle_key_flip_floatwin_setting = true,
			hint_prefix = {
				above = "↙ ", -- when the hint is on the line above the current line
				current = "← ", -- when the hint is on the same line
				below = "↖ ", -- when the hint is on the line below the current line
			},
		}
	end,
}
