return {
	"nanozuki/tabby.nvim",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("tabby").setup {
			preset = "tab_only",
			option = {
				lualine_theme = "catppuccin",
				nerdfont = true,
			},
			line = function(line)
				local theme = {
					fill = "TabLineFill",
					head = { fg = "#8aadf4", bg = "#24273a" },
					current_tab = { fg = "#1e2030", bg = "#8aadf4" },
					tab = { fg = "#8aadf4", bg = "#24273a" },
					win = { fg = "#1e2030", bg = "#8aadf4" },
					tail = { fg = "#8aadf4", bg = "#24273a" },
				}
				return {
					{
						{ "  ", hl = theme.head },
						line.sep(" ", theme.head, theme.fill), -- 
					},
					line.tabs().foreach(function(tab)
						local hl = tab.is_current() and theme.current_tab or theme.tab
						return {
							line.sep("", hl, theme.fill), -- 
							tab.is_current() and "" or "",
							tab.number(),
							tab.name(),
							-- tab.close_btn(''), -- show a close button
							line.sep("", hl, theme.fill), -- 
							hl = hl,
							margin = " ",
						}
					end),

					line.spacer(),
					-- shows list of windows in tab
					--line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
					--  return {
					--    line.sep('', theme.win, theme.fill),
					--    win.is_current() and '' or '',
					--    win.buf_name(),
					--    line.sep('', theme.win, theme.fill),
					--    hl = theme.win,
					--    margin = ' ',
					--  }
					--end),
					{
						line.sep("|", theme.tail, theme.fill), -- 
						{ "  ", hl = theme.tail },
					},
					hl = theme.fill,
				}
			end,
		}
	end,
}
