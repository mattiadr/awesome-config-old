-----------------------------------------------------------------------------------------------------------------------
--                                          Hotkeys and mouse buttons config                                         --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local table = table
local awful = require("awful")
local beautiful = require("beautiful")

local redflat = require("redflat")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local hotkeys = { mouse = {}, raw = {}, keys = {}, fake = {} }

-- key aliases
local apprunner = redflat.float.apprunner
--local appswitcher = redflat.float.appswitcher
local current = redflat.widget.tasklist.filter.currenttags
local allscr = redflat.widget.tasklist.filter.allscreen
local laybox = redflat.widget.layoutbox
local redtip = redflat.float.hotkeys
local laycom = redflat.layout.common
local grid = redflat.layout.grid
local map = redflat.layout.map
local redtitle = redflat.titlebar
local qlaunch = redflat.float.qlaunch

-- Key support functions
-----------------------------------------------------------------------------------------------------------------------

-- change window focus by history
local function focus_to_previous()
	awful.client.focus.history.previous()
	if client.focus then client.focus:raise() end
end

-- change window focus by direction
local focus_switch_byd = function(dir)
	return function()
		awful.client.focus.bydirection(dir)
		if client.focus then client.focus:raise() end
	end
end

-- minimize and restore windows
local function minimize_all()
	for _, c in ipairs(client.get()) do
		if current(c, mouse.screen) then c.minimized = true end
	end
end

local function minimize_all_except_focused()
	for _, c in ipairs(client.get()) do
		if current(c, mouse.screen) and c ~= client.focus then c.minimized = true end
	end
end

local function restore_all()
	for _, c in ipairs(client.get()) do
		if current(c, mouse.screen) and c.minimized then c.minimized = false end
	end
end

local function restore_client()
	local c = awful.client.restore()
	if c then client.focus = c; c:raise() end
end

-- close window
local function kill_all()
	for _, c in ipairs(client.get()) do
		if current(c, mouse.screen) and not c.sticky then c:kill() end
	end
end

-- new clients placement
local function toggle_placement(env)
	env.set_slave = not env.set_slave
	redflat.float.notify:show({ text = (env.set_slave and "Slave" or "Master") .. " placement" })
end

