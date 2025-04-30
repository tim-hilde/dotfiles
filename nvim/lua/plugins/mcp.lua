return {
	"ravitemer/mcphub.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	-- cmd = "MCPHub",
	build = "npm install -g mcp-hub@latest",
	opts = {
		auto_approve = true,
	},
}
