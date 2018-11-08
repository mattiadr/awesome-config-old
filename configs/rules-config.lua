-----------------------------------------------------------------------------------------------------------------------
--                                                Rules config                                                       --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local beautiful = require("beautiful")

local redtitle = require("redflat.titlebar")

local appnames = require("configs/alias-config")
local lay_tabbed = require("user/layout/tabbed")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local rules = {
	unnamed_tags = { first = nil, last = 10 },
	tabbed = {},
}

-- Generic rules
--------------------------------------------------------------------------------
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

rules.vlc_fix = {
	class = "vlc",
	type = "utility"
}

-- Tabbed layout rules
--------------------------------------------------------------------------------
rules.tabbed.master = {
	{
		rule_any = { name = { "ranger" } }
	},
}

rules.tabbed.minor = {
	{
		rule_any = { class = { "st-256color" } },
	},
	{
		rule_any = rules.floating_any,
	},
	{
		rule = rules.vlc_fix,
	},
}

-- Common properties
--------------------------------------------------------------------------------
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

-- Tags tables
--------------------------------------------------------------------------------
rules.tags = {
	{
		name     = "1 TERM",
		layout   = awful.layout.suit.fair,
		args     = { selected = true, always_show = true },
	},
	{
		name     = "2 WEB",
		layout   = lay_tabbed(awful.layout.suit.tile, rules.tabbed.master, rules.tabbed.minor),
		args     = { gap_single_client = false, master_width_factor = 0.75 },
		rule_any = { class = { "Chromium" } },
	},
	{
		name     = "3 DEV",
		layout   = lay_tabbed(awful.layout.suit.tile, rules.tabbed.master, rules.tabbed.minor),
		args     = { gap_single_client = false, master_width_factor = 0.75 },
		rule_any = { class = { "Sublime_text" } },
	},
	{
		name     = "4 FILE",
		layout   = awful.layout.suit.fair,
		args     = {},
		rule_any = { name = { "ranger" } },
	},
}

-- Utility functions
-----------------------------------------------------------------------------------------------------------------------

-- Build rule from props table
--------------------------------------------------------------------------------
local function build_rule(props)
	local ret = {}

	if not props.rule and not props.rule_any then return nil end

	ret.rule       = props.rule
	ret.rule_any   = props.rule_any
	ret.except     = props.except
	ret.except_any = props.except_any

	ret.properties = {
		tag         = props.name,
		switchtotag = true,
	}

	return ret
end

-- Create tag from props table
--------------------------------------------------------------------------------
local function create_tag(props, screen)
	local args = props.args or {}
	-- sey defaults
	args.screen = screen
	args.layout = props.layout

	awful.tag.add(props.name, args)
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
	}

	for _, v in ipairs(self.tags) do
		local rule = build_rule(v)
		if rule then table.insert(self.rules, rule) end
	end

	table.insert(self.rules, { -- "TG"
		rule_any   = {
			class  = { "TelegramDesktop" }
		},
		properties = {
			tag         = "TG",
			switchtotag = false,
		},
	})
	table.insert(self.rules, { -- floating
		rule_any   = args.floating_any or self.floating_any,
		properties = {
			floating     = true,
			placement    = awful.placement.centered,
			border_width = beautiful.border_width,
		},
	})
	table.insert(self.rules, { -- vlc console fix
		rule = self.vlc_fix,
		properties = {
			floating     = true,
			border_width = 0,
		},
	})

	-- Set awful rules
	--------------------------------------------------------------------------------
	awful.rules.rules = self.rules
end

-- Tag setup
-----------------------------------------------------------------------------------------------------------------------
function rules:tag_setup(screen)
	for _, v in ipairs(self.tags) do
		create_tag(v, screen)
	end

	self.unnamed_tags.first = #screen.tags + 1
	for i = self.unnamed_tags.first, self.unnamed_tags.last do
			create_tag({
			name   = tostring(i),
			layout = lay_tabbed(awful.layout.suit.tile, self.tabbed.master, self.tabbed.minor),
			args   = { gap_single_client = false, master_width_factor = 0.75 },
		}, screen)
	end

	awful.tag.add("TG", {
		layout      = awful.layout.suit.max,
		screen      = s,
		always_show = true,
	})
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return rules
