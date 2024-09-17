-- Docstring creation
-- - quickly create docstrings via `<leader>a`
return {
	"danymat/neogen",
	opts = true,
	keys = {
		{
			"<leader>ca",
			function()
				require("neogen").generate()
			end,
			desc = "Add Docstring",
		},
	},
}
