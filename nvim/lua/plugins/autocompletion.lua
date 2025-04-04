return {
	"saghen/blink.cmp",
	-- optional: provides snippets for the snippet source
	dependencies = {
		"rafamadriz/friendly-snippets",
		"Kaiser-Yang/blink-cmp-git",
		"L3MON4D3/LuaSnip",
		"catpucchin/nvim",
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
			use_nvim_cmp_as_default = false,
		},

		completion = {
			menu = {
				-- border = "rounded",
				draw = {
					columns = {
						{
							"label",
							"label_description",
							gap = 1,
						},
						{
							"kind",
							gap = 1,
							"kind_icon",
						},
					},
				},
			},
			documentation = {
				auto_show = true,
				window = {
					-- border = "rounded",
				},
			},
		},
		signature = {
			window = {
				-- border = "rounded",
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
					opts = {
						-- options for the blink-cmp-git
					},
				},
			},
		},

		-- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
		-- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
		-- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
		--
		-- See the fuzzy documentation for more information
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
