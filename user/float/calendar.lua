-----------------------------------------------------------------------------------------------------------------------
--                                                 Floating Calendar                                                 --
-----------------------------------------------------------------------------------------------------------------------
-- Modded version of https://github.com/deficient/calendar
-- Using awful.wibox instead of naughty.notify
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local os = os

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local calendar = {}

-- Utility function
-----------------------------------------------------------------------------------------------------------------------
local function format_date(format, date)
	return os.date(format, os.time(date))
end

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		margin       = { 5, 5, 3, 3 },
		timeout      = 1,
		font         = "Sans 12",
		border_width = 2,
		color        = { border = "#404040", text = "#aaaaaa", wibox = "#202020" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "float.calendar") or {})
end

-- Create a new calendar
-----------------------------------------------------------------------------------------------------------------------
function calendar:new(args)
	return setmetatable({}, {__index = self}):init(args)
end

function calendar:init(args, style)
	local style = redutil.table.merge(default_style(), style or {})

	self.num_lines  = 0
	-- first day of week: monday=1, …, sunday=7
	self.fdow          = args.fdow          or 1
	-- notification area:
	self.html          = args.html          or "<span font_desc='monospace'>\n%s</span>"
	-- highlight current date:
	self.today         = args.today         or "<b><span color='" .. style.color.main .. "'>%2i</span></b>"
	self.anyday        = args.anyday        or "%2i"
	self.page_title    = args.page_title    or "%B %Y"    -- month year
	self.col_title     = args.col_title     or "%a "      -- weekday
	-- Date equality check is based on day_id. We deliberately ignore the year
	-- to highlight the same day in different years:
	self.day_id        = args.day_id        or "%m-%d"
	self.empty_sep     = args.empty_sep     or "   -"
	self.week_head     = args.week_head     or "   "
	self.week_col      = args.week_col      or " %V"
	self.days_style    = args.days_style    or {}
	self.position      = args.position      or "bottom_right"
	self.corner_offset = args.corner_offset or { x = -2 * style.border_width, y = -2 * style.border_width }

	-- Construct calendar window with wibox and textbox
	--------------------------------------------------------------------------------
	local cal = { wibox = wibox({ type = "tooltip" }) }
	local tb = wibox.widget.textbox()
	cal.widget = tb
	cal.wibox:set_widget(wibox.container.margin(tb, unpack(style.margin)))
	tb:set_font(style.font)

	-- configure wibox properties
	cal.wibox.visible = false
	cal.wibox.ontop = true
	cal.wibox.border_width = style.border_width
	cal.wibox.border_color = style.color.border
	cal.wibox:set_bg(style.color.wibox)
	cal.wibox:set_fg(style.color.text)

	-- configure buttons
	cal.wibox:buttons(awful.util.table.join(
		awful.button({         }, 1, function() self:hide()      end),
		awful.button({         }, 3, function() self:show()      end),
		awful.button({         }, 4, function() self:switch( -1) end),
		awful.button({         }, 5, function() self:switch(  1) end),
		awful.button({ "Shift" }, 4, function() self:switch(-12) end),
		awful.button({ "Shift" }, 5, function() self:switch( 12) end)
	))

	function cal:set_geometry()
		local geom = self.wibox:geometry()
		local n_w, n_h = self.widget:get_preferred_size()
		if geom.width ~= n_w or geom.height ~= n_h then
			self.wibox:geometry({
				width = n_w + style.margin[1] + style.margin[2],
				height = n_h + style.margin[3] + style.margin[4]
			})
		end
	end

	function cal:set_text(text)
		self.widget:set_markup(text)
		self:set_geometry()
	end

	self.cal = cal

	-- Auto-hide timer
	--------------------------------------------------------------------------------
	self.hide_timer = timer({ timeout = style.timeout })
	self.hide_timer:connect_signal("timeout",
		function()
			self:hide()
			self.hide_timer:stop()
		end)

	self:set_timer_signals(cal.wibox)

	return self
