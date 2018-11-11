local awful = require("awful")

local hist = {}

function hist.previous()
	local s = awful.screen.focused()
	local curr_tag = s.selected_tag
	-- failsafe
	local stop = 10
	repeat
		awful.tag.history.restore(s, 1)
		stop = stop - 1
	until ((s.selected_tag ~= curr_tag and not s.selected_tag.non_numeric) or stop <= 0)
	-- switch twice to reinsert tags into history
	local new_tag = s.selected_tag
	curr_tag:view_only()
	new_tag:view_only()
end

function hist.non_empty()
	local s = awful.screen.focused()
	local curr_tag = s.selected_tag
	-- failsafe
	local stop = 10
	repeat
		awful.tag.history.restore(s, 1)
		stop = stop - 1
	until ((s.selected_tag ~= curr_tag and not s.selected_tag.non_numeric
	      and (#s.selected_tag:clients() > 0 or s.selected_tag.always_show))
	      or stop <= 0)
	-- switch twice to reinsert tags into history
	local new_tag = s.selected_tag
	curr_tag:view_only()
	new_tag:view_only()
end

return hist