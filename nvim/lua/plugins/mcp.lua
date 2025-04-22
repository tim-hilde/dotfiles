return {
	"ravitemer/mcphub.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	cmd = "MCPHub",
	build = "npm install -g mcp-hub@latest",
	config = function()
		require("mcphub").setup()
	end,
}
