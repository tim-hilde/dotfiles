return {
	dir = "~/code/Projects/dooing",
	dev = true,
	-- "atiladefreitas/dooing",
	config = function()
		require("dooing").setup {
			keymaps = {
				toggle_window = "<leader>tD", -- Toggle global todos
			},
			calendar = {
				language = "de",
				start_day = "monday",
			},
			per_project = {
				enabled = false,
			},
		}
	end,
}
