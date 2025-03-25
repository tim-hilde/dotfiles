return {
	-- Useful plugin to show you pending keybinds.
	"folke/which-key.nvim",
	event = "VimEnter", -- Sets the loading event to 'VimEnter'
	opts = {
		preset = "modern",
		icon = {
			-- set icon mappings to true if you have a Nerd Font
			mappings = vim.g.have_nerd_font,
			-- If you are using a Nerd Font: set icon.keys to an empty table which will use the
			-- default whick-key.nvim defined Nerd Font icon, otherwise define a string table
			keys = vim.g.have_nerd_font and {} or {
				Up = "<Up> ",
				Down = "<Down> ",
				Left = "<Left> ",
				Right = "<Right> ",
				C = "<C-…> ",
				M = "<M-…> ",
				D = "<D-…> ",
				S = "<S-…> ",
				CR = "<CR> ",
				Esc = "<Esc> ",
				ScrollWheelDown = "<ScrollWheelDown> ",
				ScrollWheelUp = "<ScrollWheelUp> ",
				NL = "<NL> ",
				BS = "<BS> ",
				Space = "<Space> ",
				Tab = "<Tab> ",
				F1 = "<F1>",
				F2 = "<F2>",
				F3 = "<F3>",
				F4 = "<F4>",
				F5 = "<F5>",
				F6 = "<F6>",
				F7 = "<F7>",
				F8 = "<F8>",
				F9 = "<F9>",
				F10 = "<F10>",
				F11 = "<F11>",
				F12 = "<F12>",
			},
		},

		-- Document existing key chains
		spec = {
			{ "<leader>c", group = "[C]ode", mode = { "n", "x" }, icon = "" },
			{ "<leader>b", group = "De[b]ug", mode = { "n", "v" }, icon = "" },
			{ "<leader>d", group = "[D]ocument", icon = "󰈙" },
			{ "<leader>r", group = "[R]ename", icon = "" },
			{ "<leader>s", group = "[S]earch", icon = "" },
			{ "<leader>w", group = "[W]orkspace", icon = "󰇄" },
			{ "<leader>t", group = "[T]oggle", mode = { "n", "v" } },
			{ "<leader>i", group = "[I]ronRepl", mode = { "n", "v" } },
			{ "<leader>wa", group = "[A]utosession" },
			{ "<C-w>t", group = "[T]abs" },
			{ "<C-w>tm", group = "[M]ove" },
		},
	},
}
