return {
	"atiladefreitas/dooing",
	config = function()
		require("dooing").setup {
			keymaps = {
				toggle_window = "<leader>tD", -- Toggle global todos
			},
			calendar = {
				language = "de",
			},
			per_project = {
				enabled = false,
			},
		}
	end,
}
