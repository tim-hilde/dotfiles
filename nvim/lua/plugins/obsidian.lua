return {
	"obsidian-nvim/obsidian.nvim",
	ft = "markdown",
	---@module 'obsidian'
	---@type obsidian.config
	opts = {
		workspaces = {
			{
				name = "personal",
				path = "~/Zettelkasten/",
			},
		},
	},
}
