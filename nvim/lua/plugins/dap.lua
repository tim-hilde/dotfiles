return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		config = true,
		-- require("dapui").toggle()
		-- Setting breakpoints via :lua require'dap'.toggle_breakpoint().
		-- Launching debug sessions and resuming execution via :lua require'dap'.continue().
		-- Stepping through code via :lua require'dap'.step_over() and :lua require'dap'.step_into().
		-- Inspecting the state via the built-in REPL: :lua require'dap'.repl.open() or using the widget UI (:help dap-widgets)
	},
	{
		"mfussenegger/nvim-dap-python",
		config = function()
			local python_path = vim.fn.system("which python"):gsub("\n", "")
			local dap = require "dap-python"
			dap.setup(python_path)
		end,
	},
}
