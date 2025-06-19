return {
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		opts = {
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
				},
			},
			presets = {
				bottom_search = false, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = true, -- add a border to hover docs and signature help
			},
			views = {
				notify = {
					replace = true,
				},
			},
			routes = {
				{ filter = { event = "msg_show", find = "written" } },
				{ filter = { event = "msg_show", find = "yanked" } },
				{ filter = { event = "msg_show", find = "%d+L, %d+B" } },
				{ filter = { event = "msg_show", find = "; after #%d+" } },
				{ filter = { event = "msg_show", find = "; before #%d+" } },
				{ filter = { event = "msg_show", find = "%d fewer lines" } },
				{ filter = { event = "msg_show", find = "%d more lines" } },
				{ filter = { event = "msg_show", find = "<ed" } },
				{ filter = { event = "msg_show", find = ">ed" } },
			},
		},
		dependencies = {
			"MunifTanjim/nui.nvim",
			-- OPTIONAL:
			--   `nvim-notify` is only needed, if you want to use the notification view.
			--   If not available, we use `mini` as the fallback
			{ "rcarriga/nvim-notify", opts = {
				timeout = 5000,
				stages = "static",
				render = "wrapped-compact",
			} },
		},
	},
}
