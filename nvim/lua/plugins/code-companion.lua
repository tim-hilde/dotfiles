return {
	-- dir = "~/code/Projects/codecompanion.nvim/",
	-- dev = true,
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"saghen/blink.cmp",
		"folke/snacks.nvim",
		{ "stevearc/dressing.nvim", opts = {} },
		{ "j-hui/fidget.nvim", opts = {
			notification = {
				window = {
					winblend = 0,
				},
			},
		} },
		"ravitemer/codecompanion-history.nvim",
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
				},
			},

			adapters = {
				http = {
					copilot = function()
						return require("codecompanion.adapters").extend("copilot", {
							schema = {
								model = {
									default = "claude-sonnet-4.5",
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
									default = "gpt-4.1",
								},
							},
						})
					end,
					ollama = function()
						return require("codecompanion.adapters").extend("openai_compatible", {
							env = {
								url = "http://127.0.0.1:1234", -- optional: default value is ollama url http://127.0.0.1:11434
							},
						})
					end,
				},
			},
			strategies = {
				chat = {
					adapter = "copilot",
					tools = {
						opts = {
							requires_approval = false,
							auto_submit_errors = true,
							auto_submit_success = true,
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
				history = {
					enabled = true,
					opts = {
						-- Keymap to open history from chat buffer (default: gh)
						keymap = "gh",
						-- Keymap to save the current chat manually (when auto_save is disabled)
						save_chat_keymap = "sc",
						-- Save all chats by default (disable to save only manually using 'sc')
						auto_save = true,
						-- Number of days after which chats are automatically deleted (0 to disable)
						expiration_days = 0,
						-- Picker interface (auto resolved to a valid picker)
						picker = "snacks", --- ("telescope", "snacks", "fzf-lua", or "default")
						---Optional filter function to control which chats are shown when browsing
						chat_filter = nil, -- function(chat_data) return boolean end
						-- Customize picker keymaps (optional)
						picker_keymaps = {
							rename = { n = "r", i = "<M-r>" },
							delete = { n = "d", i = "<M-d>" },
							duplicate = { n = "<C-y>", i = "<C-y>" },
						},
						---Automatically generate titles for new chats
						auto_generate_title = true,
						title_generation_opts = {
							---Adapter for generating titles (defaults to current chat adapter)
							adapter = nil, -- "copilot"
							---Model for generating titles (defaults to current chat model)
							model = nil, -- "gpt-4o"
							---Number of user prompts after which to refresh the title (0 to disable)
							refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
							---Maximum number of times to refresh the title (default: 3)
							max_refreshes = 3,
							format_title = function(original_title)
								-- this can be a custom function that applies some custom
								-- formatting to the title.
								return original_title
							end,
						},
						---On exiting and entering neovim, loads the last chat on opening chat
						continue_last_chat = false,
						---When chat is cleared with `gx` delete the chat from history
						delete_on_clearing_chat = false,
						---Directory path to save the chats
						dir_to_save = vim.fn.stdpath "data" .. "/codecompanion-history",
						---Enable detailed logging for history extension
						enable_logging = false,

						-- Summary system
						summary = {
							-- Keymap to generate summary for current chat (default: "gcs")
							create_summary_keymap = "gcs",
							-- Keymap to browse summaries (default: "gbs")
							browse_summaries_keymap = "gbs",

							generation_opts = {
								adapter = nil, -- defaults to current chat adapter
								model = nil, -- defaults to current chat model
								context_size = 90000, -- max tokens that the model supports
								include_references = true, -- include slash command content
								include_tool_outputs = true, -- include tool execution results
								system_prompt = nil, -- custom system prompt (string or function)
								format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
							},
						},

						-- Memory system (requires VectorCode CLI)
						memory = {
							-- Automatically index summaries when they are generated
							auto_create_memories_on_summary_generation = true,
							-- Path to the VectorCode executable
							vectorcode_exe = "vectorcode",
							-- Tool configuration
							tool_opts = {
								-- Default number of memories to retrieve
								default_num = 10,
							},
							-- Enable notifications for indexing progress
							notify = true,
							-- Index all existing memories on startup
							-- (requires VectorCode 0.6.12+ for efficient incremental indexing)
							index_on_startup = false,
						},
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
				["PR Review"] = {
					strategy = "chat",
					description = "Perform a code review",
					opts = {
						auto_submit = true,
						user_prompt = false,
					},
					prompts = {
						{
							role = "system",
							content = "You are a senior software engineer performing a code review. Analyze the following code changes.\n"
								.. "Identify any potential bugs, performance issues, security vulnerabilities, or areas that could be refactored for better readability or maintainability.\n"
								.. "Explain your reasoning clearly and provide specific suggestions for improvement.\n"
								.. "Consider edge cases, error handling, and adherence to best practices and coding standards.\n"
								.. "Do a review for each file. Files like lock files can be ignored.\n",
						},
						{
							role = "user",
							content = function()
								local target_branch = vim.fn.input("Target branch for merge diff (default: main): ", "main")

								return string.format(
									"You can use @{sequentialthinking} to plan your review." .. "Here are the code changes:\n\n```diff\n%s\n```",
									vim.fn.system("git diff --merge-base " .. target_branch .. " -- . ':(exclude)*.lock' ':(exclude)*-lock.json'")
								)
							end,
						},
					},
				},
				["PR Summary"] = {
					strategy = "chat",
					description = "Write a PR summary",
					opts = {
						auto_submit = true,
						user_prompt = false,
					},
					prompts = {
						{
							role = "system",
							content = "You are a technical writer creating a GitHub pull request summary.\n"
								.. "Write a clear, professional summary that explains what changes were made and why."
								.. "Include the problem being solved, the solution implemented, and any important technical details or side effects."
								.. "Keep the tone factual and concise.\n"
								.. "Structure the summary with a brief title line (should be conventional commit message), a summary and the impact of the whole PR. This is followed by 2-3 paragraphs for each change."
								.. "Files like lock files can be ignored.\n"
								.. "The goal is to be able to copy paste the summary into GitHub. Put the summary into a markdown code block like this:\n"
								.. "\n```markdown\n"
								.. "PR SUMMARY TEXT\n"
								.. "```",
						},
						{
							role = "user",
							content = function()
								local target_branch = vim.fn.input("Target branch for diff (default: main): ", "main")
								return string.format("Here are the code changes:\n\n```diff\n%s\n```", vim.fn.system("git diff " .. target_branch))
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
