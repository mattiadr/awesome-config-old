-----------------------------------------------------------------------------------------------------------------------
--                                                 Cheatsheet viewer                                                 --
-----------------------------------------------------------------------------------------------------------------------
-- Menu insipired from reflat.float.apprunner
-- Cheatsheet inspired from redflat.float.hotkeys
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local math = math
local string = string

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")

local redflat = require("redflat")
local redutil = require("redflat.util")
local separator = require("redflat.gauge.separator")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local cs_viewer = { cheatsheet = nil, cache = {} }
local hasitem = awful.util.table.hasitem

-- key bindings
cs_viewer.keys = { close = { "Escape" } }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		border_margin = { 10, 10, 10, 10 },
		tspace        = 5,
		hspace        = 50,
		delim         = "   ",
		border_width  = 2,
		font          = "Sans 12",
		keyfont       = "Sans bold 12",
		titlefont     = "Sans bold 14",
		separator     = {},
		color         = { border = "#575757", text = "#aaaaaa", main = "#b1222b", wibox = "#202020",
		                  gray = "#575757" }
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "float.cheatsheet_viewer") or {})
end

-- Divide cheatsheet into columns
--------------------------------------------------------------------------------
local function parse(cheatsheet)
	local bounds = { 25, 35 }

	-- count all lines
	local rows = 0
	for _, v in ipairs(cheatsheet) do
		rows = rows + 2 + #v
	end

	-- get number of cols based on bounds
	local n_cols = 1
	while n_cols <= #bounds and rows > bounds[n_cols] do
		n_cols = n_cols + 1
	end

	local cols = {}

	for i = 1, n_cols do
		cols[i] = { rows = 0 }
	end

	-- put group in shortest col
	for _, group in ipairs(cheatsheet) do
		local c = nil
		for _, col in ipairs(cols) do
			if c == nil or col.rows < c.rows then c = col end
		end

		table.insert(c, group)
		c.rows = c.rows + #group
	end

	return cols
end

-- Convert cheatsheet to markup
--------------------------------------------------------------------------------
local function build_markup(cheatsheet, style, query)
	local text = {}

	for i, column in ipairs(cheatsheet) do
		local coltxt = ""

		local max_cmd = 0
		for _, group in ipairs(column) do
			for _, value in ipairs(group) do
				if string.len(value.cmd) > max_cmd then
					max_cmd = string.len(value.cmd)
				end
			end
		end

		for _, group in ipairs(column) do
			-- set group title
			coltxt = coltxt .. string.format(
				"<span font='%s' color='%s'>%s</span>\n",
				style.titlefont, style.color.gray, group.group
			)

			-- add various commands
			for _, value in ipairs(group) do
				local line = string.format("<span font='%s'>%s</span>", style.keyfont, value.cmd)
				
				-- align keys
				line = line .. string.rep(" ", max_cmd - string.len(value.cmd))

				-- add description
				line = line .. style.delim .. value.description

				local clr = string.match(query, "%w") and (string.match(line, "%f[%w]" .. query)) and style.color.main or style.color.text
				line = string.format("<span color='%s'>%s</span>", clr, line)
				coltxt = coltxt .. line .. "\n"
			end
			coltxt = coltxt .. "\n"
		end
		text[i] = coltxt
	end

	return text
end

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function cs_viewer:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = default_style()
	self.style = style

	local bm = style.border_margin

	-- Create floating wibox for top widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})

	-- Widget layout setup
	--------------------------------------------------------------------------------
	self.layout = wibox.layout.flex.horizontal()

	self.title = wibox.widget.textbox("Title")
	self.title:set_align("center")
	self.title:set_font(style.titlefont)

	self.textbox = wibox.widget.textbox()
	self.textbox:set_ellipsize("start")

	self.wibox:setup({
		{
			{
				self.title,
				self.textbox,
				redflat.gauge.separator.horizontal(style.separator),
				spacing = style.tspace,
				layout = wibox.layout.fixed.vertical,
			},
			self.layout,
			layout = wibox.layout.align.vertical,
		},
		left = bm[1], right = bm[2], top = bm[3], bottom = bm[4],
		layout = wibox.container.margin,
	})

	self.keygrabber = function(mod, key, event)
		if event == "release" then
			if hasitem(self.keys.close, key) then
				self:hide(); return
			end
		end
	end

end

-- Highlight rows matching query
--------------------------------------------------------------------------------
function cs_viewer:highlight(query, set_geom)
	local cols = build_markup(self.parsed_cs, self.style, query)

	local width, height = 0, 0
	self.layout:reset()

	for _, col in ipairs(cols) do
		local box = wibox.widget.textbox()
		box:set_valign("top")
		box:set_font(self.style.font)
		box:set_markup(col)
		self.layout:add(box)

		if set_geom then
			local bw, bh = box:get_preferred_size()
			width = width + bw
			height = math.max(height, bh)
		end
	end

	if set_geom then
		self.parsed_cs.width = width + self.style.hspace * (#cols - 1)
		self.parsed_cs.height = height
	end
end

-- Show/hide widget
-----------------------------------------------------------------------------------------------------------------------

-- show
function cs_viewer:show(cheatsheet)
	-- init if needed
	if not self.wibox then self:init() end

	-- cache if needed
	local name = cheatsheet.name
	if not self.cache[name] then self.cache[name] = parse(cheatsheet) end
	self.parsed_cs = self.cache[name]

	self.title:set_text(name .. " cheatsheet")
	self:highlight("", true)

	-- set geometry
	local tw, th = self.title:get_preferred_size()
	local tbw, tbh = self.textbox:get_preferred_size()
	local bm = self.style.border_margin
	self.wibox:geometry({
		width = math.max(tw, self.parsed_cs.width) + bm[1] + bm[2],
		height = th*2 + self.style.tspace*3 + self.parsed_cs.height + bm[3] + bm[4],
	})

	-- display
	if not self.wibox.visible then
		redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
		self.wibox.visible = true
		awful.keygrabber.run(self.keygrabber)
	end

	-- prompt
	return awful.prompt.run({
		prompt = "",
		textbox = self.textbox,
		done_callback = function() self:hide() end,
		changed_callback = function(query) self:highlight(query, false) end,
	})
end

-- hide
function cs_viewer:hide()
	self.wibox.visible = false
	awful.keygrabber.stop(self.keygrabber)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return cs_viewer
