return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		-- "hrsh7th/nvim-cmp", -- Optional: For using slash commands and variables in the chat buffer
		"saghen/blink.cmp",
		"folke/snacks.nvim", -- Optional: For using slash commands
		{ "stevearc/dressing.nvim", opts = {} }, -- Optional: Improves `vim.ui.select`
		"j-hui/fidget.nvim",
	},
	config = function()
		-- Fidget integration
		local fidget_progress_handle = nil

		local function start_fidget()
			local has_fidget, fidget = pcall(require, "fidget")
			if not has_fidget then
				return
			end

			if fidget_progress_handle then
				fidget_progress_handle.message = "Abort."
				fidget_progress_handle:cancel()
				fidget_progress_handle = nil
			end

			fidget_progress_handle = fidget.progress.handle.create {
				title = "",
				message = "Thinking...",
				lsp_client = { name = "CodeCompanion" },
			}
		end

		local function stop_fidget()
			local has_fidget, _ = pcall(require, "fidget")
			if not has_fidget then
				return
			end

			if fidget_progress_handle then
				fidget_progress_handle.message = "Done."
				fidget_progress_handle:finish()
				fidget_progress_handle = nil
			end
		end

		-- Setup fidget hooks
		local has_fidget, _ = pcall(require, "fidget")
		if has_fidget then
			-- New AU group:
			local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})

			-- Attach:
			vim.api.nvim_create_autocmd({ "User" }, {
				pattern = "CodeCompanionRequest*",
				group = group,
				callback = function(request)
					if request.match == "CodeCompanionRequestStarted" then
						start_fidget()
					elseif request.match == "CodeCompanionRequestFinished" then
						stop_fidget()
					end
				end,
			})
		end

		require("codecompanion").setup {
			display = {
				chat = {
					start_in_insert_mode = true,
				},
			},
			adapters = {
				copilot = function()
					return require("codecompanion.adapters").extend("copilot", {
						schema = {
							model = {
								default = "claude-3.7-sonnet",
							},
						},
					})
				end,
			},
			strategies = {
				chat = {
					adapter = "copilot",
					slash_commands = {
						codebase = require("vectorcode.integrations").codecompanion.chat.make_slash_command(),
					},
					tools = {
						vectorcode = {
							description = "Run VectorCode to retrieve the project context.",
							callback = require("vectorcode.integrations").codecompanion.chat.make_tool(),
						},
						mcp = {
							callback = function()
								return require "mcphub.extensions.codecompanion"
							end,
							description = "Call tools and resources from the MCP Servers",
						},
					},
				},
				inline = {
					adapter = "copilot",
				},
				agent = {
					adapter = "copilot",
				},
			},
			prompt_library = {
				["Docstring"] = {
					strategy = "inline",
					description = "Generate docstring for this function",
					opts = {
						modes = { "v" },
						short_name = "docstring",
						auto_submit = true,
						stop_context_insertion = true,
						user_prompt = false,
					},
					prompts = {
						{
							role = "system",
							content = function(context)
								return "I want you to act as a senior "
									.. context.filetype
									.. " developer."
									.. "I will send you a function and I want you to generate the docstrings for the function using the google format."
									.. "Generate only the docstrings and nothing more. Put the generated docstring at the correct position in the code depending on the programming language."
									.. "Use tabs instead of spaces"
							end,
						},
						{
							role = "user",
							content = function(context)
								local text = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

								return text
							end,
							opts = {
								visible = false,
								placement = "add",
								contains_code = true,
							},
						},
					},
				},
			},
		}
	end,
}
