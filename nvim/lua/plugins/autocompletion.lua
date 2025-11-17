return {
	{
		"xzbdmw/colorful-menu.nvim",
		opts = true,
	},
	{
		"saghen/blink.cmp",
		-- optional: provides snippets for the snippet source
		dependencies = {
			"rafamadriz/friendly-snippets",
			"Kaiser-Yang/blink-cmp-git",
			"L3MON4D3/LuaSnip",
		},

		version = "*",
		-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
		-- build = "cargo build --release",
		-- If you use nix, you can build from source using latest nightly rust with:
		-- build = 'nix run .#build-plugin',

		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = { preset = "default" },

			appearance = {
				nerd_font_variant = "mono",
			},

			completion = {
				menu = {
					border = "rounded",
					winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
					draw = {
						gap = 1,
						columns = { { "kind_icon" }, { "label", gap = 1 } },
						components = {
							label = {
								text = function(ctx)
									return require("colorful-menu").blink_components_text(ctx)
								end,
								highlight = function(ctx)
									return require("colorful-menu").blink_components_highlight(ctx)
								end,
							},
						},
					},
				},
				documentation = {
					auto_show = true,
					window = {
						border = "rounded",
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
					},
				},
			},
			signature = {
				enabled = false,
				window = {
					border = "rounded",
				},
			},
			snippets = {
				preset = "default",
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "git" },
				per_filetype = {
					codecompanion = { "codecompanion" },
				},
				providers = {
					git = {
						module = "blink-cmp-git",
						name = "Git",
						enabled = function()
							return vim.tbl_contains({ "octo", "gitcommit", "markdown" }, vim.bo.filetype)
						end,
						opts = {},
					},
				},
			},
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
}
