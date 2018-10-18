-----------------------------------------------------------------------------------------------------------------------
--                                                      Tag config                                                   --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local table = table

local awful = require("awful")

local pn = require("user/util/print").n

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local tagconf = {
	disable_signal = false,
	taglist = {},
	rules = {},
	rules_any = {},
}

local valid_layouts = {
	awful.layout.suit.tile,
	awful.layout.suit.tile.left,
	awful.layout.suit.tile.top,
	awful.layout.suit.tile.bottom,
}

-- Util functions
-----------------------------------------------------------------------------------------------------------------------

-- Check if the layout of the tag can be tagged
--------------------------------------------------------------------------------
local function check_layout(real_tag)
	for _, v in ipairs(valid_layouts) do
		if real_tag.layout == v then return true end
	end
	return false
end

-- Checks if the client matches any minor rule
--------------------------------------------------------------------------------
local function is_minor(c)
	for _, v in ipairs(tagconf.rules) do
		if awful.rules.match(c, v) then return true end
	end

	return awful.rules.match_any(c, tagconf.rules_any)
end

-- Check if a list has a client that isn't minor
--------------------------------------------------------------------------------
local function has_master(tab)
	for _, v in ipairs(tab) do
		if not is_minor(v) then return true end
	end
	return false
end

-- Control functions
-----------------------------------------------------------------------------------------------------------------------

-- Add a specific rule that has to match
--------------------------------------------------------------------------------
function tagconf:add_specific_rule(rule)
	table.insert(self.rules, rule)
end

-- Set rules that have to match_any
--------------------------------------------------------------------------------
function tagconf:set_rules_any(rules)
	self.rules_any = rules
end

-- Enable tabs for a certain tag
--------------------------------------------------------------------------------
function tagconf:set_tabbed(real_tag)
	if not check_layout(real_tag) then return end

	local tabs = {
		{ selected = true }
	}

	-- when a client gets tagged add it to a tab without a master
	real_tag:connect_signal("tagged", function(t, c)
		if self.disable_signal or not c then return end

		if not is_minor(c) then
			-- set c as master
			awful.client.setmaster(c)
			-- put all current clients except c into current tab
			local curr_tab = nil
			for i, tab in ipairs(tabs) do
				if tab.selected then
					curr_tab = i
					break
				end
			end

			-- empty current tab
			for i, _ in ipairs(tabs[curr_tab]) do tabs[curr_tab][i] = nil end
			-- all except c into current tab
			for _, v in ipairs(t:clients()) do
				if c ~= v then table.insert(tabs[curr_tab], v) end
			end

			-- choose and insert c into the appropriate tab
			local new_tab = nil
			for i = 0, #tabs-1 do
				local j = curr_tab+i > #tabs and curr_tab+i-#tabs or curr_tab+i
				if not has_master(tabs[j]) then
					new_tab = j
					break
				end
			end

			-- we don't need to switch tab
			if new_tab == curr_tab then return end

			-- deselect current tab
			tabs[curr_tab].selected = false

			-- create new tab if needed
			if new_tab then
				curr_tab = new_tab
			else
				table.insert(tabs, curr_tab, {})
			end
			-- add c to the new tab
			table.insert(tabs[curr_tab], 1, c)

			-- select current tab
			tabs[curr_tab].selected = true

			-- set clients for real_tag
			t:clients({ unpack(tabs[curr_tab]) })
		end
	end)

	-- when a client gets untagged remove any empty tabs
	real_tag:connect_signal("untagged", function(t, c)
		if self.disable_signal then return end

		for i = #tabs, 1, -1 do
			if tabs[i].selected then
				-- remove c from current tab
				for j, c1 in ipairs(tabs[i]) do
					if c == c1 then table.remove(tabs[i], j) end
				end
			end

			if #tabs > 1 and #tabs[i] == 0 then
				if tabs[i].selected then
					-- find next tab, select and activate it
					local j = i+1 > #tabs and 1 or i+1
					tabs[j].selected = true
					t:clients({ unpack(tabs[j]) })
				end
				table.remove(tabs, i)
			end
		end
	end)

	self.taglist[real_tag] = tabs
end

-- Switches to the next tab, dir should be set to 1 or -1
--------------------------------------------------------------------------------
function tagconf:switch_tab(real_tag, dir)
	self.disable_signal = true

	dir = dir or 1

	local tabs = self.taglist[real_tag]

	if not tabs or #tabs <= 1 then return end

	local curr_tab = nil
	for i, tab in ipairs(tabs) do
		if tab.selected then
			-- empty current tab
			for j, _ in ipairs(tab) do tab[j] = nil end
			-- put current clients into current tab
			for _, v in ipairs(real_tag:clients()) do table.insert(tab, v) end
			-- deselect tab
			tab.selected = false
			curr_tab = i
			break
		end
	end

	curr_tab = curr_tab + dir
	if curr_tab < 1 then curr_tab = #tabs end
	if curr_tab > #tabs then curr_tab = 1 end

	-- select new tab
	tabs[curr_tab].selected = true
	real_tag:clients({ unpack(tabs[curr_tab]) })

	self.disable_signal = false
end

-- Moves the client to the next tab, dir should be set to 1 or -1
--------------------------------------------------------------------------------
function tagconf:client_to_tab(real_tag, c, dir, switch_to_tab)
	self.disable_signal = true

	dir = dir or 1

	local tabs = self.taglist[real_tag]

	if not tabs then return end

	local curr_tab = nil
	for i, tab in ipairs(tabs) do
		if tab.selected then
			-- empty current tab
			for j, _ in ipairs(tab) do tab[j] = nil end
			-- put current clients into current tab
			for _, v in ipairs(real_tag:clients()) do table.insert(tab, v) end
			-- set current tag
			curr_tab = i
			break
		end
	end
	local old_tab = curr_tab

	-- create new tab if needed
	if #tabs <= 1 then
		curr_tab = dir == 1 and 2 or 1
		table.insert(tabs, curr_tab, {})
	else
		curr_tab = curr_tab + dir
		if curr_tab < 1 then curr_tab = #tabs end
		if curr_tab > #tabs then curr_tab = 1 end
	end

	table.insert(tabs[curr_tab], c)
	c:tags({})

	-- switch to tab and remove current tab if needed
	if #real_tag:clients() == 0 then
		self:switch_tab(real_tag, dir)
		table.remove(tabs, old_tab)
	elseif switch_to_tab then
		self:switch_tab(real_tag, dir)
	end

	self.disable_signal = false
end

-- Get list of states for real_tag
--------------------------------------------------------------------------------
function tagconf:get_tab_states(real_tag)
	local tabs = self.taglist[real_tag]

	if tabs then
		local states = {}
		for _, v in ipairs(tabs) do
			table.insert(states, { focus = v.selected and real_tag.selected })
		end
		return states
	else
		return { { focus = real_tag.selected } }
	end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return tagconf
