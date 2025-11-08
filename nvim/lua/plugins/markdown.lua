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
}
