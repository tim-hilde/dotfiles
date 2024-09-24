return {
	"ray-x/lsp_signature.nvim",
	event = "LspAttach",
	config = function()
		require("lsp_signature").on_attach {
			bind = true,
			handler_opts = {
				border = "rounded",
			},
			hint_enable = true,
			floating_window = false,
			hint_prefix = {
				above = "↙ ", -- when the hint is on the line above the current line
			},
		}
	end,
}
