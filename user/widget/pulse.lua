-----------------------------------------------------------------------------------------------------------------------
--                                   RedFlat pulseaudio volume control widget                                        --
-----------------------------------------------------------------------------------------------------------------------
-- Indicate and change volume level using pacmd
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local io = io
local math = math
local table = table
local tonumber = tonumber
local tostring = tostring
local string = string
local setmetatable = setmetatable
local wibox = require("wibox")
local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")
local timer = require("gears.timer")

local tooltip = require("redflat.float.tooltip")
local audio = require("redflat.gauge.audio.blue")
local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")
local redmenu = require("redflat.menu")


-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local pulse = { widgets = {}, mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		retry      = 0,
		notify     = {},
		widget     = audio.new,
		audio      = {},
		check_icon = redutil.base.placeholder(),
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.pulse") or {})
end

local change_volume_default_args = {
	down        = false,
	step        = 655 * 5,
	show_notify = false
}

-- Change default and active sink
-----------------------------------------------------------------------------------------------------------------------
local function set_sink(name, notify)
	awful.spawn("pacmd set-default-sink " .. name)

	for i in redutil.read.output("pacmd list-sink-inputs | grep -Po '(?<=index: )\\d+'"):gmatch("[^\n]+") do
		awful.spawn("pacmd move-sink-input " .. tostring(i) .. " " .. name)
	end

	pulse:update_volume()

	if notify then
		naughty.notify({ text = "Activated " .. pulse.sink_names[name], preset = naughty.config.presets.low })
	end
end

-- Show menu to change sink
-----------------------------------------------------------------------------------------------------------------------
function pulse:choose_sink()

	-- if menu is alredy open, close and exit
	if pulse.sink_selector.wibox.visible then
		pulse.sink_selector:hide()
		return
	end

	-- menu items
	local items = {}

	-- icon finder
	local function micon(name)
		return redflat.service.dfparser.lookup_icon(name, {})
	end

	-- get sink names
	local def_sink = redutil.read.output("pacmd dump | perl -ane 'print $F[1] if /set-default-sink/'")
	for s in redutil.read.output("pacmd list-sinks | grep -Po '(?<=name: <)\\S+(?=>)'"):gmatch("[^\n]+") do
		table.insert(items, {
			pulse.sink_names[s] or s,
			function() set_sink(s) end,
			(def_sink == s) and pulse.check_icon or redutil.base.placeholder({ txt = " " }),
		})
	end

	-- update and spawn menu
	pulse.sink_selector:replace_items(items)
	pulse.sink_selector:show()

end

-- Activate next or prev sink
-----------------------------------------------------------------------------------------------------------------------
function pulse:cycle_sink(prev)

	-- get default sink names
	local def_sink = redutil.read.output("pacmd dump | perl -ane 'print $F[1] if /set-default-sink/'")
	-- get available sinks
	local i = 0
	local index = 0
	local sinks = {}
	for s in redutil.read.output("pacmd list-sinks | grep -Po '(?<=name: <)\\S+(?=>)'"):gmatch("[^\n]+") do
		sinks[i] = s
		if s == def_sink then
			index = i
		end
		i = i + 1
	end
	-- switch to next or prev sink
	index = (index + (prev and -1 or 1)) % i
	set_sink(sinks[index], true)

end

-- Change volume level
-----------------------------------------------------------------------------------------------------------------------
function pulse:change_volume(args)

	-- initialize vars
	local args = redutil.table.merge(change_volume_default_args, args or {})
	local diff = args.down and -args.step or args.step

	-- get current sink
	local sink = redutil.read.output("pacmd dump | perl -ane 'print $F[1] if /set-default-sink/'")

	-- get current volume
	local v = redutil.read.output("pacmd dump | grep set-sink-volume | grep " .. sink )
	local volume = tonumber(string.match(v, "0x%x+"))

	-- calculate new volume
	local new_volume = volume + diff

	if new_volume > 65536 then
		new_volume = 65536
	elseif new_volume < 0 then
		new_volume = 0
	end

	-- show notify if need
	if args.show_notify then
		local vol = new_volume / 65536
		rednotify:show(
			redutil.table.merge({ value = vol, text = string.format('%.0f', vol*100) .. "%" }, pulse.notify)
		)
	end

	-- set new volume
	awful.spawn("pacmd set-sink-volume " .. sink .. " " .. new_volume)
	-- update volume indicators
	self:update_volume()
end

-- Set mute
-----------------------------------------------------------------------------------------------------------------------
function pulse:mute(forced)

	-- get current sink
	local sink = redutil.read.output("pacmd dump | perl -ane 'print $F[1] if /set-default-sink/'")

	-- get current mute state
	local mute = redutil.read.output("pacmd dump | grep set-sink-mute | grep " .. sink)

	if forced ~= nil then
		b = forced
	else
		b = string.find(mute, "no", -4)
	end

	if b then
		awful.spawn("pacmd set-sink-mute " .. sink .. " yes")
	else
		awful.spawn("pacmd set-sink-mute " .. sink .. " no")
	end
	self:update_volume()
end

-- Update volume level info
-----------------------------------------------------------------------------------------------------------------------
function pulse:update_volume()

	-- initialize vars
	local volmax = 65536
	local volume = 0
	local mute

	-- get current sink
	local sink = redutil.read.output("pacmd dump | perl -ane 'print $F[1] if /set-default-sink/'")

	-- retry if no default sink is detected
	if sink == "" then
		if pulse.retry and pulse.retry > 0 then
			timer.start_new(1, function() pulse:update_volume() end)
		end
		return
	end

	-- get current volume and mute state
	local v = redutil.read.output("pacmd dump | grep set-sink-volume | grep " .. sink)
	local m = redutil.read.output("pacmd dump | grep set-sink-mute | grep " .. sink)

	if v then
		local pv = string.match(v, "0x%x+")
		if pv then volume = math.ceil(tonumber(pv) * 100 / volmax) end
	end

	if m ~= nil and string.find(m, "no", -4) then
		mute = false
	else
		mute = true
	end

	-- update tooltip
	self.tooltip:set_text(volume .. "%")

	-- update widgets value
	for _, w in ipairs(pulse.widgets) do
		w:set_value(volume / 100)
		w:set_mute(mute)
	end
end

-- Create a new pulse widget
-- @param timeout Update interval
-----------------------------------------------------------------------------------------------------------------------
function pulse.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = redutil.table.merge(default_style(), style or {})
	pulse.notify = style.notify
	pulse.retry = style.retry

	local args = args or {}
	local timeout = args.timeout or 5
	local autoupdate = args.autoupdate or false
	local menu_theme = args.menu_theme or { auto_hotkey = true }

	pulse.sink_names = args.sink_names or {}
	pulse.check_icon = style.check_icon

	-- create widget
	--------------------------------------------------------------------------------
	widg = style.widget(style.audio)
	table.insert(pulse.widgets, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	if not pulse.tooltip then
		pulse.tooltip = tooltip({ objects = { widg } }, style.tooltip)
	else
		pulse.tooltip:add_to_object(widg)
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	if autoupdate then
		local t = timer({ timeout = timeout })
		t:connect_signal("timeout", function() pulse:update_volume() end)
		t:start()
	end

	-- Create menu
	if not pulse.sink_selector then
		pulse.sink_selector = redmenu({ theme = theme, items = {} })
	end

	--------------------------------------------------------------------------------
	pulse:update_volume()
	return widg
end

-- Config metatable to call pulse module as function
-----------------------------------------------------------------------------------------------------------------------
function pulse.mt:__call(...)
	return pulse.new(...)
end

return setmetatable(pulse, pulse.mt)
