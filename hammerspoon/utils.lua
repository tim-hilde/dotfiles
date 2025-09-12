local utils = {}

function utils.notify(msg)
	hs.notify.show("Hammerspoon", "", msg)
end

return utils
