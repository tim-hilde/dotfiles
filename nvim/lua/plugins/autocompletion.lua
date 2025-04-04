return {
	-- "hrsh7th/nvim-cmp",
	-- event = "InsertEnter",
	-- dependencies = {
	-- 	-- Snippet Engine & its associated nvim-cmp source
	-- 	{
	-- 		"L3MON4D3/LuaSnip",
	-- 		build = (function()
	-- 			-- Build Step is needed for regex support in snippets.
	-- 			-- This step is not supported in many windows environments.
	-- 			-- Remove the below condition to re-enable on windows.
	-- 			if vim.fn.has "win32" == 1 or vim.fn.executable "make" == 0 then
	-- 				return
	-- 			end
	-- 			return "make install_jsregexp"
	-- 		end)(),
	-- 		dependencies = {
	-- 			-- `friendly-snippets` contains a variety of premade snippets.
	-- 			--    See the README about individual language/framework/plugin snippets:
	-- 			--    https://github.com/rafamadriz/friendly-snippets
	-- 			{
	-- 				"rafamadriz/friendly-snippets",
	-- 				config = function()
	-- 					require("luasnip.loaders.from_vscode").lazy_load()
	-- 				end,
	-- 			},
	-- 		},
	-- 	},
	-- 	"saadparwaiz1/cmp_luasnip",
	-- 	"onsails/lspkind.nvim",
	--
	-- 	-- Adds other completion capabilities.
	-- 	--  nvim-cmp does not ship with all sources by default. They are split
	-- 	--  into multiple repos for maintenance purposes.
	-- 	"hrsh7th/cmp-nvim-lsp",
	-- 	"hrsh7th/cmp-path",
	-- 	-- "hrsh7th/cmp-cmdline"
	-- },
	-- config = function()
	-- 	-- See `:help cmp`
	-- 	local cmp = require "cmp"
	-- 	local lspkind = require "lspkind"
	-- 	local luasnip = require "luasnip"
	-- 	luasnip.config.setup {}
	--
	-- 	cmp.setup {
	-- 		-- view = {
	-- 		-- 	docs = {
	-- 		-- 		auto_open = false,
	-- 		-- 	},
	-- 		-- },
	-- 		-- performance = {
	-- 		-- 	max_view_entries = 20,
	-- 		-- },
	-- 		formatting = {
	-- 			format = lspkind.cmp_format {
	-- 				mode = "symbol_text",
	-- 			},
	-- 		},
	-- 		snippet = {
	-- 			expand = function(args)
	-- 				luasnip.lsp_expand(args.body)
	-- 			end,
	-- 		},
	--
	-- 		window = {
	-- 			completion = cmp.config.window.bordered(),
	-- 			documentation = cmp.config.window.bordered(),
	-- 		},
	-- 		completion = { completeopt = "menu,menuone,noinsert" },
	--
	-- 		-- For an understanding of why these mappings were
	-- 		-- chosen, you will need to read `:help ins-completion`
	-- 		--
	-- 		-- No, but seriously. Please read `:help ins-completion`, it is really good!
	-- 		mapping = cmp.mapping.preset.insert {
	-- 			-- Select the [n]ext item
	-- 			["<C-n>"] = cmp.mapping.select_next_item(),
	-- 			-- Select the [p]revious item
	-- 			["<C-p>"] = cmp.mapping.select_prev_item(),
	--
	-- 			-- Scroll the documentation window [b]ack / [f]orward
	-- 			["<C-b>"] = cmp.mapping.scroll_docs(-4),
	-- 			["<C-f>"] = cmp.mapping.scroll_docs(4),
	--
	-- 			-- Accept ([y]es) the completion.
	-- 			--  This will auto-import if your LSP supports it.
	-- 			--  This will expand snippets if the LSP sent a snippet.
	-- 			["<C-z>"] = cmp.mapping.confirm { select = true },
	--
	-- 			-- If you prefer more traditional completion keymaps,
	-- 			-- you can uncomment the following lines
	-- 			-- ["<CR>"] = cmp.mapping.confirm { select = true },
	-- 			-- ["<Tab>"] = function(fallback)
	-- 			-- 	if cmp.visible() then
	-- 			-- 		cmp.select_next_item()
	-- 			-- 	elseif luasnip.expand_or_jumpable() then
	-- 			-- 		vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, false), "")
	-- 			-- 	else
	-- 			-- 		fallback()
	-- 			-- 	end
	-- 			-- end,
	-- 			-- ["<S-Tab>"] = function(fallback)
	-- 			-- 	if cmp.visible() then
	-- 			-- 		cmp.select_prev_item()
	-- 			-- 	elseif luasnip.jumpable(-1) then
	-- 			-- 		vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, false), "")
	-- 			-- 	else
	-- 			-- 		fallback()
	-- 			-- 	end
	-- 			-- end,
	--
	-- 			-- Manually trigger a completion from nvim-cmp.
	-- 			--  Generally you don't need this, because nvim-cmp will display
	-- 			--  completions whenever it has completion options available.
	-- 			["<C-Space>"] = cmp.mapping.complete {},
	--
	-- 			-- Manually trigger documentation
	-- 			["<C-g>"] = function()
	-- 				if cmp.visible_docs() then
	-- 					cmp.close_docs()
	-- 				else
	-- 					cmp.open_docs()
	-- 				end
	-- 			end,
	-- 			-- Think of <c-l> as moving to the right of your snippet expansion.
	-- 			--  So if you have a snippet that's like:
	-- 			--  function $name($args)
	-- 			--    $body
	-- 			--  end
	-- 			--
	-- 			-- <c-l> will move you to the right of each of the expansion locations.
	-- 			-- <c-h> is similar, except moving you backwards.
	-- 			["<C-l>"] = cmp.mapping(function()
	-- 				if luasnip.expand_or_locally_jumpable() then
	-- 					luasnip.expand_or_jump()
	-- 				end
	-- 			end, { "i", "s" }),
	-- 			["<C-h>"] = cmp.mapping(function()
	-- 				if luasnip.locally_jumpable(-1) then
	-- 					luasnip.jump(-1)
	-- 				end
	-- 			end, { "i", "s" }),
	--
	-- 			-- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
	-- 			--    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
	-- 		},
	-- 		sources = {
	-- 			-- {
	-- 			-- 	name = "lazydev",
	-- 			-- 	-- set group index to 0 to skip loading LuaLS completions as lazydev recommends it
	-- 			-- 	group_index = 0,
	-- 			-- },
	-- 			{ name = "nvim_lsp" },
	-- 			{ name = "luasnip" },
	-- 			{ name = "path" },
	-- 			-- { name = "cmdline"}
	-- 		},
	-- 	}
	-- end,
	"saghen/blink.cmp",
	-- optional: provides snippets for the snippet source
	dependencies = { "rafamadriz/friendly-snippets" },

	-- use a release tag to download pre-built binaries
	version = "*",
	-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	-- build = "cargo build --release",
	-- If you use nix, you can build from source using latest nightly rust with:
	-- build = 'nix run .#build-plugin',

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		-- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
		-- 'super-tab' for mappings similar to vscode (tab to accept)
		-- 'enter' for enter to accept
		-- 'none' for no mappings
		--
		-- All presets have the following mappings:
		-- C-space: Open menu or open docs if already open
		-- C-n/C-p or Up/Down: Select next/previous item
		-- C-e: Hide menu
		-- C-k: Toggle signature help (if signature.enabled = true)
		--
		-- See :h blink-cmp-config-keymap for defining your own keymap
		keymap = { preset = "default" },

		appearance = {
			-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			-- Adjusts spacing to ensure icons are aligned
			nerd_font_variant = "mono",
		},

		-- (Default) Only show the documentation popup when manually triggered
		completion = { documentation = { auto_show = false } },

		-- Default list of enabled providers defined so that you can extend it
		-- elsewhere in your config, without redefining it, due to `opts_extend`
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
			per_filetype = {
				codecompanion = { "codecompanion" },
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
