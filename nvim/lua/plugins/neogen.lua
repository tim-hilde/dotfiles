-- Docstring creation
-- - quickly create docstrings via `<leader>a`
return {
	"danymat/neogen",
	opts = {
		snippet_engine = "luasnip",
		languages = {
			python = {
				template = {
					annotation_convention = "numpydoc",
				},
			},
		},
	},
}
