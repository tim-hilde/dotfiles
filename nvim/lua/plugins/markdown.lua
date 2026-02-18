return {
	{
		"OXY2DEV/markview.nvim",
		lazy = false,

		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		init = function()
			vim.cmd [[set conceallevel=2]]
			require("markview").setup {
				preview = {
					filetypes = { "markdown", "codecompanion" },
					ignore_buftypes = {},
				},

				markdown = {
					list_items = {
						shift_width = 2,
					},
				},
				experimental = {
					check_rtp_message = false,
				},
			}
		end,
	},
	{
		"3rd/diagram.nvim",
		dependencies = {
			{ "3rd/image.nvim", opts = {} }, -- you'd probably want to configure image.nvim manually instead of doing this
		},
		opts = {},
	},
}
