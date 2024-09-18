return {
	"ptdewey/yankbank-nvim",
	dependencies = "kkharji/sqlite.lua",
	config = function()
		require("yankbank").setup {
			persist_type = "sqlite",
			focus_gain_poll = true,
		}
	end,
}
