return {
	{
		"sotte/presenting.nvim",
		opts = {
			-- fill in your options here
			-- see :help Presenting.config
		},
		cmd = { "Presenting" },
	},

	{
		"ducks/vimdeck.nvim",
		cmd = { "Vimdeck", "VimdeckFile" },
		opts = {
			use_figlet = false,
			center_slides = false,
		},
	},
}
