return {
	"johmsalas/text-case.nvim",
	opts = {
		default_keymappings_enabled = true,
		-- `prefix` is only considered if `default_keymappings_enabled` is true. It configures the prefix
		-- of the keymappings, e.g. `gau ` executes the `current_word` method with `to_upper_case`
		-- and `gaou` executes the `operator` method with `to_upper_case`.
		prefix = "g.",
	},
}
