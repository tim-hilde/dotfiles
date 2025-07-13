return {
	"tamton-aquib/duck.nvim",
	config = function()
		-- Track duck state
		local duck_active = false

		-- Toggle function
		local function toggle_duck()
			if duck_active then
				require("duck").cook_all()
				duck_active = false
			else
				require("duck").hatch("🦆", 5)
				duck_active = true
			end
		end

		-- Create user command
		vim.api.nvim_create_user_command("Duck", toggle_duck, {})
	end,
}
