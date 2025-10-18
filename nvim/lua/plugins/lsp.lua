return {
	{
		-- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
		-- used for completion, annotations and signatures of Neovim apis
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				-- Load luvit types when the `vim.uv` word is found
				{ path = "luvit-meta/library", words = { "vim%.uv" } },
			},
		},
	},
	{ "Bilal2453/luvit-meta", lazy = true },
	{
		-- Main LSP Configuration
		"neovim/nvim-lspconfig",
		dependencies = {
			-- Automatically install LSPs and related tools to stdpath for Neovim
			{
				"mason-org/mason.nvim",
				config = true,
			},
			{
				"mason-org/mason-lspconfig.nvim",
			},

			{ "WhoIsSethDaniel/mason-tool-installer.nvim" },

			-- Useful status updates for LSP.
			{ "j-hui/fidget.nvim", opts = {} },

			-- Allows extra capabilities provided by nvim-cmp
			-- "hrsh7th/cmp-nvim-lsp",
			"saghen/blink.cmp",
		},
		config = function()
			vim.opt.pumheight = 20

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					vim.keymap.set(
						"n",
						"<leader>h",
						function()
							vim.lsp.buf.hover { border = "rounded" }
						end,
						-- function() require("pretty_hover").hover() end,
						{ desc = "[H]over documentation" }
					)

					-- Set the border style for the hover and signature help windows
					-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.buf.hover
					vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.buf.signature_help

					-- Jump to the definition of the word under your cursor.
					--  This is where a variable was first declared, or where a function is defined, etc.
					--  To jump back, press <C-t>.
					map("gd", function()
						Snacks.picker.lsp_definitions()
					end, "[G]oto [D]efinition")

					map("g<c-d>", function()
						vim.cmd "vsplit"
						Snacks.picker.lsp_definitions()
					end, "[G]oto [D]efinition (split)")

					-- Find references for the word under your cursor.
					map("gr", function()
						Snacks.picker.lsp_references()
					end, "[G]oto [R]eferences")

					-- Jump to the implementation of the word under your cursor.
					--  Useful when your language has ways of declaring types without an actual implementation.
					map("gI", function()
						Snacks.picker.lsp_implementations()
					end, "[G]oto [I]mplementation")

					-- Jump to the type of the word under your cursor.
					--  Useful when you're not sure what type a variable is and you want to see
					--  the definition of its *type*, not where it was *defined*.
					map("<leader>D", function()
						Snacks.picker.lsp_type_definitions()
					end, "Type [D]efinition")

					-- Fuzzy find all the symbols in your current document.
					--  Symbols are things like variables, functions, types, etc.
					map("<leader>ds", function()
						Snacks.picker.lsp_symbols()
					end, "[D]ocument [S]ymbols")

					-- Fuzzy find all the symbols in your current workspace.
					--  Similar to document symbols, except searches over your entire project.
					map("<leader>ws", function()
						Snacks.picker.lsp_workspace_symbols()
					end, "[W]orkspace [S]ymbols")

					-- Rename the variable under your cursor.
					--  Most Language Servers support renaming across files, etc.
					map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

					-- Execute a code action, usually your cursor needs to be on top of an error
					-- or a suggestion from your LSP for this to activate.
					map("<leader>ca", require("actions-preview").code_actions, "[C]ode [A]ction", { "n", "x" })

					-- WARN: This is not Goto Definition, this is Goto Declaration.
					--  For example, in C this would take you to the header.
					map("gD", function()
						Snacks.picker.lsp_declarations()
					end, "[G]oto [D]eclaration")

					-- The following two autocommands are used to highlight references of the
					-- word under your cursor when your cursor rests there for a little while.
					--    See `:help CursorHold` for information about when this is executed
					--
					-- When you move your cursor, the highlights will be cleared (the second autocommand).
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
						local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds { group = "kickstart-lsp-highlight", buffer = event2.buf }
							end,
						})
					end

					-- The following code creates a keymap to toggle inlay hints in your
					-- code, if the language server you are using supports them
					--
					-- This may be unwanted, since they displace some of your code
					if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			local capabilities = require("blink.cmp").get_lsp_capabilities()
			local servers = {

				-- basedpyright = {
				-- 	settings = {
				-- 		basedpyright = {
				-- 			disableOrganizeImports = true,
				-- 			analysis = {
				-- 				diagnosticMode = "openFilesOnly",
				-- 				ignore = { "*" },
				-- 				-- typeCheckingMode = "basic",
				-- 				-- inlayHints = {
				-- 				-- 	variableTypes = false,
				-- 				-- 	callArgumentNames = false,
				-- 				-- 	functionReturnTypes = false,
				-- 				-- 	genericTypes = false,
				-- 				-- },
				-- 			},
				-- 		},
				-- 	},
				-- },
				pyrefly = {},
				ts_ls = {},
				bashls = {},
				dockerls = {},
				ltex_plus = {
					on_attach = function(client, bufnr)
						require("ltex_extra").setup { path = vim.fn.stdpath "config" .. "/tex" }
					end,
					settings = {
						ltex = {
							enabled = { "markdown", "python" },
							language = "en-US",
						},
					},
				},
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							-- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
							diagnostics = { disable = { "missing-fields" } },
						},
					},
				},
				ruff = {},
				taplo = {},
				typos_lsp = {},
				yamlls = {},
			}

			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"pyrefly",
				"stylua",
				"ruff",
				"bashls",
				"actionlint",
				"fixjson",
				"typos-lsp",
			})

			for server_name, server_config in pairs(servers) do
				server_config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server_config.capabilities or {})
				vim.lsp.config(server_name, server_config)
				vim.lsp.enable(server_name)
			end

			require("mason").setup {
				ensure_installed = ensure_installed,
			}
		end,
	},
	{
		-- preview code actions
		"aznhe21/actions-preview.nvim",
		opts = {
			backend = { "snacks" },
			---@type snacks.picker.Config
			snacks = {
				layout = { preset = "dropdown" },
			},
		},
	},
	{
		-- Call tree hierarchy
		"ldelossa/litee.nvim",
		event = "VeryLazy",
		opts = {
			notify = { enabled = false },
			panel = {
				orientation = "right",
				panel_size = 60,
			},
		},
		config = function(_, opts)
			require("litee.lib").setup(opts)
		end,
	},

	{
		"ldelossa/litee-calltree.nvim",
		dependencies = "ldelossa/litee.nvim",
		event = "VeryLazy",
		opts = {
			on_open = "panel",
			map_resize_keys = false,
		},
		config = function(_, opts)
			require("litee.calltree").setup(opts)
		end,
	},
	-- {
	-- 	"Fildo7525/pretty_hover",
	-- 	event = "LspAttach",
	-- 	opts = { border = "rounded" },
	-- },
}
