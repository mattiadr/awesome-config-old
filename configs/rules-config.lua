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
	name = { "Event Tester", "Eclipse IDE Launcher " },
}

rules.vlc_fix = {
	class = "vlc",
	type = "utility",
}

-- Tabbed layout rules
--------------------------------------------------------------------------------
rules.tabbed.master = {
	-- empty
}

rules.tabbed.minor = {
	{
		rule_any = { class = { "St" } },
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

-- Named Tags tables
--------------------------------------------------------------------------------
rules.named_tags = {
	{
		name       = "1 TERM",
		layout     = awful.layout.suit.fair,
		lay_args   = { selected = true, always_show = true },
	},
	{
		name       = "2 WEB",
		layout     = lay_tabbed(awful.layout.suit.tile, rules.tabbed.master, rules.tabbed.minor),
		lay_args   = { gap_single_client = false, master_width_factor = 0.75 },
		rule_any   = { class = { "Chromium" } },
		except_any = rules.floating_any,
		cl_props   = { switchtotag = true },
	},
	{
		name       = "3 DEV",
		layout     = lay_tabbed(awful.layout.suit.tile, rules.tabbed.master, rules.tabbed.minor),
		lay_args   = { gap_single_client = false, master_width_factor = 0.75 },
		rule_any   = { class = { "Sublime_text", "Eclipse" } },
		except_any = rules.floating_any,
		cl_props   = { switchtotag = true },
	},
	{
		name       = "4 FILE",
		layout     = awful.layout.suit.fair.horizontal,
		lay_args   = {},
		rule_any   = { class = { "ranger" } },
		except_any = rules.floating_any,
		cl_props   = { switchtotag = true },
	},
}

-- Non Numeric Tags tables
--------------------------------------------------------------------------------
rules.nn_tags = {
	{
		name     = "HTOP",
		layout   = awful.layout.suit.max,
		rule_any = { class = { "htop" } },
		cl_props = { switchtotag = true },
		key      = "x",
		desc     = "Toggle htop",
		spawn    = function() awful.spawn("st -c htop -e htop") end,
	},
	{
		name     = "TG",
		layout   = awful.layout.suit.max,
		lay_args = { always_show = true },
		rule_any = { class = { "TelegramDesktop" } },
		key      = "\\",
		desc     = "Toggle Telegram",
		spawn    = function() awful.spawn.with_shell("telegram-desktop") end,
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

	local cl_props = props.cl_props or {}
	-- set defaults
	cl_props.tag = props.name

	ret.properties = cl_props

	return ret
end

-- Create tag from props table
--------------------------------------------------------------------------------
local function create_tag(props, screen, skip_if_exists)
	if skip_if_exists and props.tag then return end

	local args = props.lay_args or {}
	-- sey defaults
	args.screen = screen
	args.layout = props.layout

	props.tag = awful.tag.add(props.name, args)
end

-- Create key from props table
--------------------------------------------------------------------------------
local function create_nn_key(env, props)
	-- function called when key is pressed
	local function toggle()
		local t = awful.screen.focused().selected_tag

		if t and t == props.tag then
			awful.tag.history.restore()
		else
			-- find if app is alredy open
			local ar = awful.rules
			for _, c in ipairs(props.tag:clients()) do
				if awful.rules.matches(c, props) then
					c:raise()
					props.tag:view_only()
					return
				end
			end
			-- if no clients match the rules, spawn
			props.spawn()
		end
	end

	-- create key
	local key = {
		{ env.mod }, props.key, toggle,
		{ description = props.desc, group = "Non Numeric Tags" }
	}

	return key
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

	-- named tags
	for _, v in ipairs(self.named_tags) do
		local rule = build_rule(v)
		if rule then table.insert(self.rules, rule) end
	end

	-- non numeric tags
	for _, v in ipairs(self.nn_tags) do
		local rule = build_rule(v)
		if rule then table.insert(self.rules, rule) end
	end

	-- floating
	table.insert(self.rules, {
		rule_any   = args.floating_any or self.floating_any,
		properties = {
			floating     = true,
			placement    = awful.placement.centered,
			border_width = beautiful.border_width,
		},
	})

	-- vlc console fix
	table.insert(self.rules, {
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
function rules:tag_setup(screen, skip_nn)
	-- create named tags
	for _, v in ipairs(self.named_tags) do
		create_tag(v, screen)
	end

	-- create non named tags
	self.unnamed_tags.first = #screen.tags + 1
	for i = self.unnamed_tags.first, self.unnamed_tags.last do
		create_tag({
			name     = tostring(i),
			layout   = lay_tabbed(awful.layout.suit.tile, self.tabbed.master, self.tabbed.minor),
			lay_args = { gap_single_client = false, master_width_factor = 0.75 },
		}, screen)
	end

	-- create non numeric tags
	for _, v in ipairs(self.nn_tags) do
		-- create lay_args if doesn't exist and set non_numeric property to true
		v.lay_args = v.lay_args or {}
		v.lay_args.non_numeric = true
		-- we skip if tag alredy exists to avoid creating it on multiple monitors
		create_tag(v, screen, true)
	end
end

-- Get table of keys to toggle non numeric tags
-----------------------------------------------------------------------------------------------------------------------
function rules:get_nn_keys(env)
	local keys = {}

	for _, v in ipairs(self.nn_tags) do
		table.insert(keys, create_nn_key(env, v))
	end

	return keys
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return rules
