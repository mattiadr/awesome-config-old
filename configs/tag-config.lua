-----------------------------------------------------------------------------------------------------------------------
--                                                      Tag config                                                   --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local table = table

local awful = require("awful")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local tagconf = {
	tags = {}
}

-- Add new tag
--------------------------------------------------------------------------------
function tagconf:add_tag(name, args)
	local tag = {}
	tag.real_tag = awful.tag.add(name, args)
	tag.index = 1
	tag.tabs = { {} }

	-- Switch to next tab if there is more than 1
	------------------------------------------------------------
	function tag:next_tab()
		-- if there is only one tab, do nothing
		if not (#self.tabs > 1) then return end

		-- get current clients
		local clients = self.real_tag:clients()
		if #clients > 0 then
			-- insert clients into current tab
			self.tabs[self.index] = { unpack(clients) }
			-- untag all clients
			for _, c in ipairs(clients) do c:tags({}) end
		end
		-- switch to next tab
		self.index = self.index + 1
		if self.index > #self.tabs then self.index = 1 end
		-- tag all clients in the new current tab
		for _, c in ipairs(self.tabs[self.index]) do c:tags({ self.real_tag }) end
	end

	-- Create new tab and switch to it
	------------------------------------------------------------
	function tag:new_tab()
		-- get current clients
		local clients = self.real_tag:clients()
		if #clients > 0 then
			-- insert clients into current tab
			self.tabs[self.index] = { unpack(clients) }
			-- untag all clients
			for _, c in ipairs(clients) do c:tags({}) end
			-- create new empty tab
			table.insert(self.tabs, self.index, {})
		end
	end

	table.insert(self.tags, tag)
end

-- Initialize tags
--------------------------------------------------------------------------------
function tagconf:init(s)
	-- TODO
	self:add_tag("1 MAIN", {
		layout   = awful.layout.suit.fair,
		screen   = s,
		selected = true,
	})

	self:add_tag("2", {
		layout   = awful.layout.suit.fair,
		screen   = s,
	})
	self:add_tag("3", {
		layout   = awful.layout.suit.fair,
		screen   = s,
	})
	self:add_tag("4", {
		layout   = awful.layout.suit.fair,
		screen   = s,
	})
	self:add_tag("5", {
		layout   = awful.layout.suit.fair,
		screen   = s,
	})
	self:add_tag("6", {
		layout   = awful.layout.suit.fair,
		screen   = s,
	})

	self:add_tag("TG", {
		layout   = awful.layout.suit.max,
		screen   = s,
	})
end

-- View n-th tag
--------------------------------------------------------------------------------
function tagconf:view_only(n)
	local curr_tag = awful.screen.focused().selected_tag
	local tag = awful.screen.focused().tags[n]

	if tag == curr_tag then
		-- switch to next "tab"
		self.tags[n]:next_tab()
	else
		-- switch to tag
		tag:view_only()
	end
end

-- Viewtoggle n-th tag
--------------------------------------------------------------------------------
function tagconf:viewtoggle(n)
	awful.screen.focused().tags[n]:viewtoggle()
end

-- Move client to n-th tag, optional create new tab
--------------------------------------------------------------------------------
function tagconf:client_move_to_tag(client, n, new_tab)
	local tag = self.tags[n]

	if new_tab then tag:new_tab() end

	local real_tag = awful.screen.focused().tags[n]
	client:move_to_tag(real_tag)
	real_tag:view_only()
end

-- Toggle n-th tag for client
--------------------------------------------------------------------------------
function tagconf:client_toggle_tag(client, n)
	local real_tag = awful.screen.focused().tags[n]
	client:toggle_tag(real_tag)
end

-- Get list of states for n-th tab
--------------------------------------------------------------------------------
function tagconf:get_tab_states(real_tag)
	for _, v in ipairs(self.tags) do
		if v.real_tag == real_tag then
			local states = {}
			for i = 1, #v.tabs do
				table.insert(states, { focus = false, urgent = false, minimized = false })
			end
			states[v.index].focus = true
			return states
		end
	end

	return { { focus = true, urgent = false, minimized = false } }
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return tagconf
