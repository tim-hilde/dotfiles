return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
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
			auto_install = true,
		},
		config = function(_, opts)
			require("nvim-treesitter").setup(opts)

			local indent_disabled = { ruby = true }
			local regex_highlight = { ruby = true }

			vim.treesitter.language.register("bash", "env")

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter_setup", { clear = true }),
				desc = "Treesitter highlight and indent",
				callback = function(ev)
					local buf = ev.buf
					local ft = vim.bo[buf].filetype
					pcall(vim.treesitter.start, buf)
					if regex_highlight[ft] then
						vim.bo[buf].syntax = "ON"
					end
					if not indent_disabled[ft] and pcall(vim.treesitter.get_parser, buf) then
						vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = "nvim-treesitter/nvim-treesitter",
		init = function()
			-- Verhindert Konflikte mit built-in ftplugin Mappings (z.B. Python ]m/[m)
			-- Alternativ: nur pro Filetype, z.B. vim.g.no_python_maps = true
			vim.g.no_plugin_maps = true
		end,
		config = function()
			require("nvim-treesitter-textobjects").setup {
				select = {
					lookahead = true,
					include_surrounding_whitespace = false,
				},
				move = {
					set_jumps = true,
				},
			}

			local select_maps = {
				{ "af", "@function.outer", "Outer function" },
				{ "if", "@function.inner", "Inner function" },
				{ "ac", "@class.outer", "Outer class" },
				{ "ic", "@class.inner", "Inner class" },
				{ "aa", "@parameter.outer", "Outer parameter" },
				{ "ia", "@parameter.inner", "Inner parameter" },
				{ "aR", "@assignment.rhs", "Right side assignment" },
				{ "aL", "@assignment.lhs", "Left side assignment" },
			}
			for _, m in ipairs(select_maps) do
				local key, query, desc = m[1], m[2], m[3]
				vim.keymap.set({ "x", "o" }, key, function()
					require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
				end, { desc = desc })
			end

			local move_maps = {
				-- goto_next_start
				{ "]f", "goto_next_start", "@function.outer", "textobjects", "Next function start" },
				{ "]c", "goto_next_start", "@class.outer", "textobjects", "Next class start" },
				{ "]a", "goto_next_start", "@parameter.outer", "textobjects", "Next parameter start" },
				{ "]R", "goto_next_start", "@assignment.rhs", "textobjects", "Next right side assignment" },
				{ "]z", "goto_next_start", "@fold", "folds", "Next fold" },
				-- goto_next_end
				{ "]F", "goto_next_end", "@function.outer", "textobjects", "Next function end" },
				{ "]C", "goto_next_end", "@class.outer", "textobjects", "Next class end" },
				{ "]A", "goto_next_end", "@parameter.outer", "textobjects", "Next parameter end" },
				-- goto_previous_start
				{ "[f", "goto_previous_start", "@function.outer", "textobjects", "Previous function start" },
				{ "[c", "goto_previous_start", "@class.outer", "textobjects", "Previous class start" },
				{ "[a", "goto_previous_start", "@parameter.outer", "textobjects", "Previous parameter start" },
				-- goto_previous_end
				{ "[F", "goto_previous_end", "@function.outer", "textobjects", "Previous function end" },
				{ "[C", "goto_previous_end", "@class.outer", "textobjects", "Previous class end" },
				{ "[A", "goto_previous_end", "@parameter.outer", "textobjects", "Previous parameter end" },
			}
			for _, m in ipairs(move_maps) do
				local key, fn_name, query, group, desc = m[1], m[2], m[3], m[4], m[5]
				vim.keymap.set({ "n", "x", "o" }, key, function()
					require("nvim-treesitter-textobjects.move")[fn_name](query, group)
				end, { desc = desc })
			end

			-------------------------------------------------
			-- REPEATABLE MOVES mit ; und ,
			-------------------------------------------------
			local ts_repeat = require "nvim-treesitter-textobjects.repeatable_move"
			vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat.repeat_last_move_next)
			vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat.repeat_last_move_previous)
			vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat.builtin_f_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat.builtin_F_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat.builtin_t_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat.builtin_T_expr, { expr = true })
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		opts = { multiline_threshold = 1 },
	},
	{ "HiPhish/rainbow-delimiters.nvim" },
	{ "fladson/vim-kitty", ft = "kitty" },
	{
		"andymass/vim-matchup",
		---@type matchup.Config
		opts = { treesitter = { stopline = 500 } },
	},
}
