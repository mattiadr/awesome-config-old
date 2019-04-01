-----------------------------------------------------------------------------------------------------------------------
--                                                 AwesomeWM Debugger                                                --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gfs = require("gears.filesystem")

local inspect = require("user/util/inspect")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local debugger = { cmd_path = gfs.get_cache_dir() .. "debugger_cmd.lua" }

function context_to_text(context)
	-- skip metatable
	local process = function(item)
		if item ~= getmetatable(context) then return item end
	end
	return "Console context:\n" .. inspect(context, { depth = 1, process = process })
end

-- Create text box with border and callback
--------------------------------------------------------------------------------
function create_button(name, callback)
	local tb = wibox.widget.textbox(" " .. name .. " ")
	tb:buttons(awful.button({}, 1, callback))
	local ma = wibox.container.margin(tb, 2, 2, 2, 2, "#aaaaaa")
	-- force margin container to occupy only the space of the text box
	return wibox.layout.fixed.horizontal(ma)
end

function debugger:open_editor(new)
	-- clear file
	if new then os.remove(self.cmd_path) end

	awful.spawn("st -e nano " .. self.cmd_path)
	self:hide()
end

function debugger:run_command()
	local fun, err = loadfile(self.cmd_path, nil, self.console.context)

	if fun then
		fun()
	else
		self:log(err)
	end
end

-- Initialize wibox
--------------------------------------------------------------------------------
function debugger:init()
	-- set wibox properties
	self.wibox = wibox({ type = "tooltip" })
	self.wibox.visible = false
	self.wibox.ontop = true
	self.wibox.border_width = 2
	self.wibox.border_color = "#404040"
	self.wibox:set_bg("#202020")
	self.wibox:set_fg("#aaaaaa")

	local wa = awful.screen.focused().workarea
	self.wibox:geometry({
		width  = wa.width - 12,
		height = wa.height - 12,
	})

	awful.placement.centered(self.wibox, { honor_workarea = true })

	-- title widget
	local title = wibox.widget.textbox("Debugger")
	title:set_align("center")
	local tw, th = title:get_preferred_size()

	-- logger widget
	self.logger = { len = 0 }
	self.logger.widget = wibox.layout.fixed.vertical()
	self.logger.max_len = self.wibox.height - th

	-- console widget
	self.console = {}
	-- console context (libs + log function)
	self.console.context = setmetatable({
		awful     = require("awful"),
		beautiful = require("beautiful"),
		log       = function(...) self:log(...) end,
	}, { __index = _G })

	self.console.context_widget = wibox.widget.textbox()
	self.console.context_widget:set_text(context_to_text(self.console.context))

	-- setup wibox content
	self.wibox:setup({
		layout = wibox.layout.fixed.vertical,
		spacing = 15,

		title,
		{
			layout = wibox.layout.flex.horizontal,
			spacing = 20,

			self.logger.widget,
			{
				layout = wibox.layout.fixed.vertical,
				spacing = 15,

				self.console.context_widget,
				{
					layout = wibox.layout.fixed.horizontal,
					spacing = 4,

					create_button("New Command", function() self:open_editor(true) end),
					create_button("Edit Command", function() self:open_editor() end),
					create_button("Run Command", function() self:run_command() end),
				},
			},
		},
	})
end

-- Show debugger window
--------------------------------------------------------------------------------
function debugger:show()
	-- init debugger
	if not self.wibox then
		self:init(sub)
	end

	self.wibox.visible = true
end

-- Hide debugger window
--------------------------------------------------------------------------------
function debugger:hide()
	-- init debugger
	if not self.wibox then
		self:init(sub)
	end

	self.wibox.visible = false
end

-- Toggle debugger window
--------------------------------------------------------------------------------
function debugger:toggle()
	-- init debugger
	if not self.wibox then
		self:init(sub)
	end

	if self.wibox.visible then
		self:hide()
	else
		self:show()
	end
end

-- Log object
--------------------------------------------------------------------------------
function debugger:log(obj, name, inspect_args)
	-- init debugger
	if not self.logger then
		self:init()
	end

	-- convert obj to text
	local text = ""
	if name then
		text = string.format("[%s]\n", name)
		self:add(obj, name)
	end
	text = text .. inspect(obj, inspect_args or { depth = 1 })

	-- create new text box and append to logger
	local tb = wibox.widget.textbox()
	tb:set_text(text)
	local _, th = tb:get_preferred_size()
	self.logger.widget:add(tb)
	self.logger.len = self.logger.len + th

	-- remove children if necessary
	while self.logger.len > self.logger.max_len do
		-- break if the first and only children is bigger then max
		if #self.logger.widget.children == 1 then break end
		local first = self.logger.widget.children[1]
		local _, h = first:get_preferred_size()
		self.logger.len = self.logger.len - h
		self.logger.widget:remove(1)
	end
end

-- Add object to context, to add primitive types wrap them in a function
--------------------------------------------------------------------------------
function debugger:add(obj, name)
	-- init debugger
	if not self.console then
		self:init()
	end

	if not name then
		self:log("Missing object name")
		return
	end

	self.console.context[name] = obj

	self.console.context_widget:set_text(context_to_text(self.console.context))
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return debugger
