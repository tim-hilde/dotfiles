return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",
	opts = {
		options = {
			indicator = {
				style = "underline",
			},
			offsets = {
				{
					filetype = "neo-tree",
					text = "File Explorer",
					text_align = "left",
				},
			},
			diagnostics = "nvim_lsp",
			diagnostics_indicator = function(count, level, diagnostics_dict, context)
				local s = " "
				for e, n in pairs(diagnostics_dict) do
					local sym = e == "error" and " " or (e == "warning" and " " or " ")
					s = s .. n .. sym
				end
				return s
			end,
		},
	},
	config = function(_, opts)
		vim.opt.termguicolors = true
		require("bufferline").setup(opts)
	end,
}
