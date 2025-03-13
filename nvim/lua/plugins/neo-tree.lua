return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	config = function()
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

		require("neo-tree").setup {
			close_if_last_window = true,
			event_handlers = {
				{
					event = "file_opened",
					handler = function(file_path)
						print("Opened file: " .. file_path)
					end,
				},
			},
			filesystem = {
				window = {
					mappings = {
						["<c-c>"] = function(state)
							local node = state.tree:get_node()
							local path = node:get_id()
							local codecompanion = require "codecompanion"
							local chat = codecompanion.last_chat()

							-- create chat if none exists
							if not chat then
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
						end,
					},
				},
			},
		}
	end,
}
