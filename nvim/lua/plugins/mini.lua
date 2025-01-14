-- Collection of various small independent plugins/modules
return {
	"echasnovski/mini.nvim",
	config = function()
		-- Better Around/Inside textobjects
		--
		-- Examples:
		--  - va)  - [V]isually select [A]round [)]paren
		--  - yinq - [Y]ank [I]nside [N]ext [Q]uote
		--  - ci'  - [C]hange [I]nside [']quote
		require("mini.ai").setup { n_lines = 500 }

		-- Add/delete/replace surroundings (brackets, quotes, etc.)
		--
		-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
		-- - sd'   - [S]urround [D]elete [']quotes
		-- - sr)'  - [S]urround [R]eplace [)] [']
		require("mini.surround").setup {
			-- Module mappings. Use `''` (empty string) to disable one.
			mappings = {
				add = "sa", -- Add surrounding in Normal and Visual modes
				delete = "sd", -- Delete surrounding
				find = "sf", -- Find surrounding (to the right)
				find_left = "sF", -- Find surrounding (to the left)
				highlight = "sh", -- Highlight surrounding
				replace = "sr", -- Replace surrounding
				update_n_lines = "sn", -- Update `n_lines`
			},
		}
		require("mini.operators").setup {
			replace = {
				prefix = "cr",
			},
			exchange = {
				prefix = "cx",
			},
		}

		-- Show start up screen
		-- require("mini.starter").setup()
		-- local override_mappings = function(args)
		-- 	vim.keymap.set("n", "<C-j>", "<Cmd>lua MiniStarter.update_current_item('next')<CR>", { buffer = args.buf })
		-- 	vim.keymap.set("n", "<C-k>", "<Cmd>lua MiniStarter.update_current_item('previous')<CR>", { buffer = args.buf })
		-- 	vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left toggle<CR>", { buffer = args.buf })
		-- end
		-- vim.api.nvim_create_autocmd("User", { pattern = "MiniStarterOpened", callback = override_mappings })
	end,
}
