-----------------------------------------------------------------------------------------------------------------------
--                                                Signals config                                                     --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local beautiful = require("beautiful")

local hist = require("user/util/history")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local signals = {}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function do_sloppy_focus(c)
	if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) then
		client.focus = c
	end
end

local function fixed_maximized_geometry(c, context)
	if c.maximized and context ~= "fullscreen" then
		c:geometry({
			x = c.screen.workarea.x,
			y = c.screen.workarea.y,
			height = c.screen.workarea.height - 2 * c.border_width,
			width = c.screen.workarea.width - 2 * c.border_width,
		})
	end
end

-- Build  table
-----------------------------------------------------------------------------------------------------------------------
function signals:init(args)

	local args = args or {}
	local env = args.env

	-- actions on every application start
	client.connect_signal(
		"manage",
		function(c)
			-- put client at the end of list
			if env.set_slave then awful.client.setslave(c) end

			-- startup placement
			if awesome.startup
				and not c.size_hints.user_position
				and not c.size_hints.program_position
			then
				awful.placement.no_offscreen(c)
			end
		end
	)

	-- don't allow maximized windows move/resize themselves
	client.connect_signal("request::geometry", fixed_maximized_geometry)

	-- enable sloppy focus, so that focus follows mouse
	if env.sloppy_focus then
		client.connect_signal("mouse::enter", do_sloppy_focus)
	end

	-- hilight border of focused window
	-- can be disabled since focus indicated by titlebars in current config
	if env.color_border_focus then
		client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus  end)
		client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
	end

	-- if the client occupies all the workarea then remove borders, else add them
	client.connect_signal("property::size", function(c)
		local wa = c.screen.workarea
		if c.border_width > 0 then
			if c.width == wa.width - 2 * c.border_width and c.height == wa.height - 2 * c.border_width then
				c.width = c.width + 2 * c.border_width
				c.height = c.height + 2 * c.border_width
				c.border_width = 0
			end
		else
			if c.width < wa.width - 2 * c.border_width or c.height < wa.height - 2 * c.border_width then
				c.border_width = beautiful.border_width
				c.width = c.width - 2 * c.border_width
				c.height = c.height - 2 * c.border_width
			end
		end
	end)

	-- wallpaper update on screen geometry change
	screen.connect_signal("property::geometry", env.wallpaper)

	-- Awesome v4.0 introduce screen handling without restart.
	-- Since I'm using single monitor setup and I'm too lazy to rework my panel widgets for this new feature,
	-- simple adding signal to restart wm on new monitor pluging.
	-- For reference, screen-dependent widgets are
	-- redflat.widget.layoutbox, redflat.widget.taglist, redflat.widget.tasklist
	screen.connect_signal("list", awesome.restart)

	-- bring urgent to front, first two are ignored to avoid switching to telegram at startup
	local ignore = 2
	tag.connect_signal("property::urgent", function(t)
		if ignore > 0 then
			ignore = ignore - 1
		else
			t:view_only()
		end
	end)

	-- fix geometry not refreshed when untagged
	-- tag.connect_signal("untagged", function(t)
	-- 	t:emit_signal("tagged")
	-- end)

	-- set opened_by property
	tag.connect_signal("tagged", function(new_tag)
		local curr_tag = awful.screen.focused().selected_tag

		if new_tag ~= curr_tag then
			new_tag.opened_by = curr_tag
		end
	end)

	-- return to opened_by tag when current is empty
	tag.connect_signal("untagged", function(tag)
		-- find previous non empty tag
		-- tag                   -> needs to be non nil
		-- tag ~= tag.opened_by  -> avoid infinite loops
		-- tag.non_numeric       -> tag must be numeric
		-- #tag:clients() == 0   -> tag must be non empty
		-- not tag.always_show   -> except for always_show tags
		while tag and tag ~= tag.opened_by and (tag.non_numeric or (#tag:clients() == 0 and not tag.always_show)) do
			tag = tag.opened_by
		end

		-- switch to tag and reset opened_by
		if tag then
			tag:view_only()
		end
	end)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return signals
