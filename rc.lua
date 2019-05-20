-----------------------------------------------------------------------------------------------------------------------
--                                                    Main config                                                    --
-----------------------------------------------------------------------------------------------------------------------

-- Load modules
-----------------------------------------------------------------------------------------------------------------------

-- Standard awesome library
------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

require("awful.autofocus")

-- User modules
------------------------------------------------------------
local redflat = require("redflat")

local rules = require("configs/rules-config")

-- global module
timestamp = require("redflat.timestamp")

-- Error handling
-----------------------------------------------------------------------------------------------------------------------
require("configs/ercheck-config") -- load file with error handling

-- Setup theme and environment vars
-----------------------------------------------------------------------------------------------------------------------
local env = require("configs/env-config") -- load file with environment
env:init()

-- Layouts setup
-----------------------------------------------------------------------------------------------------------------------
local layouts = require("configs/layout-config") -- load file with tile layouts setup
layouts:init()

-- Main menu configuration
-----------------------------------------------------------------------------------------------------------------------
local mymenu = require("configs/menu-config") -- load file with menu configuration
mymenu:init({ env = env })

-- Panel widgets
-----------------------------------------------------------------------------------------------------------------------

-- Separator
--------------------------------------------------------------------------------
local separator = redflat.gauge.separator.vertical()

-- Layoutbox configure
--------------------------------------------------------------------------------
local layoutbox = {}

layoutbox.buttons = awful.util.table.join(
	awful.button({ }, 1, function () mymenu.mainmenu:toggle()                                        end),
	awful.button({ }, 3, function () redflat.widget.layoutbox:toggle_menu(mouse.screen.selected_tag) end),
	awful.button({ }, 4, function () awful.layout.inc(1)                                             end),
	awful.button({ }, 5, function () awful.layout.inc(-1)                                            end)
)

-- Taglist widget
--------------------------------------------------------------------------------
local taglist = {}
taglist.style = { separator = separator, widget = redflat.gauge.tag.blue.new, show_tip = false }
taglist.buttons = awful.util.table.join(
	awful.button({         }, 1, function(t)
		local tag = awful.screen.focused().selected_tag
		if tag ~= t then t:view_only() elseif t.layout.switch_tab then t.layout:switch_tab(t) end
	end),
	awful.button({ env.mod }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
	awful.button({         }, 2, awful.tag.viewtoggle                                                ),
	awful.button({         }, 3, function(t) redflat.widget.layoutbox:toggle_menu(t)              end),
	awful.button({ env.mod }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end  end)
)

-- Tasklist
--------------------------------------------------------------------------------
local tasklist = {}

-- load list of app name aliases from files and set it as part of tasklist theme
tasklist.style = { appnames = require("configs/alias-config") }

tasklist.buttons = awful.util.table.join(
	awful.button({ }, 1, redflat.widget.tasklist.action.select),
	awful.button({ }, 2, redflat.widget.tasklist.action.close ),
	awful.button({ }, 3, redflat.widget.tasklist.action.menu  )
)

-- Textclock widget
--------------------------------------------------------------------------------
local textclock = {}
textclock.widget = redflat.widget.textclock({
	timeout    = 10,
	timeformat = "%H:%M - %d/%m",
	dateformat = "%a, %d %B %Y",
})

-- Floating Calendar
--------------------------------------------------------------------------------
local calendar = require("user/float/calendar")
calendar({
	day_id     = "%Y-%m-%d",
	week_head  = "",
	week_col   = "",
}):attach(textclock.widget)

-- Software update indcator
--------------------------------------------------------------------------------
local upgrades_widget = require("user/widget/upgrades")

local upgrades = {}
upgrades.widget = upgrades_widget({
	{ name = "pacman", check = [[checkupdates | wc -l]], upgrade = [[sudo pacman -Syu]] },
	-- { name = "cower",  check = [[cower -u | grep -v -P "(Checking)|(ignored)" | wc -l]], upgrade = [[cower -duf]] },
}, { terminal = env.terminal })

-- PA volume control
--------------------------------------------------------------------------------
local pulse = require("user/widget/pulse")

local volume = {}
volume.widget = pulse({ sink_names = {
	["alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo"] = "Headphones",
	["alsa_output.pci-0000_0b_00.3.analog-stereo"] = "Speakers",
} }, { widget = redflat.gauge.audio.red.new })

volume.buttons = awful.util.table.join(
	awful.button({ }, 1, function() pulse:mute()                             end),
	awful.button({ }, 2, function() awful.spawn.with_shell("pavucontrol-qt") end),
	awful.button({ }, 3, function() pulse:choose_sink()                      end),
	awful.button({ }, 4, function() pulse:change_volume()                    end),
	awful.button({ }, 5, function() pulse:change_volume({ down = true })     end)
)

-- Usisks widget
--------------------------------------------------------------------------------
local udisks = require("user/widget/udisks")
udisks.filemanager = env.fm

-- Screen setup
-----------------------------------------------------------------------------------------------------------------------

-- setup
awful.screen.connect_for_each_screen(
	function(s)
		-- wallpaper
		env.wallpaper(s)

		-- tags
		rules:tag_setup(s)

		-- layoutbox widget
		layoutbox[s] = redflat.widget.layoutbox({ screen = s })

		-- taglist widget
		taglist[s] = redflat.widget.taglist({ screen = s, filter = redflat.widget.taglist.filter.noempty, hint = env.tagtip, buttons = taglist.buttons }, taglist.style)

		-- tasklist widget
		tasklist[s] = redflat.widget.tasklist({ screen = s, buttons = tasklist.buttons }, tasklist.style)

		-- panel wibox
		s.panel = awful.wibar({ position = "bottom", screen = s, height = beautiful.panel_height or 36 })

		-- add widgets to the wibox
		s.panel:setup({
			layout = wibox.layout.align.horizontal,
			{ -- left widgets
				layout = wibox.layout.fixed.horizontal,

				env.wrapper(layoutbox[s], "layoutbox", layoutbox.buttons),
				separator,
				env.wrapper(taglist[s], "taglist"),
				separator,
			},
			{ -- middle widget
				layout = wibox.layout.align.horizontal,
				expand = "outside",

				nil,
				env.wrapper(tasklist[s], "tasklist"),
			},
			{ -- right widgets
				layout = wibox.layout.fixed.horizontal,

				udisks.widget,
				separator,
				env.wrapper(wibox.widget.systray(true), "systray"),
				separator,
				env.wrapper(volume.widget, "volume", volume.buttons),
				separator,
				env.wrapper(upgrades.widget, "upgrades"),
				separator,
				env.wrapper(textclock.widget, "textclock"),
			},
		})
	end
)

-- Key bindings
-----------------------------------------------------------------------------------------------------------------------
local hotkeys = require("configs/keys-config") -- load file with hotkeys configuration
hotkeys:init({ env = env, menu = mymenu.mainmenu, powermenu = mymenu.powermenu })

-- Rules
-----------------------------------------------------------------------------------------------------------------------
rules:init({ hotkeys = hotkeys})

-- Base signal set for awesome wm
-----------------------------------------------------------------------------------------------------------------------
local signals = require("configs/signals-config") -- load file with signals configuration
signals:init({ env = env })

-- Autostart user applications
-----------------------------------------------------------------------------------------------------------------------
local autostart = require("configs/autostart-config") -- load file with autostart application list

if timestamp.is_startup() then
	autostart.run()
end
