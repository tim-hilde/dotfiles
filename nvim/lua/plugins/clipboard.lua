return {
	"AckslD/nvim-neoclip.lua",
	dependencies = {
		{ "nvim-telescope/telescope.nvim", "kkharji/sqlite.lua" },
	},
	config = function()
		local function is_whitespace(line)
			return vim.fn.match(line, [[^\s*$]]) ~= -1
		end

		local function all(tbl, check)
			for _, entry in ipairs(tbl) do
				if not check(entry) then
					return false
				end
			end
			return true
		end

		local opts = {
			enable_persistent_history = true,
			continuous_sync = true,
			default_register = "*",
			dedent_picker_display = true,
			filter = function(data)
				return not all(data.event.regcontents, is_whitespace)
			end,
		}

		require("neoclip").setup(opts)
	end,
}
