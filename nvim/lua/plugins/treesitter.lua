return {
	{
		"nvim-treesitter/nvim-treesitter",
		dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
		build = ":TSUpdate",
		main = "nvim-treesitter.configs", -- Sets main module to use for opts
		-- [[ Configure Treesitter ]] See `:help nvim-treesitter`
		opts = {
			ensure_installed = {
				"bash",
				"c",
				"diff",
				"html",
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"query",
				"vim",
				"vimdoc",
				"python",
				"yaml",
			},
			-- Autoinstall languages that are not installed
			auto_install = true,
			highlight = {
				enable = true,
				-- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
				--  If you are experiencing weird indenting issues, add the language to
				--  the list of additional_vim_regex_highlighting and disabled languages for indent.
				additional_vim_regex_highlighting = { "ruby" },
			},
			indent = { enable = true, disable = { "ruby" } },
			textobjects = {
				select = {
					enable = true,

					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = true,

					keymaps = {
						-- outer: outer part
						-- inner: inner part
						["af"] = { query = "@function.outer", desc = "Outer function" },
						["if"] = { query = "@function.inner", desc = "Inner function" },

						["aa"] = { query = "@parameter.outer", desc = "Outer parameter" },
						["ia"] = { query = "@parameter.inner", desc = "Inner parameter" },

						["ac"] = { query = "@class.outer", desc = "Outer class" },
						["ic"] = { query = "@class.inner", desc = "Inner class" },

						-- ["al"] = { query = "@loop.outer", desc = "Outer loop" },
						-- ["il"] = { query = "@loop.inner", desc = "Inner loop" },

						["ar"] = { query = "@assignment.rhs", desc = "Right side assignment" },
					},
					-- If you set this to `true` (default is `false`) then any textobject is
					-- extended to include preceding or succeeding whitespace. Succeeding
					-- whitespace has priority in order to act similarly to eg the built-in
					-- `ap`.
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * selection_mode: eg 'v'
					-- and should return true or false
					include_surrounding_whitespace = false,
				},
				move = {
					enable = true,
					set_jumps = true, -- whether to set jumps in the jumplist
					goto_next_start = {
						["]f"] = { query = "@function.outer", desc = "Next function start" },
						["]c"] = { query = "@class.outer", desc = "Next class start" },
						--
						["]a"] = { query = "@parameter.outer", desc = "Next parameter start" },
						["]r"] = { query = "@assignment.rhs", desc = "Next right side assignment start" },

						-- You can use regex matching (i.e. lua pattern) and/or pass a list in a "query" key to group multiple queires.
						-- ["]l"] = { query = "@loop.*", desc = "Next loop start" }, -- that is, ["]o"] = { query = { "@loop.inner", "@loop.outer" } }

						-- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
						-- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
						["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
					},
					goto_next_end = {
						["]F"] = { query = "@function.outer", desc = "Next function end" },
						["]C"] = { query = "@class.outer", desc = "Next class end" },
						["]A"] = { query = "@parameter.outer", desc = "Next parameter end" },
					},
					goto_previous_start = {
						["[f"] = { query = "@function.outer", desc = "Previous function start" },
						["[c"] = { query = "@class.outer", desc = "Previous class start" },
						["[a"] = { query = "@parameter.outer", desc = "Previous parameter start" },
					},
					goto_previous_end = {
						["[F"] = { query = "@function.outer", desc = "Previous function end" },
						["[C"] = { query = "@class.outer", desc = "Previous class end" },
						["[A"] = { query = "@parameter.outer", desc = "Previous parameter end" },
					},
					-- Below will go to either the start or the end, whichever is closer.
					-- Use if you want more granular movements
					-- Make it even more gradual by adding multiple queries and regex.
					goto_next = {},
					goto_previous = {},
				},
			},
		},
		-- There are additional nvim-treesitter modules that you can use to interact
		-- with nvim-treesitter. You should go explore a few and see what interests you:
		--
		--    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
		--    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
		--    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		opts = {
			multiline_threshold = 1,
		},
	},
	{
		-- Colored paranthesis
		"HiPhish/rainbow-delimiters.nvim",
	},
	{
		"fladson/vim-kitty",
		ft = "kitty",
	},
}