end

-- Enable auto-hide timer on widget
-----------------------------------------------------------------------------------------------------------------------
function calendar:set_timer_signals(object)
	object:connect_signal("mouse::enter", function() if self.hide_timer.started then self.hide_timer:stop() end end)
	object:connect_signal("mouse::leave", function() if not self.hide_timer.started then self.hide_timer:start() end end)
end

function calendar:day_style(day_of_week)
	return self.days_style[day_of_week] or "%s"
end

function calendar:page(month, year)

	local today = format_date(self.day_id)

	-- 2001 started with a monday:
	local d0 = format_date("*t", {year=2001, month=1,       day=self.fdow })
	local dA = format_date("*t", {year=year, month=month,   day=1         })
	local dB = format_date("*t", {year=year, month=month+1, day=0         })
	local tA =                   {year=year, month=month,   day=1         }
	local colA = (dA.wday - d0.wday) % 7

	local page_title = format_date(self.page_title, tA)

	-- print column titles (weekday)
	local page = " " .. self.week_head
	for d = 0, 6 do
		page = page .. self:day_style(d+1):format(format_date(self.col_title, {
			year  = d0.year,
			month = d0.month,
			day   = d0.day + d,
		}))
	end

	-- print empty space before first day
	page = page .. "\n" .. format_date(self.week_col, tA)
	for column = 1, colA do
		page = page .. self.empty_sep
	end

	-- iterate all days of the month
	local nLines = 1
	local column = colA
	for day = 1, dB.day do
		if column == 7 then
			column = 0
			nLines = nLines + 1
			page = page .. "\n" .. format_date(self.week_col, {year=year, month=month, day=day})
		end
		if today == format_date(self.day_id, {day=day, month=month, year=year}) then
			page = page .. "  " .. self.today:format(day)
		else
			page = page .. "  " .. self:day_style(column+1):format(self.anyday:format(day))
		end
		column = column + 1
	end

	for column = column, 6 do
		page = page .. self.empty_sep
	end

	return page_title, self.html:format(page)
end

-- Change calendar page
-----------------------------------------------------------------------------------------------------------------------
function calendar:switch(months)
	self:show(self.year, self.month+months)
end

-- Show calendar
-----------------------------------------------------------------------------------------------------------------------
function calendar:show(year, month)
	local today = os.time()
	self.month  = month or os.date("%m", today)
	self.year   = year  or os.date("%Y", today)
	local title, text = self:page(self.month, self.year)

	self.cal:set_text(title .. "\n" .. text)
	awful.placement[self.position](self.cal.wibox)
	awful.placement.no_offscreen(self.cal.wibox)
	self.cal.wibox.x = self.cal.wibox.x + self.corner_offset.x
	self.cal.wibox.y = self.cal.wibox.y + self.corner_offset.y
	self.cal.wibox.visible = true
end

-- Hide calendar
-----------------------------------------------------------------------------------------------------------------------
function calendar:hide()
	self.cal.wibox.visible = false
end

-- Toggle calendar visibility
-----------------------------------------------------------------------------------------------------------------------
function calendar:toggle()
	if self.cal.wibox.visible then
		self:hide()
	else
		self:show()
	end
end

-- Attach calendar to existing widget
-----------------------------------------------------------------------------------------------------------------------
function calendar:attach(widget)
	widget:buttons(awful.util.table.join(
		awful.button({         }, 1, function() self:toggle()    end),
		awful.button({         }, 3, function() self:show()      end),
		awful.button({         }, 4, function() self:switch( -1) end),
		awful.button({         }, 5, function() self:switch(  1) end),
		awful.button({ "Shift" }, 4, function() self:switch(-12) end),
		awful.button({ "Shift" }, 5, function() self:switch( 12) end)
	))

	self:set_timer_signals(widget)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return setmetatable(calendar, {
	__call = calendar.new,
})
