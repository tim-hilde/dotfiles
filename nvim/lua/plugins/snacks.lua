return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		dashboard = {
			enabled = true,
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "startup" },
			},
		},
		bigfile = { enabled = true },
		statuscolumn = { enabled = true },
		picker = {
			enabled = true,
		},
		keys = {

			{
				"n",
				"<leader>sh",
				function()
					Snacks.picker.help()
				end,
				{ desc = "[S]earch [H]elp" },
			},
			-- {"n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" }},
			{
				"n",
				"<leader>sf",
				function()
					Snacks.picker.smart()
				end,
				{ desc = "[S]earch [F]iles" },
			},
			{
				"n",
				"<leader>ss",
				function()
					Snacks.picker()
				end,
				{ desc = "[S]earch [S]elect Pickers" },
			},
			{
				"n",
				"<leader>sw",
				function()
					Snacks.picker.grep_word()
				end,
				{ desc = "[S]earch current [W]ord" },
			},
			{ "n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" } },
			{ "n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" } },
			{ "n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" } },
			{ "n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat' } },
		},
	},
}
