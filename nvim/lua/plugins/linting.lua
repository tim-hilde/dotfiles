return {

	{ -- Linting
		"mfussenegger/nvim-lint",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.filetype.add {
				pattern = {
					[".*/.github/workflows/.*%.yml"] = "yaml.ghaction",
					[".*/.github/workflows/.*%.yaml"] = "yaml.ghaction",
				},
			}
			local lint = require "lint"
			lint.linters_by_ft = {
				yaml = { "yamllint" },
				-- github action
				ghaction = { "actionlint" },
				shell = { "shellcheck" },
				typescriptreact = { "eslint_d" },
			}

			-- Create autocommand which carries out the actual linting
			-- on the specified events.
			local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
				group = lint_augroup,
				callback = function()
					lint.try_lint()
					lint.try_lint { "woke" }
				end,
			})
		end,
	},
}
