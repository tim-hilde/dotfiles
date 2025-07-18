return {
	"ravitemer/mcphub.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
	},
	--cmd = "MCPHub",  -- lazy load
	build = "npm install -g mcp-hub@latest", -- Installs required mcp-hub npm module
	config = function()
		require("mcphub").setup {
			auto_approve = true,
		}
	end,
}
