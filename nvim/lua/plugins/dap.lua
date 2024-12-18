return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		config = function()
			local dap = require "dap"
			local dapui = require "dapui"
			dapui.setup()
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},
	{
		"mfussenegger/nvim-dap",
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
			})
		end,
	},
}
