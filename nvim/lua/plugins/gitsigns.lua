return {
	-- Adds git related signs to the gutter, as well as utilities for managing changes
	-- See `:help gitsigns` to understand what the configuration keys do
	"lewis6991/gitsigns.nvim",
	commit = "25050e4ed39e628282831d4cbecb1850454ce915",
	opts = {
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
	},
}
