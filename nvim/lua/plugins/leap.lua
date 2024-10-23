return {
	"ggandor/leap.nvim",
	config = function()
		vim.api.nvim_set_hl(0, "LeapBackdrop", { link = "Comment" }) -- or some grey
		vim.api.nvim_set_hl(0, "LeapMatch", {
			-- For light themes, set to 'black' or similar.
			fg = "white",
			bold = true,
			nocombine = true,
		})
	end,
}
