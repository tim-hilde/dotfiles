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
			{ "williamboman/mason.nvim", config = true }, -- NOTE: Must be loaded before dependants
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",

			-- Useful status updates for LSP.
			{ "j-hui/fidget.nvim", opts = {} },

			-- Allows extra capabilities provided by nvim-cmp
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- Brief aside: **What is LSP?**
			--
			-- LSP is an initialism you've probably heard, but might not understand what it is.
			--
			-- LSP stands for Language Server Protocol. It's a protocol that helps editors
			-- and language tooling communicate in a standardized fashion.
			--
			-- In general, you have a "server" which is some tool built to understand a particular
			-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
			-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
			-- processes that communicate with some "client" - in this case, Neovim!
			--
			-- LSP provides Neovim with features like:
			--  - Go to definition
			--  - Find references
			--  - Autocompletion
			--  - Symbol Search
			--  - and more!
			--
			-- Thus, Language Servers are external tools that must be installed separately from
			-- Neovim. This is where `mason` and related plugins come into play.
			--
			-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
			-- and elegantly composed help section, `:help lsp-vs-treesitter`

			--  This function gets run when an LSP attaches to a particular buffer.
			--    That is to say, every time a new file is opened that is associated with
			--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
			--    function will be executed to configure the current buffer
			if not vim.g.vscode then
				vim.opt.pumheight = 20

				vim.api.nvim_create_autocmd("LspAttach", {
					group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
					callback = function(event)
						-- NOTE: Remember that Lua is a real programming language, and as such it is possible
						-- to define small helper and utility functions so you don't have to repeat yourself.
						--
						-- In this case, we create a function that lets us more easily define mappings specific
						-- for LSP related items. It sets the mode, buffer and description for us each time.
						local map = function(keys, func, desc, mode)
							mode = mode or "n"
							vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
						end

						-- Custom hover function to remove weird strings
						local util = require "vim.lsp.util"

						local function split_lines(value)
							-- handle all the stuff that can be done globally here.
							value = string.gsub(value, "&gt;", ">")
							value = string.gsub(value, "&lt;", "<")
							value = string.gsub(value, "\\_", "_")

							-- then split on newline
							local split = vim.split(value, "\n", { plain = true, trimempty = true })

							-- now fix the indent levels.
							local indent_level = 0

							for line_no, line in pairs(split) do
								line, count = string.gsub(line, "&nbsp;", " ")

								-- if blank line then reset indent because we are on next param.
								if line == "" then
									indent_level = 0
								end

								-- if there should be indent and there was no subbing of `&nbsp;` then indent.
								-- note the and is needed because otherwise it will indnet the `&nbsp;` and that is already done.
								if indent_level > 0 and count == 0 then
									for _ = 1, indent_level, 1 do
										line = " " .. line
									end
								end

								-- update the indent_level to the number of `&nbsp;` chars found.
								if count > 0 then
									indent_level = count
								end

								-- finally update the line in the split which is a table of all the lines split by `\n`
								split[line_no] = line
							end

							return split
						end

						local function convert_input_to_markdown_lines(input, contents)
							contents = contents or {}
							assert(type(input) == "table", "Expected a table for LSP input")
							if input.kind then
								local value = input.value or ""
								vim.list_extend(contents, split_lines(value))
							end
							if (contents[1] == "" or contents[1] == nil) and #contents == 1 then
								return {}
							end
							return contents
						end

						-- The overwritten hover function for pyright fucking around.
						local function hover(_, result, ctx, config)
							local ms = require("vim.lsp.protocol").Methods
							config = config or {}
							config.border = "rounded"
							config.focus_id = ms.textDocument_hover
							if vim.api.nvim_get_current_buf() ~= ctx.bufnr then
								-- Ignore result since buffer changed. This happens for slow language servers.
								return
							end

							-- return nothing and print no info if no content
							if not (result and result.contents) then
								if config.silent ~= true then
									vim.notify "No information available"
								end
								return
							end

							local contents ---@type string[]
							contents = convert_input_to_markdown_lines(result.contents)

							-- return nothing and print no info if no content
							if vim.tbl_isempty(contents) then
								if config.silent ~= true then
									vim.notify "No information available"
								end
								return
							end

							-- finally oprn the floating hover window and display the new contents just formatted in markdown format.
							return util.open_floating_preview(contents, "markdown", config)
						end

						vim.lsp.buf.hover = function()
							hover { border = "rounded" }
						end

						vim.keymap.set(
							"n",
							"<leader>h",
							vim.lsp.buf.hover,
							-- function() require("pretty_hover").hover() end,
							{ desc = "[H]over documentation" }
						)

						-- Set the border style for the hover and signature help windows
						-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.buf.hover
						vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.buf.signature_help

						-- Jump to the definition of the word under your cursor.
						--  This is where a variable was first declared, or where a function is defined, etc.
						--  To jump back, press <C-t>.
						map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
						map("g<c-d>", function()
							vim.cmd "vsplit"
							require("telescope.builtin").lsp_definitions()
						end, "[G]oto [D]efinition (split)")

						-- Find references for the word under your cursor.
						map("gr", function()
							require("telescope.builtin").lsp_references { trim_text = true }
						end, "[G]oto [R]eferences")

						-- Jump to the implementation of the word under your cursor.
						--  Useful when your language has ways of declaring types without an actual implementation.
						map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

						-- Jump to the type of the word under your cursor.
						--  Useful when you're not sure what type a variable is and you want to see
						--  the definition of its *type*, not where it was *defined*.
						map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")

						-- Fuzzy find all the symbols in your current document.
						--  Symbols are things like variables, functions, types, etc.
						map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")

						-- Fuzzy find all the symbols in your current workspace.
						--  Similar to document symbols, except searches over your entire project.
						map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

						-- Rename the variable under your cursor.
						--  Most Language Servers support renaming across files, etc.
						map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

						-- Execute a code action, usually your cursor needs to be on top of an error
						-- or a suggestion from your LSP for this to activate.
						map("<leader>ca", require("actions-preview").code_actions, "[C]ode [A]ction", { "n", "x" })

						-- WARN: This is not Goto Definition, this is Goto Declaration.
						--  For example, in C this would take you to the header.
						map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

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
			end

			-- LSP servers and clients are able to communicate to each other what features they support.
			-- LSP servers and clients are able to communicate to each other what features they support.
			--  By default, Neovim doesn't support everything that is in the LSP specification.
			--  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
			--  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

			-- Enable the following language servers
			--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
			--
			--  Add any additional override configuration in the following tables. Available keys are:
			--  - cmd (table): Override the default command used to start the server
			--  - filetypes (table): Override the default list of associated filetypes for the server
			--  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
			--  - settings (table): Override the default settings passed when initializing the server.
			--        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
			local servers = {
				-- clangd = {},
				-- gopls = {},
				-- pyright = {},
				-- rust_analyzer = {},
				-- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
				--
				-- Some languages (like typescript) have entire language plugins that can be useful:
				--    https://github.com/pmizio/typescript-tools.nvim
				--
				-- But for many setups, the LSP (`tsserver`) will work just fine
				-- tsserver = {},
				--

				lua_ls = {
					-- cmd = {...},
					-- filetypes = { ...},
					-- capabilities = {},
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							-- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
							-- diagnostics = { disable = { 'missing-fields' } },
						},
					},
				},
				-- jedi_language_server = {
				-- 	settings = {
				-- 		jedi_language_server = {
				-- 			diagnostics = {
				-- 				enable = false,
				-- 			},
				-- 			markupKindPreferred = "markdown",
				-- 		},
				-- 	},
				-- },
				ruff = {},
				basedpyright = {
					settings = {
						basedpyright = {
							disableOrganizeImports = true,
							analysis = {
								ignore = { "*" },
								-- typeCheckingMode = "basic",
								-- inlayHints = {
								-- 	variableTypes = true,
								-- 	callArgumentNames = true,
								-- 	functionReturnTypes = true,
								-- 	genericTypes = true,
								-- },
							},
						},
					},
				},
				bashls = {},
				yamlls = {},
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
			}

			-- Ensure the servers and tools above are installed
			--  To check the current status of installed tools and/or manually install
			--  other tools, you can run
			--    :Mason
			--
			--  You can press `g?` for help in this menu.
			require("mason").setup {
				registries = {
					"github:mason-org/mason-registry",
					"github:visimp/mason-registry",
				},
			}

			-- You can add other tools here that you want Mason to install
			-- for you, so that they are available from within Neovim.
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"stylua", -- Used to format Lua code
				"ruff",
				"bashls",
			})
			require("mason-tool-installer").setup { ensure_installed = ensure_installed }

			require("mason-lspconfig").setup {
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						-- This handles overriding only values explicitly passed
						-- by the server configuration above. Useful when disabling
						-- certain features of an LSP (for example, turning off formatting for tsserver)
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			}
		end,
	},
	{
		-- preview code actions
		"aznhe21/actions-preview.nvim",
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
-- vim: ts=2 sts=2 sw=2 et
