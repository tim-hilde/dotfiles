return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			icons_enabled = true,
			theme = "catppuccin",
			component_separators = { left = "|", right = "|" },
			section_separators = { left = "", right = "" },
			disabled_filetypes = {},
			always_divide_middle = true,
			-- globalstatus = true,
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch", "diff", "diagnostics" },
			lualine_c = {
				{
					"filename",
					path = 1,
					-- 0: Just the filename
					-- 1: Relative path
					-- 2: Absolute path
					-- 3: Absolute path, with tilde as the home directory
					-- 4: Filename and parent dir, with tilde as the home directory
				},
			},
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = {
				{
					function()
						local mode = vim.fn.mode()
						if mode == "v" or mode == "V" or mode == "\22" then -- \22 is visual block mode
							local start_pos = vim.fn.getpos "v"
							local end_pos = vim.fn.getpos "."

							if mode == "v" then
								-- Character-wise visual mode
								local start_line, start_col = start_pos[2], start_pos[3]
								local end_line, end_col = end_pos[2], end_pos[3]

								if start_line == end_line then
									local count = math.abs(end_col - start_col) + 1
									return string.format("%d", count)
								else
									local lines = math.abs(end_line - start_line) + 1
									return string.format("%d", lines)
								end
							elseif mode == "V" then
								-- Line-wise visual mode
								local lines = math.abs(end_pos[2] - start_pos[2]) + 1
								return string.format("%d", lines)
							elseif mode == "\22" then
								-- Block-wise visual mode
								local lines = math.abs(end_pos[2] - start_pos[2]) + 1
								local cols = math.abs(end_pos[3] - start_pos[3]) + 1
								return string.format("%dx%d", lines, cols)
							end
						else
							-- Show location when not in visual mode
							return "%l:%c"
						end
						return ""
					end,
				},
			},
		},
	},
}
