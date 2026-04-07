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
			local select = require "nvim-treesitter-textobjects.select"
			local move = require "nvim-treesitter-textobjects.move"
			local ts_repeat = require "nvim-treesitter-textobjects.repeatable_move"

			-- Setup: nur Optionen, keine Keymaps mehr
			require("nvim-treesitter-textobjects").setup {
				select = {
					lookahead = true,
					include_surrounding_whitespace = false,
				},
				move = {
					set_jumps = true,
				},
			}

			-------------------------------------------------
			-- SELECT
			-------------------------------------------------
			local select_maps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["ar"] = "@assignment.rhs",
				["al"] = "@assignment.lhs",
			}
			for key, query in pairs(select_maps) do
				vim.keymap.set({ "x", "o" }, key, function()
					select.select_textobject(query, "textobjects")
				end, { desc = "TS: " .. query })
			end

			-------------------------------------------------
			-- MOVE
			-------------------------------------------------
			local move_maps = {
				-- goto_next_start
				{ "]f", move.goto_next_start, "@function.outer" },
				{ "]c", move.goto_next_start, "@class.outer" },
				{ "]a", move.goto_next_start, "@parameter.outer" },
				{ "]r", move.goto_next_start, "@assignment.rhs" },
				{ "]z", move.goto_next_start, "@fold", "folds" },
				-- goto_next_end
				{ "]F", move.goto_next_end, "@function.outer" },
				{ "]C", move.goto_next_end, "@class.outer" },
				{ "]A", move.goto_next_end, "@parameter.outer" },
				-- goto_previous_start
				{ "[f", move.goto_previous_start, "@function.outer" },
				{ "[c", move.goto_previous_start, "@class.outer" },
				{ "[a", move.goto_previous_start, "@parameter.outer" },
				-- goto_previous_end
				{ "[F", move.goto_previous_end, "@function.outer" },
				{ "[C", move.goto_previous_end, "@class.outer" },
				{ "[A", move.goto_previous_end, "@parameter.outer" },
			}
			for _, m in ipairs(move_maps) do
				local key, fn, query, group = m[1], m[2], m[3], m[4] or "textobjects"
				vim.keymap.set({ "n", "x", "o" }, key, function()
					fn(query, group)
				end, { desc = "TS move: " .. key .. " " .. query })
			end
			-------------------------------------------------
			-- REPEATABLE MOVES mit ; und ,
			-------------------------------------------------
			vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat.repeat_last_move_next)
			vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat.repeat_last_move_previous)
			-- f/F/t/T ebenfalls repeatable machen
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
