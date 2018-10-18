-----------------------------------------------------------------------------------------------------------------------
--                                                Rules config                                                       --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local beautiful = require("beautiful")

local redtitle = require("redflat.titlebar")

local appnames = require("configs/alias-config")
local tagconf = require("configs/tag-config")
local merge_rules = require("user/util/table").merge_rules

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local rules = {}

rules.base_properties = {
	border_width      = beautiful.border_width,
	border_color      = beautiful.border_normal,
	focus             = awful.client.focus.filter,
	raise             = true,
	size_hints_honor  = false,
	screen            = awful.screen.preferred,
	titlebars_enabled = false,
	minimized         = false,
}

rules.floating_any = {
	type = { "dialog" },
	class = {
		"Nm-connection-editor",
		"Qalculate-gtk",
	},
	role = { "pop-up" },
	name = {
		"Event Tester",
		"htop",
	},
}

-- these will not trigger the creation of a new tab
rules.minor = {
	class = {
		"st-256color",
		"TelegramDesktop",
	},
}

-- Build rule table
-----------------------------------------------------------------------------------------------------------------------
function rules:init(args)

	local args = args or {}
	self.base_properties.keys = args.hotkeys.keys.client
	self.base_properties.buttons = args.hotkeys.mouse.client


	-- Build rules
	--------------------------------------------------------------------------------
	self.rules = {
		{ -- all
			rule       = {},
			properties = args.base_properties or self.base_properties,
		},
		{ -- "TG"
			rule_any   = {
				class  = { "TelegramDesktop" }
			},
			properties = {
				tag         = "TG",
				switchtotag = false,
			},
		},
		{ -- floating
			rule_any   = args.floating_any or self.floating_any,
			properties = {
				floating     = true,
				placement    = awful.placement.centered,
			},
		},
		{ -- vlc console fix
			rule = { class = "vlc", type = "utility" },
			properties = {
				floating = true,
				border_width = 0,
			},
		},
	}


	-- Set awful rules
	--------------------------------------------------------------------------------
	awful.rules.rules = rules.rules

	-- Set tagconf rules
	--------------------------------------------------------------------------------
	tagconf:set_rules_any(merge_rules(self.minor, self.floating_any))
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return rules
