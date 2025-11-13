return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format { async = true, lsp_format = "fallback" }
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = false,
		format_on_save = function(bufnr)
			-- Disable "format_on_save lsp_fallback" for languages that don't
			-- have a well standardized coding style. You can add additional
			-- languages here or re-enable it for the disabled ones.
			local disable_filetypes = { c = true, cpp = true }
			if disable_filetypes[vim.bo[bufnr].filetype] then
				return nil
			else
				return {
					timeout_ms = 500,
					lsp_format = "fallback",
				}
			end
		end,
		formatters_by_ft = {
			json = { "fixjson" },
			lua = { "stylua" },
			markdown = { "markdownlint" },
			python = { "ruff_format", "ruff_organize_imports" },
			shell = { "beautysh" },
			toml = { "taplo" },
			yaml = { "yamlfmt" },
			yml = { "yamlfmt" },
		},
		formatters = {
			yamlfmt = {
				args = { "-formatter", "retain_line_breaks=true" },
			},
			markdownlint = {
				prepend_args = {
					"--config",
					vim.fn.stdpath "config" .. "/formatters/markdownlint.json",
				},
			},
			-- 	stylua = {
			-- 		indent_style = "Spaces",
			-- 		indent_width = 2,
			-- 	},
			-- },
		},
	},
}
