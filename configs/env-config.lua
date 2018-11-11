-----------------------------------------------------------------------------------------------------------------------
--                                                  Environment config                                               --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local os = os
local math = math
local io = io
local table = table

local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local wibox = require("wibox")
local naughty = require("naughty")

local redflat = require("redflat")

local convert_wallpaper = require("user.util.screen-lock").convert_wallpaper

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local env = {}

-- Build hotkeys depended on config parameters
-----------------------------------------------------------------------------------------------------------------------
function env:init()

	-- environment vars
	self.terminal = "st"
	self.mod = "Mod4"
	self.fm = self.terminal .. " -c ranger -e ranger"
	self.home = os.getenv("HOME")
	self.themedir = awful.util.get_configuration_dir() .. "theme/"

	self.sloppy_focus = true
	self.color_border = true
	self.color_border_focus = true
	self.set_slave = true

	-- theme setup
	beautiful.init(env.themedir .. "/theme.lua")

	-- naughty config
	naughty.config.defaults.position = "bottom_right"
	naughty.config.padding = beautiful.useless_gap and 2 * beautiful.useless_gap or 0

	if beautiful.naughty then
		naughty.config.presets.normal   = redflat.util.table.merge(beautiful.naughty.base, beautiful.naughty.normal)
		naughty.config.presets.critical = redflat.util.table.merge(beautiful.naughty.base, beautiful.naughty.critical)
		naughty.config.presets.low      = redflat.util.table.merge(beautiful.naughty.base, beautiful.naughty.low)

		-- dirty fix to ignore forced geometry for critical preset
		-- For the sake of laziness I prefer fix some parameters after inherit than write pure table without inherit
		naughty.config.presets.critical.height, naughty.config.presets.critical.width = nil, nil
	end
end


-- Common functions
-----------------------------------------------------------------------------------------------------------------------

-- Wallpaper setup
--------------------------------------------------------------------------------
local last_used = nil

math.randomseed(os.time())

env.wallpaper = function(s)
	if beautiful.wallpaper then
		if gears.filesystem.file_readable(beautiful.wallpaper) then
			-- is file
			gears.wallpaper.maximized(beautiful.wallpaper, s, true)
			convert_wallpaper(beautiful.wallpaper)
		elseif gears.filesystem.dir_readable(beautiful.wallpaper) then
			-- is directory, choose random
			local files = {}
			for file in io.popen('find "' .. beautiful.wallpaper .. '" -type f'):lines() do
				table.insert(files, file)
			end
			for i, v in ipairs(files) do
				if v == last_used then
					table.remove(files, i)
					break
				end
			end
			last_used = files[math.random(#files)]
			gears.wallpaper.maximized(last_used)
			convert_wallpaper(last_used)
		else
			-- isn't file or dir, might me color string
			gears.wallpaper.set(beautiful.color.bg)
		end
	end
end

-- Tag tooltip text generation
--------------------------------------------------------------------------------
env.tagtip = function(t)
	local layname = awful.layout.getname(awful.tag.getproperty(t, "layout"))
	if redflat.util.table.check(beautiful, "widget.layoutbox.name_alias") then
		layname = beautiful.widget.layoutbox.name_alias[layname] or layname
	end
	return string.format("%s (%d apps) [%s]", t.name, #(t:clients()), layname)
end

-- Panel widgets wrapper
--------------------------------------------------------------------------------
env.wrapper = function(widget, name, buttons)
	local margin = { 0, 0, 0, 0 }

	if redflat.util.table.check(beautiful, "widget.wrapper") and beautiful.widget.wrapper[name] then
		margin = beautiful.widget.wrapper[name]
	end
	if buttons then
		widget:buttons(buttons)
	end

	return wibox.container.margin(widget, unpack(margin))
end


-- End
-----------------------------------------------------------------------------------------------------------------------
return env
