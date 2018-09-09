------------------------------------------------------------------------------------------------------------------------
--                                             Cheatsheet selector widget                                             --
------------------------------------------------------------------------------------------------------------------------
-- Widget with cheatsheet list and quick search
-- Inspired from redflat.float.apprunner
------------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local io = io
local math = math

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")

local redutil = require("redflat.util")
local decoration = require("redflat.float.decoration")

local cs_viewer = require("user/float/cheatsheet-viewer")
local printn = require("user/util/print").n

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local cs_selector = { list = {}, keys = {} }

local cheatsheets = {}
local lastquery = nil

-- key bindings
cs_selector.keys.move = {
	{
		{ }, "Down", function() cs_selector:down() end,
		{ description = "Select next item", group = "Navigation" }
	},
	{
		{ }, "Up", function() cs_selector:up() end,
		{ description = "Select previous item", group = "Navigation" }
	},
}

cs_selector.keys.action = {
	{
		{ "Mod4" }, "F1", function() redtip:show() end,
		{ description = "Show hotkeys helper", group = "Action" }
	},
}

cs_selector.keys.all = awful.util.table.join(cs_selector.keys.move, cs_selector.keys.action)

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		location         = "",
		itemnum          = 5,
		geometry         = { width = 620, height = 520 },
		border_margin    = { 10, 10, 10, 10 },
		title_height     = 48,
		prompt_height    = 35,
		name_font        = "Sans 12",
		name_margin      = { 4, 4, 4, 4 },
		border_width     = 2,
		color            = { border = "#575757", text = "#aaaaaa", highlight = "#eeeeee", main = "#b1222b",
		                     bg = "#161616", bg_second = "#181818", wibox = "#202020", icon = "a0a0a0" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "float.cheatsheet_selector") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Fuction to convert an iterator to a table
--------------------------------------------------------------------------------
local function iter_to_table(iterator)
	local t = {}
	for e in iterator do
		table.insert(t, e)
	end
	return t
end

