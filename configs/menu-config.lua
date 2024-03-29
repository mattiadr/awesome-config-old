-----------------------------------------------------------------------------------------------------------------------
--                                                  Menu config                                                      --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local beautiful = require("beautiful")
local awful = require("awful")
local naughty = require("naughty")

local redflat = require("redflat")


-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local menu = {}


-- Build function
-----------------------------------------------------------------------------------------------------------------------
function menu:init(args)

	-- vars
	local args = args or {}
	local env = args.env or {} -- fix this?
	local separator = args.separator or { widget = redflat.gauge.separator.horizontal() }
	local theme = args.theme or { auto_hotkey = true }
	local icon_style = args.icon_style or { custom_only = true, scalable_only = true }

	-- theme vars
	local deficon = redflat.util.base.placeholder()
	local icon = redflat.util.table.check(beautiful, "icon.awesome") and beautiful.icon.awesome or deficon
	local color = redflat.util.table.check(beautiful, "color.icon") and beautiful.color.icon or nil

	-- icon finder
	local function micon(name)
		return redflat.service.dfparser.lookup_icon(name, icon_style)
	end

	-- Application submenu
	------------------------------------------------------------
	local appmenu = redflat.service.dfparser.menu({ icons = icon_style, wm_name = "awesome" })

	-- Awesome submenu
	------------------------------------------------------------
	local awesomemenu = {
		{ "Restart",        awesome.restart,                     micon("gnome-session-reboot") },
		separator,
		{ "Awesome config", env.fm .. " .config/awesome",        micon("folder-bookmarks")     },
		{ "Awesome lib",    env.fm .. " /usr/share/awesome/lib", micon("folder-bookmarks")     },
	}

	-- Exit submenu
	------------------------------------------------------------
	local exitmenu = {
		{ "Reboot",       "reboot",            micon("gnome-session-reboot")  },
		{ "Suspend",      "systemctl suspend", micon("gnome-session-suspend") },
	}

	-- Main menu
	------------------------------------------------------------
	self.mainmenu = redflat.menu({ theme = theme,
		items = {
			{ "Awesome",      awesomemenu,                        micon("awesome")          },
			{ "Applications", appmenu,                            micon("distributor-logo") },
			separator,
			{ "Chromium",     "chromium",                         micon("google-chrome")    },
			{ "ranger",       env.fm,                             micon("folder")           },
			{ "htop",         env.terminal .. " -c htop -e htop", micon("htop")             },
			separator,
			{ "Exit",         exitmenu,                           micon("exit")             },
			{ "Shutdown",     "shutdown now",                     micon("system-shutdown")  },
		}
	})

	-- Power menu
	------------------------------------------------------------
	self.powermenu = redflat.menu({ theme = theme,
		items = {
			{ "Shutdown",     "shutdown now",      micon("system-shutdown")       },
			{ "Reboot",       "reboot",            micon("gnome-session-reboot")  },
			{ "Suspend",      "systemctl suspend", micon("gnome-session-suspend") },
		}
	})

	-- Menu panel widget
	------------------------------------------------------------
	self.widget = redflat.gauge.svgbox(icon, nil, color)
	self.buttons = awful.util.table.join(
		awful.button({ }, 1, function() self.mainmenu:toggle() end)
	)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return menu
