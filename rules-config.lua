-----------------------------------------------------------------------------------------------------------------------
--                                                Rules config                                                       --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful =require("awful")
local beautiful = require("beautiful")
local redtitle = require("redflat.titlebar")

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
}

rules.floating_any = {
	type = { "dialog" }
}

rules.ide = {
	class = { "Sublime_text" }
}

rules.borderless = {
	class = { "Chromium" }
}

for i = 1, #rules.ide.class do
	rules.borderless.class[#rules.borderless.class + i] = rules.ide.class[i]
end

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
		{ -- "2 - Dev"
			rule_any   = self.ide,
			properties = {
				tag         = "2 - Dev",
				switchtotag = true,
			},
		},
		{ -- "3 - Web"
			rule_any   = {
				class  = { "Chromium" }
			},
			properties = {
				tag         = "3 - Web",
				switchtotag = true,
			},
		},
		{ -- "0 - Tg"
			rule_any   = {
				class  = { "TelegramDesktop" }
			},
			properties = {
				tag         = "0 - Tg",
				switchtotag = false,
			},
		},
		{ -- borderless
			rule_any   = self.borderless,
			properties = {
				border_width = 0,
			},
		},
		{ -- floating
			rule_any   = args.floating_any or self.floating_any,
			properties = {
				floating     = true,
				placement    = awful.placement.centered,
				border_width = self.base_properties.border_width,
			},
		},
		{ -- normal
			rule_any   = { type = { "normal" }},
			properties = {
				placement    = awful.placement.no_overlap + awful.placement.no_offscreen,
			},
		},
	}


	-- Set rules
	--------------------------------------------------------------------------------
	awful.rules.rules = rules.rules
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return rules
