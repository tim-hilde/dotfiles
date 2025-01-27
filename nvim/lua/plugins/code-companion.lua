return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"hrsh7th/nvim-cmp", -- Optional: For using slash commands and variables in the chat buffer
		"nvim-telescope/telescope.nvim", -- Optional: For using slash commands
		{ "stevearc/dressing.nvim", opts = {} }, -- Optional: Improves `vim.ui.select`
	},
	config = function()
		require("codecompanion").setup {
			adapters = {
				ollama = function()
					return require("codecompanion.adapters").extend("ollama", {
						schema = {
							model = {
								default = "deepseek-r1:32b",
							},
						},
					})
				end,
				-- copilot = function()
				-- 	return require("codecompanion.adapters").extend("copilot", {
				-- 		schema = {
				-- 			model = {
				-- 				default = "claude-3.5-sonnet",
				-- 			},
				-- 		},
				-- 	})
				-- end,
			},
			strategies = {
				chat = {
					adapter = "ollama",
				},
				inline = {
					adapter = "ollama",
				},
				agent = {
					adapter = "ollama",
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
									.. " developer. I will send you a function and I want you to generate the docstrings for the function using the numpy format. Generate only the docstrings and nothing more. Put the generated docstring at the correct position in the code. Use tabs instead of spaces"
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
