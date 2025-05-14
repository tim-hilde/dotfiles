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
			"mikavilpas/blink-ripgrep.nvim",
		},

		commit = "6dc82a0",
		-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
		build = "cargo build --release",
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
				window = {
					border = "rounded",
				},
			},
			snippets = {
				preset = "default",
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "git", "ripgrep" },
				per_filetype = {
					codecompanion = { "codecompanion" },
				},
				providers = {
					git = {
						module = "blink-cmp-git",
						name = "Git",
						opts = {},
					},
					ripgrep = {
						module = "blink-ripgrep",
						name = "Ripgrep",
					},
				},
			},
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
}
