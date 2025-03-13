return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		require("neo-tree").setup {
			close_if_last_window = true,
			-- filesystem = {
			-- 	filtered_items = {
			-- 		visible = true, -- when true, they will just be displayed differently than normal items
			-- 		hide_dotfiles = false,
			-- 		hide_gitignored = false,
			-- 		never_show = {
			-- 			".DS_Store",
			-- 			"thumbs.db",
			-- 		},
			-- 	},
			-- },
		}
	end,
}
