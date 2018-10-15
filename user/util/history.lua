local awful = require("awful")

local hist = {}

function hist.previous()
	local s = awful.screen.focused()
	local curr_tag = s.selected_tag
	-- failsafe
	local stop = 5
	repeat
		awful.tag.history.restore(s, 1)
		stop = stop - 1
	until ((s.selected_tag ~= curr_tag and s.selected_tag.name ~= "TG") or stop <= 0)
	-- switch twice to reinsert tags into history
	local new_tag = s.selected_tag
	curr_tag:view_only()
	new_tag:view_only()
end

return hist