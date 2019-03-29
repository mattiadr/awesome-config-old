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
		icon        = redutil.base.placeholder(),
		firstrun    = false,
		-- interval    = 60, TODO
		-- timeout     = 5,
		color       = { main = "#b1222b", icon = "#a0a0a0" }
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
	local spawn_cmd = [[%s -e sh -c "echo '%s'; %s; echo 'Done!'; read"]]

	local style = redutil.table.merge(default_style(), style or {})

	object.widget = svgbox(style.icon)
	object.widget:set_color(style.color.icon)
	table.insert(upgrades.objects, object)

	-- Set tooltip
	--------------------------------------------------------------------------------
	object.tp = tooltip({ objects =  { object.widget } }, style.tooltip)

	-- Update info function
	--------------------------------------------------------------------------------
	local function update_count(pm, stdout, stderr, _, exitcode)
		local c = string.match(stdout, "(%d+)")
		pm.count = tonumber(c) or 0
		local total = 0
		local tt_text = nil

		for _, pm in ipairs(pacmans) do
			total = total + pm.count
			tt_text = (tt_text and tt_text .. "\n" or "") .. pm.name .. ": " .. pm.count .. " updates"
		end

		object.tp:set_text(tt_text)
		object.widget:set_color(total > 0 and style.color.main or style.color.icon)
	end

	function object.update_all()
		object.tp:set_text("Checking updates...")
		for _, pm in ipairs(pacmans) do
			awful.spawn.easy_async_with_shell(pm.check, function (...) update_count(pm, ...) end)
		end
	end

	-- Spawn terminal for updates
	--------------------------------------------------------------------------------
	function object.do_update()
		for _, pm in ipairs(pacmans) do
			if pm.count > 0 then
				awful.spawn.with_line_callback(string.format(spawn_cmd, terminal, pm.upgrade, pm.upgrade), {
					exit = object.update_all
				})
				return
			end
		end
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	local t = timer({ timeout = update_timeout })
	t:connect_signal("timeout", object.update_all)
	t:start()

	if true then t:emit_signal("timeout") end

	-- Set buttons
	--------------------------------------------------------------------------------
	object.widget:buttons(awful.util.table.join(
		awful.button({ }, 1, object.do_update),
		awful.button({ }, 3, object.update_all)
	))

	--------------------------------------------------------------------------------
	return object.widget
end

-- Update upgrades info for every widget
-----------------------------------------------------------------------------------------------------------------------
function upgrades:update(is_force)
	for _, o in ipairs(upgrades.objects) do o.update({ is_force = is_force }) end
end

-- Config metatable to call upgrades module as function
-----------------------------------------------------------------------------------------------------------------------
function upgrades.mt:__call(...)
	return upgrades.new(...)
end

return setmetatable(upgrades, upgrades.mt)