-- Fuction to parse file to cheatsheet
--------------------------------------------------------------------------------
local function parse_file(filename)
	local cs = {}

	for line in io.lines(filename) do
		if line:match("%S") then
			-- line is not empty
			if not cs.name then
				-- first line of file is filename
				cs.name = line
			else
				if line:sub(1, 1) == "#" then
					-- create new group
					table.insert(cs, { group = line:sub(2) })
				else
					-- insert cmd + description into last group
					line = iter_to_table(line:gmatch("[^\t]+"))
					table.insert(cs[#cs], { cmd = line[1], description = line[2] })
				end
			end
		end
	end

	return cs
end

-- Fuction to parse all files in dir to cheatsheets
--------------------------------------------------------------------------------
local function parse_all_files(directory)
	local css = {}

	if gears.filesystem.dir_readable(directory) then
		for file in io.popen('find "' .. directory .. '" -type f'):lines() do
			table.insert(css, parse_file(file))
		end
	end

	return css
end

-- Fuction to build list item
--------------------------------------------------------------------------------
local function construct_item(style)
	local item = {
		name = wibox.widget.textbox(),
		bg   = style.color.bg,
		cs   = nil,
	}

	item.name:set_font(style.name_font)

	-- Construct item layouts
	------------------------------------------------------------
	--wibox.container.margin
	item.layout = wibox.container.background(
		wibox.container.margin(item.name, unpack(style.name_margin)),
	item.bg)

	-- Item methods
	------------------------------------------------------------
	function item:set(cs)
		local cs = cs or {}

		local name_text = awful.util.escape(cs.name) or ""
		self.name:set_markup(name_text)

		self.cs = cs
	end

	function item:set_bg(color)
		self.bg = color
		self.layout:set_bg(color)
	end

	function item:set_select()
		self.layout:set_bg(style.color.main)
		self.layout:set_fg(style.color.highlight)
	end

	function item:set_unselect()
		self.layout:set_bg(self.bg)
		self.layout:set_fg(style.color.text)
	end

	function item:open()
		if self.cs then
			cs_viewer:show(self.cs)
		end
	end

	------------------------------------------------------------
	return item
end

-- Fuction to build application list
--------------------------------------------------------------------------------
local function construct_list(num, css, style)
	local list = { selected = 1, position = 1, items = {} }

	-- Construct application list
	------------------------------------------------------------
	local list_layout = wibox.layout.flex.vertical()
	list.layout = wibox.container.background(list_layout, style.color.bg)

	for i = 1, num do
		list.items[i] = construct_item(style)
		list.items[i]:set_bg((i % 2) == 1 and style.color.bg or style.color.bg_second)
		list_layout:add(list.items[i].layout)
	end

	-- Application list functions
	------------------------------------------------------------
	function list:set_select(index)
		self.items[self.selected]:set_unselect()
		self.selected = index
		self.items[self.selected]:set_select()
	end

	function list:update(t)
		for i = self.position, (self.position - 1 + num) do
			self.items[i - self.position + 1]:set(t[i])
		end
		self:set_select(self.selected)
	end

	-- First run actions
	------------------------------------------------------------
	list:update(css)
	list:set_select(1)

	------------------------------------------------------------
	return list
end

-- Sort function
--------------------------------------------------------------------------------
local function sort_by_query(t, query)
	l = query:len()

	local function starts(e)
		return e.name:sub(1, l):lower() == query
	end

	local function s(a, b)
		local r = starts(a)
		if r == starts(b) then
			return a.name:lower() < b.name:lower()
		else
			return r
		end
	end

	table.sort(t, s)
end

-- Function to filter application list by quick search input
--------------------------------------------------------------------------------
local function list_filtrate(query)
	if lastquery ~= query then
		cheatsheets.current = {}

		for i, c in ipairs(cheatsheets.all) do
			if c.name:lower():match(query) then
				table.insert(cheatsheets.current, c)
			end
		end

		sort_by_query(cheatsheets.current, query)

		cs_selector.list.position = 1
		cs_selector.list:update(cheatsheets.current)
		cs_selector.list:set_select(1)
		lastquery = query
	end
end

-- Functions to navigate through application list
-----------------------------------------------------------------------------------------------------------------------
function cs_selector:down()
	if self.list.selected < math.min(self.itemnum, #cheatsheets.current) then
		self.list:set_select(self.list.selected + 1)
	elseif self.list.selected + self.list.position - 1 < #cheatsheets.current then
		self.list.position = self.list.position + 1
		self.applist:update(cheatsheets.current)
	end
end

function cs_selector:up()
	if self.list.selected > 1 then
		self.list:set_select(self.list.selected - 1)
	elseif self.list.position > 1 then
		self.list.position = self.list.position - 1
		self.list:update(cheatsheets.current)
	end
end

-- Keypress handler
-----------------------------------------------------------------------------------------------------------------------
local function keypressed_callback(mod, key, comm)
	for _, k in ipairs(cs_selector.keys.all) do
		if redutil.key.match_prompt(k, mod, key) then k[3](); return true end
	end
	return false
end

-- Initialize apprunner widget
-----------------------------------------------------------------------------------------------------------------------
function cs_selector:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = default_style()
	self.itemnum = style.itemnum
	
	-- get full cheatsheet list
	cheatsheets.all = parse_all_files(style.location)
	cheatsheets.current = awful.util.table.clone(cheatsheets.all)

	-- Create quick search widget
	--------------------------------------------------------------------------------
	self.textbox = wibox.widget.textbox()
	self.textbox:set_ellipsize("start")
	self.decorated_widget = decoration.textfield(self.textbox, style.field)

	-- Build cheatsheet list
	--------------------------------------------------------------------------------
	self.list = construct_list(self.itemnum, cheatsheets.current, style)

	-- Construct widget layouts
	--------------------------------------------------------------------------------
	local prompt_width = style.geometry.width - 2 * style.border_margin[1] - style.title_height
	local prompt_layout = wibox.container.constraint(self.decorated_widget, "exact", prompt_width, style.prompt_height)

	local prompt_vertical = wibox.layout.align.vertical()
	prompt_vertical:set_expand("outside")
	prompt_vertical:set_middle(prompt_layout)

	local prompt_area_layout = wibox.container.constraint(prompt_vertical, "exact", nil, style.title_height)

	local area_vertical = wibox.layout.align.vertical()
	area_vertical:set_top(prompt_area_layout)
	area_vertical:set_middle(wibox.container.margin(self.list.layout, 0, 0, style.border_margin[3]))
	local area_layout = wibox.container.margin(area_vertical, unpack(style.border_margin))

	-- Create floating wibox for cs_selector widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})

	self.wibox:set_widget(area_layout)
	self.wibox:geometry(style.geometry)
end

-- Show cs_selector widget
-- Wibox appears on call and hides after "enter" or "esc" pressed
-----------------------------------------------------------------------------------------------------------------------
function cs_selector:show()
	if not self.wibox then
		self:init()
	end

	list_filtrate("")
	self.list:set_select(1)

	redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
	self.wibox.visible = true

	return awful.prompt.run({
		prompt = "",
		textbox = self.textbox,
		exe_callback = function() self.list.items[self.list.selected]:open() end,
		done_callback = function() self:hide() end,
		keypressed_callback = keypressed_callback,
		changed_callback = list_filtrate,
	})
end

function cs_selector:hide()
	self.wibox.visible = false
end

-- Set user hotkeys
-----------------------------------------------------------------------------------------------------------------------
function cs_selector:set_keys(keys, layout)
	local layout = layout or "all"
	if keys then
		self.keys[layout] = keys
		if layout ~= "all" then
			self.keys.all = awful.util.table.join(self.keys.move, self.keys.action)
		end
	end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return cs_selector
