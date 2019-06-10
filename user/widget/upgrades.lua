-----------------------------------------------------------------------------------------------------------------------
--                                                  Upgrades widget                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- Show if system updates are available
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local table = table
local string = string

local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local timer = require("gears.timer")

local tooltip = require("redflat.float.tooltip")
local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local upgrades = { objects = {}, mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		firstrun    = false,
		retry       = 0,
		retry_delay = 5,
		icon        = redutil.base.placeholder(),
		color       = { main = "#b1222b", icon = "#a0a0a0" },
		notify      = { preset = naughty.config.presets.normal, title = "Upgrades" },
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.upgrades") or {})
end

-- Create a new upgrades widget
-----------------------------------------------------------------------------------------------------------------------
function upgrades.new(pacmans, args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local object = {}
	local pacmans = pacmans or {}
	local args = args or {}
	local terminal = args.terminal or nil
	local update_timeout = args.update_timeout or 3600
	local spawn_cmd = [[%s -e sh -c "echo '%s'; %s"]]

	local style = redutil.table.merge(default_style(), style or {})

	object.widget = svgbox(style.icon)
	object.widget:set_color(style.color.icon)
	table.insert(upgrades.objects, object)

	-- Set tooltip
	--------------------------------------------------------------------------------
	object.tt = tooltip({ objects =  { object.widget } }, style.tooltip)

	-- Set notify
	--------------------------------------------------------------------------------
	object.notify = style.notify

	-- Update tooltip and icon color
	--------------------------------------------------------------------------------
	function object.update_widget(show_notify)
		local total = 0
		local tt_text = nil

		for _, pm in ipairs(pacmans) do
			total = total + (pm.count or 0)
			tt_text = (tt_text and tt_text .. "\n" or "") .. pm.name .. ": " .. (pm.text or "Not checked yet")
		end

		object.widget:set_color(total > 0 and style.color.main or style.color.icon)
		object.tt:set_text(tt_text)

		if show_notify and total > 0 then
			naughty.notify(
				redutil.table.merge({
					text = tt_text,
					run = function(n) object.do_upgrade(); n.die(naughty.notificationClosedReason.dismissedByUser) end
				}, object.notify)
			)
		end
	end

	-- Callback to check exit code and output
	--------------------------------------------------------------------------------
	local function check_callback(pm, stdout, stderr, _, exitcode)
		if exitcode == 0 then
			local c = string.match(stdout, "(%d+)")
			pm.count = tonumber(c)
			pm.text = c .. " updates"
		else
			pm.text = "Error!"
		end

		object.update_widget(args.show_notify and exitcode == 0)

		pm.try = pm.try or 0
		if exitcode ~= 0 and pm.try < style.retry then
			pm.try = pm.try + 1
			timer.start_new(style.retry_delay, function() object.check_pm(pm) end)
		end
	end

	-- Check a single packet manager for updates
	--------------------------------------------------------------------------------
	function object.check_pm(pm)
		pm.text = "Checking..."
		object.update_widget(false)
		awful.spawn.easy_async_with_shell(pm.check, function (...) check_callback(pm, ...) end)
	end

	-- Check all packet managers for updates
	--------------------------------------------------------------------------------
	function object.check_all()
		for _, pm in ipairs(pacmans) do
			object.check_pm(pm)
		end
	end

	-- Spawn terminal for updates
	--------------------------------------------------------------------------------
	function object.do_upgrade()
		for _, pm in ipairs(pacmans) do
			if pm.count and pm.count >= 0 then
				pm.text = "Upgrading..."
				object.update_widget(false)
				awful.spawn.with_line_callback(string.format(spawn_cmd, terminal, pm.upgrade, pm.upgrade), {
					exit = object.check_all
				})
				return
			end
		end
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	local t = timer({ timeout = update_timeout })
	t:connect_signal("timeout", object.check_all)
	t:start()

	if style.firstrun then
		t:emit_signal("timeout")
	else
		object.update_widget(false)
	end

	-- Set buttons
	--------------------------------------------------------------------------------
	object.widget:buttons(awful.util.table.join(
		awful.button({ }, 1, object.do_upgrade),
		awful.button({ }, 3, object.check_all)
	))

	--------------------------------------------------------------------------------
	return object.widget
end

-- Config metatable to call upgrades module as function
-----------------------------------------------------------------------------------------------------------------------
function upgrades.mt:__call(...)
	return upgrades.new(...)
end

return setmetatable(upgrades, upgrades.mt)
