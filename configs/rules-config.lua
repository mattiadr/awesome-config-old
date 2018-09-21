-----------------------------------------------------------------------------------------------------------------------
--                                                Rules config                                                       --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local beautiful = require("beautiful")

local redtitle = require("redflat.titlebar")

local appnames = require("configs/alias-config")

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
	callback          = function(client)
		local tag = awful.screen.focused().selected_tag
		if tag.index == 1 or #tag:clients() > 1 then
			tag = global_add_tag(appnames.short[client.class])
		end
		client:move_to_tag(tag)
		tag:view_only()
	end
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

rules.minor = {
	class = {
		"st-256color",
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
				callback    = function() end, -- used to disable default callback
			},
		},
		{ -- floating
			rule_any   = args.floating_any or self.floating_any,
			properties = {
				floating     = true,
				placement    = awful.placement.centered,
				border_width = self.base_properties.border_width,
				callback     = function() end, -- used to disable default callback
			},
		},
		{ -- minor apps (wont create new tag)
			rule_any   = self.minor,
			properties = {
				callback     = function() end, -- used to disable default callback
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
