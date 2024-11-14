return {
	"chrisgrieser/nvim-rip-substitute",
	cmd = "RipSubstitute",
	keys = {
		{
			"<leader>df",
			function()
				require("rip-substitute").sub()
			end,
			mode = { "n", "x" },
			desc = " substitute",
		},
	},
}
