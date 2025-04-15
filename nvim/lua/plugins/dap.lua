return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		keys = {
			{
				"<leader>bu",
				function()
					require("dapui").toggle {}
				end,
				desc = "Dap UI",
			},
			{
				"<leader>be",
				function()
					require("dapui").eval()
				end,
				desc = "Eval",
				mode = { "n", "v" },
			},
		},
		opts = {},
		config = function(_, opts)
			local dap = require "dap"
			local dapui = require "dapui"
			dapui.setup(opts)
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open {}
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close {}
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close {}
			end
		end,
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			-- virtual text for the debugger
			{
				"theHamsta/nvim-dap-virtual-text",
				opts = {},
			},
		},

  -- stylua: ignore
  keys = {
    { "<leader>bB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
    { "<leader>bb", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>bc", function() require("dap").continue() end, desc = "Run/Continue" },
    { "<leader>ba", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
    { "<leader>bC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
    { "<leader>bg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
    { "<leader>bi", function() require("dap").step_into() end, desc = "Step Into" },
    { "<leader>bj", function() require("dap").down() end, desc = "Down" },
    { "<leader>bk", function() require("dap").up() end, desc = "Up" },
    { "<leader>bl", function() require("dap").run_last() end, desc = "Run Last" },
    { "<leader>bo", function() require("dap").step_out() end, desc = "Step Out" },
    { "<leader>bO", function() require("dap").step_over() end, desc = "Step Over" },
    { "<leader>bP", function() require("dap").pause() end, desc = "Pause" },
    { "<leader>br", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>bs", function() require("dap").session() end, desc = "Session" },
    { "<leader>bt", function() require("dap").terminate() end, desc = "Terminate" },
    { "<leader>bw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
  },

		config = function()
			vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

			local dap_icons = {
				Stopped = { "󰁕 ", "DiagnosticWarn", "DapStoppedLine" },
				Breakpoint = " ",
				BreakpointCondition = " ",
				BreakpointRejected = { " ", "DiagnosticError" },
				LogPoint = ".>",
			}

			for name, sign in pairs(dap_icons) do
				sign = type(sign) == "table" and sign or { sign }
				vim.fn.sign_define("Dap" .. name, { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] })
			end

			-- setup dap config by VsCode launch.json file
			local vscode = require "dap.ext.vscode"
			local json = require "plenary.json"
			vscode.json_decode = function(str)
				return vim.json.decode(json.json_strip_comments(str))
			end
		end,
	},
	{
		"mfussenegger/nvim-dap-python",
		ft = "python",
		dependencies = {
			"mfussenegger/nvim-dap",
			"rcarriga/nvim-dap-ui",
		},
		config = function(_, opts)
			local python_path = vim.fn.system("which python"):gsub("\n", "")
			require("dap-python").setup(python_path)

			require("dap").set_exception_breakpoints { "raised", "uncaught" }
			require("dap").configurations.python[1].justMyCode = false
			require("dap-python").test_runner = "pytest"
			table.insert(require("dap").configurations.python, {
				name = "Run pytest",
				type = "python",
				request = "launch",
				module = "pytest",
				args = {
					".",
					"-v",
				},
				console = "integratedTerminal",
				justMyCode = true,
			})
		end,
	},
}