-- finds the forst tag that starts with name
local function tag_starts_with(tags, name)
	for _, t in ipairs(tags) do
		if t.name:sub(1, #name) == name then
			return t
		end
	end
end

-- extracts the number from a tag name
local function tagname_to_num(name)
	return tonumber(string.match(name, "%d+"))
end

-- gets the correct tag or creates it
local function get_or_add_tag(s, i, name)
	-- volatile tags
	local tag = tag_starts_with(s.tags, tostring(i))

	if not tag then
		-- tag doesn't exist, create and move it second to last
		local tagname = name and tostring(i) .. " " .. name or tostring(i)
		tag = awful.tag.add(tagname, {
			layout              = awful.layout.suit.tile,
			screen              = s,
			gap_single_client   = false,
			master_width_factor = 0.75,
			volatile            = true,
		})

		-- swap last (newest tag) with second to last (telegram tag)
		local tags = s.tags
		tag:swap(tags[#tags - 1])

		-- sort newest tag into place
		for j = #tags - 2, 1, -1 do
			if (tagname_to_num(tag.name) < tagname_to_num(tags[j].name)) then
				tag:swap(tags[j])
			else
				break
			end
		end
	end

	return tag
end

-- add new tag
function global_add_tag(name)
	local s = awful.screen.focused()
	local tags = s.tags
	for i = 1, #tags do
		local is = tostring(i)
		if tags[i].name:sub(1, #is) ~= is then
			return get_or_add_tag(s, i, name)
		end
	end
	return get_or_add_tag(s, #s.tags, name)
end

-- numeric keys function builders
local function tag_numkey(i, mod, action)
	return awful.key(
		mod, "#" .. i + 9,
		function ()
			local screen = awful.screen.focused()
			local tag = get_or_add_tag(screen, i, nil)
			if tag then action(tag) end
		end
	)
end

local function client_numkey(i, mod, action)
	return awful.key(
		mod, "#" .. i + 9,
		function ()
			if client.focus then
				local tag = get_or_add_tag(client.focus.screen, i, nil)
				if tag then action(tag) end
			end
		end
	)
end

-- volume functions
local volume_raise = function()
	redflat.widget.pulse:mute(false)
	redflat.widget.pulse:change_volume({ show_notify = true })
end

local volume_lower = function()
	redflat.widget.pulse:mute(false)
	redflat.widget.pulse:change_volume({ show_notify = true, down = true })
end

local volume_mute  = function() redflat.widget.pulse:mute() end

-- brightness functions
local brightness = function(args)
	redflat.float.brightness:change_with_xbacklight(args) -- use xbacklight utility
	-- redflat.float.brightness:change_with_gsd(args) -- use gnome settings deamon
end

-- horizontal scroll function
local toggle_hor_scroll = function()
	local cmd = [[xinput list-props "AlpsPS/2 ALPS DualPoint TouchPad"]]
	awful.spawn.with_line_callback(cmd, {
		stdout = function(line)
			if not line:find("libinput Horizontal Scroll Enabled") then return end

			if line:match("0$") then
				awful.spawn.with_shell([[xinput set-prop "AlpsPS/2 ALPS DualPoint TouchPad" "libinput Horizontal Scroll Enabled" 1]])
				awful.spawn.with_shell([[notify-send "Horizontal scroll Enabled"]])
			else
				awful.spawn.with_shell([[xinput set-prop "AlpsPS/2 ALPS DualPoint TouchPad" "libinput Horizontal Scroll Enabled" 0]])
				awful.spawn.with_shell([[notify-send "Horizontal scroll Disabled"]])
			end
		end
	})
end

-- scrot function
local function scrot(sel, clipboard)
	local s = ""
	if sel then s = "-s " end

	local name
	local notif
	if clipboard then
		name = "/tmp/scrot.png"
		notif = "clipboard"
	else
		name = "~/images/scrot/%Y-%m-%d_$wx$h_scrot.png"
		notif = "~/images/scrot/"
	end

	local cmd = string.format("sleep 0.2 ; scrot -z -q 100 %s%s --exec 'xclip -i -selection c -t image/png < $f' && notify-send 'scrot' 'Screenshot taken to %s'", s, name, notif)
	awful.spawn.with_shell(cmd)
end

-- stash functions
local stash_FILO = {}

local stash_push = function()
	local c = client.focus
	if not c then return end
	table.insert(stash_FILO, c)
	c:tags({})
end

local stash_pop = function()
	if #stash_FILO > 0 then
		local t = awful.screen.focused().selected_tags
		stash_FILO[#stash_FILO]:tags(t)
		stash_FILO[#stash_FILO] = nil
	end
end

-- right bottom corner position
local rb_corner = function()
	return { x = screen[mouse.screen].workarea.x + screen[mouse.screen].workarea.width,
	         y = screen[mouse.screen].workarea.y + screen[mouse.screen].workarea.height }
end

local telegram_key = function()
	local tags = awful.screen.focused().tags
	local t = awful.screen.focused().selected_tag

	-- tags[#tags] is the last tag (telegram will always be the last tag)
	if t == tags[#tags] then
		awful.tag.history.restore()
	else
		tags[#tags]:view_only()
		awful.spawn.with_shell("telegram-desktop")
	end
end

-- Build hotkeys depended on config parameters
-----------------------------------------------------------------------------------------------------------------------
function hotkeys:init(args)

	-- Init vars
	local args = args or {}
	local env = args.env
	local mainmenu = args.menu

	self.mouse.root = (awful.util.table.join(
		awful.button({ }, 3, function () mainmenu:toggle() end)
		--awful.button({ }, 4, awful.tag.viewnext),
		--awful.button({ }, 5, awful.tag.viewprev)
	))

	-- Init widgets
	redflat.float.qlaunch:init()

	-- Keys for widgets
	--------------------------------------------------------------------------------

	-- Apprunner widget
	------------------------------------------------------------
	local apprunner_keys_move = {
		{
			{ }, "Up", function() apprunner:up() end,
			{ description = "Select previous item", group = "Navigation" }
		},
		{
			{ }, "Down", function() apprunner:down() end,
			{ description = "Select next item", group = "Navigation" }
		},
	}

	-- apprunner:set_keys(awful.util.table.join(apprunner.keys.move, apprunner_keys_move), "move")
	apprunner:set_keys(apprunner_keys_move, "move")

	-- Menu widget
	------------------------------------------------------------
	local menu_keys_move = {
		{
			{ env.mod }, "h", redflat.menu.action.back,
			{ description = "Go back", group = "Navigation" }
		},
		{
			{ env.mod }, "j", redflat.menu.action.down,
			{ description = "Select next item", group = "Navigation" }
		},
		{
			{ env.mod }, "k", redflat.menu.action.up,
			{ description = "Select previous item", group = "Navigation" }
		},
		{
			{ env.mod }, "l", redflat.menu.action.enter,
			{ description = "Open submenu", group = "Navigation" }
		},
	}

	redflat.menu:set_keys(awful.util.table.join(redflat.menu.keys.move, menu_keys_move), "move")
	-- redflat.menu:set_keys(menu_keys_move, "move")

	-- Appswitcher widget
	------------------------------------------------------------
	--[[
	appswitcher_keys = {
		{
			{ env.mod }, "a", function() appswitcher:switch() end,
			{ description = "Select next app", group = "Navigation" }
		},
		{
			{ env.mod, "Shift" }, "a", function() appswitcher:switch() end,
			{} -- hidden key
		},
		{
			{ env.mod }, "q", function() appswitcher:switch({ reverse = true }) end,
			{ description = "Select previous app", group = "Navigation" }
		},
		{
			{ env.mod, "Shift" }, "q", function() appswitcher:switch({ reverse = true }) end,
			{} -- hidden key
		},
		{
			{}, "Super_L", function() appswitcher:hide() end,
			{ description = "Activate and exit", group = "Action" }
		},
		{
			{ env.mod }, "Super_L", function() appswitcher:hide() end,
			{} -- hidden key
		},
		{
			{ env.mod, "Shift" }, "Super_L", function() appswitcher:hide() end,
			{} -- hidden key
		},
		{
			{}, "Return", function() appswitcher:hide() end,
			{ description = "Activate and exit", group = "Action" }
		},
		{
			{}, "Escape", function() appswitcher:hide(true) end,
			{ description = "Exit", group = "Action" }
		},
		{
			{ env.mod }, "Escape", function() appswitcher:hide(true) end,
			{} -- hidden key
		},
		{
			{ env.mod }, "F1", function() redtip:show()  end,
			{ description = "Show hotkeys helper", group = "Action" }
		},
	}

	appswitcher:set_keys(appswitcher_keys)
	--]]

	-- Emacs like key sequences
	--------------------------------------------------------------------------------

	-- initial key
	local keyseq = { { env.mod }, "c", {}, {} }

	-- group
	keyseq[3] = {
		{ {}, "k", {}, {} }, -- application kill group
		{ {}, "c", {}, {} }, -- client managment group
		{ {}, "r", {}, {} }, -- client managment group
		{ {}, "n", {}, {} }, -- client managment group
		{ {}, "g", {}, {} }, -- run or rise group
		{ {}, "f", {}, {} }, -- launch application group
	}

	-- quick launch key sequence actions
	for i = 1, 9 do
		local ik = tostring(i)
		table.insert(keyseq[3][5][3], {
			{}, ik, function() qlaunch:run_or_raise(ik) end,
			{ description = "Run or rise application №" .. ik, group = "Run or Rise", keyset = { ik } }
		})
		table.insert(keyseq[3][6][3], {
			{}, ik, function() qlaunch:run_or_raise(ik, true) end,
			{ description = "Launch application №".. ik, group = "Quick Launch", keyset = { ik } }
		})
	end

	-- application kill sequence actions
	keyseq[3][1][3] = {
		{
			{}, "f", function() if client.focus then client.focus:kill() end end,
			{ description = "Kill focused client", group = "Kill application", keyset = { "f" } }
		},
		{
			{}, "a", kill_all,
			{ description = "Kill all clients with current tag", group = "Kill application", keyset = { "a" } }
		},
	}

	-- client managment sequence actions
	keyseq[3][2][3] = {
		{
			{}, "p", function () toggle_placement(env) end,
			{ description = "Switch master/slave window placement", group = "Clients managment", keyset = { "p" } }
		},
	}

	keyseq[3][3][3] = {
		{
			{}, "f", restore_client,
			{ description = "Restore minimized client", group = "Clients managment", keyset = { "f" } }
		},
		{
			{}, "a", restore_all,
			{ description = "Restore all clients with current tag", group = "Clients managment", keyset = { "a" } }
		},
	}

	keyseq[3][4][3] = {
		{
			{}, "f", function() if client.focus then client.focus.minimized = true end end,
			{ description = "Minimized focused client", group = "Clients managment", keyset = { "f" } }
		},
		{
			{}, "a", minimize_all,
			{ description = "Minimized all clients with current tag", group = "Clients managment", keyset = { "a" } }
		},
		{
			{}, "e", minimize_all_except_focused,
			{ description = "Minimized all clients except focused", group = "Clients managment", keyset = { "e" } }
		},
	}


	-- Layouts
	--------------------------------------------------------------------------------

	-- shared layout keys
	local layout_tile = {
		{
			{ env.mod }, "h", function () awful.tag.incmwfact(-0.05) end,
			{ description = "Decrease master width factor", group = "Layout" }
		},
		{
			{ env.mod }, "j", function () awful.client.incwfact(-0.05) end,
			{ description = "Decrease window factor of a client", group = "Layout" }
		},
		{
			{ env.mod }, "k", function () awful.client.incwfact( 0.05) end,
			{ description = "Increase window factor of a client", group = "Layout" }
		},
		{
			{ env.mod }, "l", function () awful.tag.incmwfact( 0.05) end,
			{ description = "Increase master width factor", group = "Layout" }
		},
		{
			{ env.mod, }, "+", function () awful.tag.incnmaster( 1, nil, true) end,
			{ description = "Increase the number of master clients", group = "Layout" }
		},
		{
			{ env.mod }, "-", function () awful.tag.incnmaster(-1, nil, true) end,
			{ description = "Decrease the number of master clients", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "+", function () awful.tag.incncol( 1, nil, true) end,
			{ description = "Increase the number of columns", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "-", function () awful.tag.incncol(-1, nil, true) end,
			{ description = "Decrease the number of columns", group = "Layout" }
		},
	}

	laycom:set_keys(layout_tile, "tile")

	-- grid layout keys
	local layout_grid_move = {
		{
			{ env.mod }, "KP_Up", function() grid.move_to("up") end,
			{ description = "Move window up", group = "Movement" }
		},
		{
			{ env.mod }, "KP_Down", function() grid.move_to("down") end,
			{ description = "Move window down", group = "Movement" }
		},
		{
			{ env.mod }, "KP_Left", function() grid.move_to("left") end,
			{ description = "Move window left", group = "Movement" }
		},
		{
			{ env.mod }, "KP_right", function() grid.move_to("right") end,
			{ description = "Move window right", group = "Movement" }
		},
		{
			{ env.mod, "Control" }, "KP_Up", function() grid.move_to("up", true) end,
			{ description = "Move window up by bound", group = "Movement" }
		},
		{
			{ env.mod, "Control" }, "KP_Down", function() grid.move_to("down", true) end,
			{ description = "Move window down by bound", group = "Movement" }
		},
		{
			{ env.mod, "Control" }, "KP_Left", function() grid.move_to("left", true) end,
			{ description = "Move window left by bound", group = "Movement" }
		},
		{
			{ env.mod, "Control" }, "KP_Right", function() grid.move_to("right", true) end,
			{ description = "Move window right by bound", group = "Movement" }
		},
	}

	local layout_grid_resize = {
		{
			{ env.mod }, "h", function() grid.resize_to("left") end,
			{ description = "Inrease window size to the left", group = "Resize" }
		},
		{
			{ env.mod }, "j", function() grid.resize_to("down") end,
			{ description = "Inrease window size to the down", group = "Resize" }
		},
		{
			{ env.mod }, "k", function() grid.resize_to("up") end,
			{ description = "Inrease window size to the up", group = "Resize" }
		},
		{
			{ env.mod }, "l", function() grid.resize_to("right") end,
			{ description = "Inrease window size to the right", group = "Resize" }
		},
		{
			{ env.mod, "Shift" }, "h", function() grid.resize_to("left", nil, true) end,
			{ description = "Decrease window size from the left", group = "Resize" }
		},
		{
			{ env.mod, "Shift" }, "j", function() grid.resize_to("down", nil, true) end,
			{ description = "Decrease window size from the down", group = "Resize" }
		},
		{
			{ env.mod, "Shift" }, "k", function() grid.resize_to("up", nil, true) end,
			{ description = "Decrease window size from the up", group = "Resize" }
		},
		{
			{ env.mod, "Shift" }, "l", function() grid.resize_to("right", nil, true) end,
			{ description = "Decrease window size from the right", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "h", function() grid.resize_to("left", true) end,
			{ description = "Increase window size to the left by bound", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "j", function() grid.resize_to("down", true) end,
			{ description = "Increase window size to the down by bound", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "k", function() grid.resize_to("up", true) end,
			{ description = "Increase window size to the up by bound", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "l", function() grid.resize_to("right", true) end,
			{ description = "Increase window size to the right by bound", group = "Resize" }
		},
		{
			{ env.mod, "Control", "Shift" }, "h", function() grid.resize_to("left", true, true) end,
			{ description = "Decrease window size from the left by bound ", group = "Resize" }
		},
		{
			{ env.mod, "Control", "Shift" }, "j", function() grid.resize_to("down", true, true) end,
			{ description = "Decrease window size from the down by bound ", group = "Resize" }
		},
		{
			{ env.mod, "Control", "Shift" }, "k", function() grid.resize_to("up", true, true) end,
			{ description = "Decrease window size from the up by bound ", group = "Resize" }
		},
		{
			{ env.mod, "Control", "Shift" }, "l", function() grid.resize_to("right", true, true) end,
			{ description = "Decrease window size from the right by bound ", group = "Resize" }
		},
	}

	redflat.layout.grid:set_keys(layout_grid_move, "move")
	redflat.layout.grid:set_keys(layout_grid_resize, "resize")

	-- user map layout keys
	local layout_map_layout = {
		{
			{ env.mod }, "s", function() map.swap_group() end,
			{ description = "Change placement direction for group", group = "Layout" }
		},
		{
			{ env.mod }, "v", function() map.new_group(true) end,
			{ description = "Create new vertical group", group = "Layout" }
		},
		{
			{ env.mod }, "h", function() map.new_group(false) end,
			{ description = "Create new horizontal group", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "v", function() map.insert_group(true) end,
			{ description = "Insert new vertical group before active", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "h", function() map.insert_group(false) end,
			{ description = "Insert new horizontal group before active", group = "Layout" }
		},
		{
			{ env.mod }, "d", function() map.delete_group() end,
			{ description = "Destroy group", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "d", function() map.clean_groups() end,
			{ description = "Destroy all empty groups", group = "Layout" }
		},
		{
			{ env.mod }, "f", function() map.set_active() end,
			{ description = "Set active group", group = "Layout" }
		},
		{
			{ env.mod }, "g", function() map.move_to_active() end,
			{ description = "Move focused client to active group", group = "Layout" }
		},
		{
			{ env.mod, "Control" }, "f", function() map.hilight_active() end,
			{ description = "Hilight active group", group = "Layout" }
		},
		{
			{ env.mod }, "a", function() map.switch_active(1) end,
			{ description = "Activate next group", group = "Layout" }
		},
		{
			{ env.mod }, "q", function() map.switch_active(-1) end,
			{ description = "Activate previous group", group = "Layout" }
		},
		{
			{ env.mod }, "]", function() map.move_group(1) end,
			{ description = "Move active group to the top", group = "Layout" }
		},
		{
			{ env.mod }, "[", function() map.move_group(-1) end,
			{ description = "Move active group to the bottom", group = "Layout" }
		},
		{
			{ env.mod }, "r", function() map.reset_tree() end,
			{ description = "Reset layout structure", group = "Layout" }
		},
	}

	local layout_map_resize = {
		{
			{ env.mod }, "h", function() map.incfactor(nil, 0.1, false) end,
			{ description = "Increase window horizontal size factor", group = "Resize" }
		},
		{
			{ env.mod }, "l", function() map.incfactor(nil, -0.1, false) end,
			{ description = "Decrease window horizontal size factor", group = "Resize" }
		},
		{
			{ env.mod }, "k", function() map.incfactor(nil, 0.1, true) end,
			{ description = "Increase window vertical size factor", group = "Resize" }
		},
		{
			{ env.mod }, "j", function() map.incfactor(nil, -0.1, true) end,
			{ description = "Decrease window vertical size factor", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "h", function() map.incfactor(nil, 0.1, false, true) end,
			{ description = "Increase group horizontal size factor", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "l", function() map.incfactor(nil, -0.1, false, true) end,
			{ description = "Decrease group horizontal size factor", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "k", function() map.incfactor(nil, 0.1, true, true) end,
			{ description = "Increase group vertical size factor", group = "Resize" }
		},
		{
			{ env.mod, "Control" }, "j", function() map.incfactor(nil, -0.1, true, true) end,
			{ description = "Decrease group vertical size factor", group = "Resize" }
		},
	}

	redflat.layout.map:set_keys(layout_map_layout, "layout")
	redflat.layout.map:set_keys(layout_map_resize, "resize")


	-- Global keys
	--------------------------------------------------------------------------------
	self.raw.root = {
		{
			{ env.mod }, "F1", function() redtip:show() end,
			{ description = "Show hotkeys helper", group = "Main" }
		},
		{
			{ env.mod }, "F2", function () redflat.service.navigator:run() end,
			{ description = "Window control mode", group = "Main" }
		},
		{
			{ env.mod }, "c", function() redflat.float.keychain:activate(keyseq, "User") end,
			{ description = "User key sequence", group = "Main" }
		},
		{
			{ env.mod, "Control" }, "r", awesome.restart,
			{ description = "Reload awesome", group = "Main" }
		},

		{
			{ env.mod }, "Return", function() awful.spawn(env.terminal) end,
			{ description = "Open a terminal", group = "Applications" }
		},
		{
			{ env.mod }, "b", function() awful.spawn("chromium") end,
			{ description = "Open Chromium", group = "Applications" }
		},
		{
			{ env.mod }, "e", function() awful.spawn(env.terminal .. " -e ranger") end,
			{ description = "Open ranger", group = "Applications" }
		},
		{
			{ env.mod }, "x", function() awful.spawn(env.terminal .. " -e htop") end,
			{ description = "Open htop", group = "Applications" }
		},
		--[[{
			{ env.mod, "Mod1" }, "space", function() awful.spawn("clipflap --show") end,
			{ description = "Clipboard manager", group = "Applications" }
		},]]

		{
			{ env.mod }, "w", function() mainmenu:show() end,
			{ description = "Show main menu", group = "Widgets" }
		},
		{
			{ env.mod }, "r", function() apprunner:show() end,
			{ description = "Application launcher", group = "Widgets" }
		},
		{
			{ env.mod }, "p", function() redflat.float.prompt:run() end,
			{ description = "Show the prompt box", group = "Widgets" }
		},
		--[[{
			{ env.mod }, "F3", function() qlaunch:show() end,
			{ description = "Application quick launcher", group = "Widgets" }
		},]]

		{
			{ env.mod }, "Left", awful.tag.viewprev,
			{ description = "View previous tag", group = "Tag navigation" }
		},
		{
			{ env.mod }, "Right", awful.tag.viewnext,
			{ description = "View next tag", group = "Tag navigation" }
		},
		{
			{ env.mod }, "Escape", awful.tag.history.restore,
			{ description = "Go previos tag", group = "Tag navigation" }
		},
		{
			{ env.mod }, "t", function() global_add_tag():view_only() end,
			{ description = "Add new tag", group = "Tag navigation" }
		},
		
		--[[{
			{ env.mod }, "a", nil, function() appswitcher:show({ filter = current }) end,
			{ description = "Switch to next with current tag", group = "Application switcher" }
		},
		{
			{ env.mod }, "q", nil, function() appswitcher:show({ filter = current, reverse = true }) end,
			{ description = "Switch to previous with current tag", group = "Application switcher" }
		},
		{
			{ env.mod, "Shift" }, "a", nil, function() appswitcher:show({ filter = allscr }) end,
			{ description = "Switch to next through all tags", group = "Application switcher" }
		},
		{
			{ env.mod, "Shift" }, "q", nil, function() appswitcher:show({ filter = allscr, reverse = true }) end,
			{ description = "Switch to previous through all tags", group = "Application switcher" }
		},]]

		--[[{
			{ env.mod }, "t", function() redtitle.toggle(client.focus) end,
			{ description = "Show/hide titlebar for focused client", group = "Titlebar" }
		},
		{
			{ env.mod, "Control" }, "t", function() redtitle.switch(client.focus) end,
			{ description = "Switch titlebar view for focused client", group = "Titlebar" }
		},
		{
			{ env.mod, "Shift" }, "t", function() redtitle.toggle_all() end,
			{ description = "Show/hide titlebar for all clients", group = "Titlebar" }
		},
		{
			{ env.mod, "Control", "Shift" }, "t", function() redtitle.switch_all() end,
			{ description = "Switch titlebar view for all clients", group = "Titlebar" }
		},]]

		{
			{ env.mod}, "Up", function() awful.layout.inc(1) end,
			{ description = "Select next layout", group = "Layouts" }
		},
		{
			{ env.mod }, "Down", function() awful.layout.inc(-1) end,
			{ description = "Select previous layout", group = "Layouts" }
		},
		{
			{ env.mod }, "y", function() laybox:toggle_menu(mouse.screen.selected_tag) end,
			{ description = "Show layout menu", group = "Layouts" }
		},

		{
			{}, "XF86TouchpadToggle", toggle_hor_scroll,
			{ description = "Toggle horizontal scroll", group = "Misc" }
		},
		{
			{}, "Print", function() scrot(true, true) end,
			{ description = "scrot selection to clipboard", group = "Misc" }
		},
		{
			{ "Shift" }, "Print", function() scrot(false, true) end,
			{ description = "scrot to clipboard", group = "Misc" }
		},
		{
			{ "Control" }, "Print", function() scrot(true, false) end,
			{ description = "scrot selection to file", group = "Misc" }
		},
		{
			{ "Control", "Shift" }, "Print", function() scrot(false, false) end,
			{ description = "scrot to file", group = "Misc" }
		},
		{
			{ env.mod, "Control" }, "s", function() for s in screen do env.wallpaper(s) end end,
			{ description = "Refresh Wallpaper", group = "Misc" }
		},

		{
			{ env.mod }, "h", focus_switch_byd("left"),
			{ description = "Go to left client", group = "Client focus" }
		},
		{
			{ env.mod }, "j", focus_switch_byd("down"),
			{ description = "Go to lower client", group = "Client focus" }
		},
		{
			{ env.mod }, "k", focus_switch_byd("up"),
			{ description = "Go to upper client", group = "Client focus" }
		},
		{
			{ env.mod }, "l", focus_switch_byd("right"),
			{ description = "Go to right client", group = "Client focus" }
		},
		{
			{ env.mod }, "Tab", focus_to_previous,
			{ description = "Go to previos client", group = "Client focus" }
		},
		{
			{ env.mod }, "u", awful.client.urgent.jumpto,
			{ description = "Go to urgent client", group = "Client focus" }
		},
		{
			{ env.mod }, "s", stash_push,
			{ description = "Push current client to stash", group = "Client focus" }
		},
		{
			{ env.mod, "Shift" }, "s", stash_pop,
			{ description = "Pop from top of the stash to current tag", group = "Client focus" }
		},

		{
			{}, "XF86AudioRaiseVolume", volume_raise,
			{} -- hidden key
		},
		{
			{}, "XF86AudioLowerVolume", volume_lower,
			{} -- hidden key
		},
		{
			{}, "XF86AudioMute", volume_mute,
			{} -- hidden key
		},

		{
			{}, "XF86MonBrightnessUp", function() brightness({ step = 5 }) end,
			{} -- hidden key
		},
		{
			{}, "XF86MonBrightnessDown", function() brightness({ step = 5, down = true }) end,
			{} -- hidden key
		},

	}

	-- Client keys
	--------------------------------------------------------------------------------
	self.raw.client = {
		{
			{ env.mod, "Shift" }, "q", function(c) c:kill() end,
			{ description = "Close", group = "Client keys" }
		},
		{
			{ env.mod }, "f", function(c) c.fullscreen = not c.fullscreen; c:raise() end,
			{ description = "Toggle fullscreen", group = "Client keys" }
		},
		{
			{ env.mod, }, "g", awful.client.floating.toggle,
			{ description = "Toggle floating", group = "Client keys" }
		},
		{
			{ env.mod }, "m", function(c) c.maximized = not c.maximized; c:raise() end,
			{ description = "Maximize", group = "Client keys" }
		},
		{
			{ env.mod }, "n", function(c) c.minimized = true end,
			{ description = "Minimize", group = "Client keys" }
		},
		{
			{ env.mod, "Control" }, "o", function(c) c.ontop = not c.ontop end,
			{ description = "Toggle keep on top", group = "Client keys" }
		},
	}

	self.keys.root = redflat.util.key.build(self.raw.root)
	self.keys.client = redflat.util.key.build(self.raw.client)

	-- Numkeys
	--------------------------------------------------------------------------------

	-- add real keys without description here
	for i = 1, 10 do
		self.keys.root = awful.util.table.join(
			self.keys.root,
			tag_numkey(i,    { env.mod },                     function(t) t:view_only()                             end),
			tag_numkey(i,    { env.mod, "Control" },          function(t) awful.tag.viewtoggle(t)                   end),
			client_numkey(i, { env.mod, "Shift" },            function(t) client.focus:move_to_tag(t) t:view_only() end),
			client_numkey(i, { env.mod, "Control", "Shift" }, function(t) client.focus:toggle_tag(t)                end)
		)
	end

	-- use mod + \ to toggle telegram
	self.keys.root = awful.util.table.join(
		self.keys.root,
		awful.key({ env.mod }, "\\", telegram_key)
	)

	-- make fake keys with description special for key helper widget
	local numkeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

	self.fake.numkeys = {
		{
			{ env.mod }, "1..0", nil,
			{ description = "Switch to tag", group = "Numeric keys", keyset = numkeys }
		},
		{
			{ env.mod, "Control" }, "1..0", nil,
			{ description = "Toggle tag", group = "Numeric keys", keyset = numkeys }
		},
		{
			{ env.mod, "Shift" }, "1..0", nil,
			{ description = "Move focused client to tag", group = "Numeric keys", keyset = numkeys }
		},
		{
			{ env.mod, "Control", "Shift" }, "1..0", nil,
			{ description = "Toggle focused client on tag", group = "Numeric keys", keyset = numkeys }
		},
		{
			{ env.mod }, "\\", nil,
			{ description = "Toggle Telegram", group = "Numeric keys" }
		}
	}

	-- Hotkeys helper setup
	--------------------------------------------------------------------------------
	redflat.float.hotkeys:set_pack("Main", awful.util.table.join(self.raw.root, self.raw.client, self.fake.numkeys), 2)

	-- Mouse buttons
	--------------------------------------------------------------------------------
	self.mouse.client = awful.util.table.join(
		awful.button({         }, 1, function (c) client.focus = c; c:raise() end),
		awful.button({ env.mod }, 1, awful.mouse.client.move),
		awful.button({ env.mod }, 3, awful.mouse.client.resize),
		awful.button({ env.mod }, 2, function(c) c:kill() end)
	)

	-- Set root hotkeys
	--------------------------------------------------------------------------------
	root.keys(self.keys.root)
	root.buttons(self.mouse.root)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return hotkeys
