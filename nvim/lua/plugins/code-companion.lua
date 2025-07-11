return {
	-- dir = "~/code/Projects/codecompanion.nvim/",
	-- dev = true,
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
					start_in_insert_mode = false,
					show_settings = false,
				},
				action_palette = {
					provider = "default",
				},
				slash_commands = {
					opts = {
						provider = "snacks",
					},
				},
				diff = {
					enabled = true,
					provider = "default",
				},
			},
			adapters = {
				copilot = function()
					return require("codecompanion.adapters").extend("copilot", {
						schema = {
							model = {
								default = "claude-sonnet-4",
							},
						},
					})
				end,
				azure_openai = function()
					return require("codecompanion.adapters").extend("azure_openai", {
						env = {
							api_key = "CC_AZURE_API_KEY",
							endpoint = "CC_AZURE_ENDPOINT",
						},
						schema = {
							model = {
								default = "gpt-4o",
							},
						},
					})
				end,
			},
			strategies = {
				chat = {
					adapter = "copilot",
					tools = {
						opts = {
							auto_submit_errors = true, -- Send any errors to the LLM automatically?
							auto_submit_success = true, -- Send any successful output to the LLM automatically?
						},
					},
					slash_commands = {
						["file"] = {
							opts = {
								provider = "snacks",
							},
						},
						["buffer"] = {
							opts = {
								provider = "snacks",
							},
						},
						["symbols"] = {
							opts = {
								provider = "snacks",
							},
						},
					},
					keymaps = {
						send = {
							modes = {
								n = { "<CR>", "<C-i>" },
								i = "<C-i>",
							},
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
			extensions = {
				mcp = {
					callback = function()
						return require "mcphub.extensions.codecompanion"
					end,
					opts = {
						show_result_in_chat = true, -- Show the mcp tool result in the chat buffer
						make_vars = true, -- make chat #variables from MCP server resources
						make_slash_commands = true, -- make /slash_commands from MCP server prompts
					},
				},
			},
			prompt_library = {
				["Docstring"] = {
					strategy = "inline",
					description = "Generate docstrings.",
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
									.. "I will send you a function or class and I want you to generate the docstrings using the google format."
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
				["Diff code review"] = {
					strategy = "chat",
					description = "Perform a code review",
					opts = {
						auto_submit = true,
						user_prompt = false,
					},
					prompts = {
						{
							role = "user",
							content = function()
								local target_branch = vim.fn.input("Target branch for merge base diff (default: master): ", "master")

								return string.format(
									[[
          You are a senior software engineer performing a code review. Analyze the following code changes.
           Identify any potential bugs, performance issues, security vulnerabilities, or areas that could be refactored for better readability or maintainability.
           Explain your reasoning clearly and provide specific suggestions for improvement.
           Consider edge cases, error handling, and adherence to best practices and coding standards.
           Here are the code changes:
           ```
            %s
           ```
           ]],
									vim.fn.system("git diff --merge-base " .. target_branch)
								)
							end,
						},
					},
				},
				["Review the code"] = {
					strategy = "inline",
					description = "Review the code in buffer",
					prompts = {
						{
							role = "system",
							content = [[You are an experienced senior developer. You do code reviews.]],
						},
						{
							role = "user",
							content = "#buffer\n\nPlease review the code in the file and make the fixes if any.",
						},
					},
				},
			},
		}
	end,
}
