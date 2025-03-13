return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		local function neo_tree_on_attach(bufnr)
			local luv = vim.loop

			-- Function to recursively add files in a directory to chat references
			local function traverse_directory(path, chat)
				local handle, err = luv.fs_scandir(path)
				if not handle then
					return print("Error scanning directory: " .. err)
				end
				while true do
					local name, type = luv.fs_scandir_next(handle)
					if not name then
						break
					end
					local item_path = path .. "/" .. name
					if type == "file" then
						-- add the file to references
						chat.references:add {
							id = "<file>" .. item_path .. "</file>",
							path = item_path,
							source = "codecompanion.strategies.chat.slash_commands.file",
							opts = {
								pinned = true,
							},
						}
					elseif type == "directory" then
						-- recursive call for a subdirectory
						traverse_directory(item_path, chat)
					end
				end
			end

			-- Add custom command for adding files to chat
			vim.keymap.set("n", "<C-c>", function()
				-- Get the node under cursor using Neo-tree's state
				local state = require "neo-tree.state"
				local tree = state.get_tree()
				local node = tree:get_node()

				if not node then
					return
				end

				local path = node.path
				local codecompanion = require "codecompanion"
				local chat = codecompanion.last_chat()

				-- create chat if none exists
				if chat == nil then
					chat = codecompanion.chat()
				end

				local attr = luv.fs_stat(path)
				if attr and attr.type == "directory" then
					-- Recursively traverse the directory
					traverse_directory(path, chat)
				else
					-- if already added, ignore
					for _, ref in ipairs(chat.refs) do
						if ref.path == path then
							return print "Already added"
						end
					end
					chat.references:add {
						id = "<file>" .. path .. "</file>",
						path = path,
						source = "codecompanion.strategies.chat.slash_commands.file",
						opts = {
							pinned = true,
						},
					}
				end
			end, { buffer = bufnr, desc = "Add or Pin file to Chat" })
		end
		require("neo-tree").setup {
			close_if_last_window = true,
			event_handlers = {
				event = "neo_tree_buffer_enter",
				handler = function(args)
					neo_tree_on_attach(args.buffer)
				end,
			},
		}
	end,
}
