local table = table

local awful = require("awful")
local laycommon = require("redflat.layout.common")

local tabbed = {}

local function is_master(rules, client)
	return awful.rules.matches(client, rules.master) or
	       not awful.rules.matches(client, rules.minor)
end

-- checks if the given tab contains a master client
local function has_master(rules, tab)
	for _, cl in ipairs(tab.clients) do
		if is_master(rules, cl) then return true end
	end
	return false
end

-- creates an iterator for all the tabs
local function tab_iterator(start)
	local tab = start
	local first = true

	return function()
		local r = tab
		tab = tab.next
		if first or r ~= start then
			first = false
			return r
		end
	end
end

-- create new tab between prev and next
local function create_tab(prev, next)
	local new_tab = { clients = {} }
	new_tab.prev = prev
	new_tab.next = next
	prev.next = new_tab
	next.prev = new_tab
	return new_tab
end

-- inserts a client into the given tab
local function insert_client(data, tab, client, first)
	if first then
		table.insert(tab.clients, 1, client)
	else
		table.insert(tab.clients, client)
	end
	data.managed_clients[client] = tab
end

-- removes a client from a tab
local function remove_client(data, tab, client)
	for i, v in ipairs(tab.clients) do
		if v == client then
			table.remove(tab.clients, i)
			break
		end
	end
	data.managed_clients[client] = nil

	if #tab.clients == 0 and tab ~= tab.next then
		if tab == data.first_tab then data.first_tab = tab.next end
		if tab == data.curr_tab then data.curr_tab = tab.next end
		tab.prev.next = tab.next
		tab.next.prev = tab.prev
	end
end

-- find the first master (if any) and moves it to first position
local function sort_clients(data, tab)
	-- exit if master is alredy in first position
	if #tab.clients < 1 or is_master(data.rules, tab.clients[1]) then
		return
	end

	-- find master client position
	local mi = nil
	for i, c in ipairs(tab.clients) do
		if is_master(data.rules, c) then
			mi = i
			break
		end
	end

	if mi then
		-- put clients[mi] in first position
		local master = tab.clients[mi]
		for i = mi, 2, -1 do
			tab.clients[i] = tab.clients[i-1]
		end
		tab.clients[1] = master
	end
end

-- inserts a master client into the first tab without a master
-- or creates a new tab
local function insert_master(data, current, client)
	local inserted = false

	-- search for first tab without master,
	-- insert client and set it as current
	for tab in tab_iterator(current) do
		if not has_master(data.rules, tab) then
			insert_client(data, tab, client, true)
			data.curr_tab = tab
			inserted = true
			break
		end
	end

	if not inserted then
		-- create new tab and add master client
		local new_tab = create_tab(current.prev, current)
		insert_client(data, new_tab, client, true)

		-- set new tab as first if needed
		if current == data.first_tab then
			data.first_tab = new_tab
		end

		-- set new tab as current
		data.curr_tab = new_tab
	end
end

local function arrange(data, param)
	-- insert all non managed clients
	for _, cl in ipairs(param.clients) do
		if not data.managed_clients[cl] then
			if is_master(data.rules, cl) then
				insert_master(data, data.curr_tab, cl)
			else
				insert_client(data, data.curr_tab, cl)
				sort_clients(data.curr_tab)
			end
		end
	end

	-- remove old/invalid clients
	for cl, tab in pairs(data.managed_clients) do
		if not cl.valid then
			remove_client(data, tab, cl)
		end
	end

	-- empty param.clients
	param.clients = {}

	-- reinsert clients into param
	for cl, tab in pairs(data.managed_clients) do
		if tab == data.curr_tab then
			cl.hidden = false
			table.insert(param.clients, cl)
		else
			cl.hidden = true
		end
	end

	-- call original layout arrange function
	return data.layout.arrange(param)
end

function tabbed:new(layout, master_rules, minor_rules)
	-- init new layout table
	local lay = { data = {} }
	
	-- set properties in data
	lay.data.layout = layout
	lay.data.managed_clients = {}
	lay.data.rules = {
		master = master_rules,
		minor = minor_rules,
	}
	
	-- create first tab
	local tab = { clients = {} }
	tab.next = tab
	tab.prev = tab
	lay.data.first_tab = tab
	lay.data.curr_tab = tab

	-- set layout attributes
	lay.key_handler = laycommon.handler[layout]
	lay.tip = laycommon.tips[layout]
	
	-- set layout arrange function
	function lay.arrange(param)
		return arrange(lay.data, param)
	end
	
	-- set layout mouse resize function
	function lay.mouse_resize_handler(...)
		return lay.data.layout.mouse_resize_handler(...)
	end

	-- set get state function
	function lay:get_state(selected)
		local states = {}

		for tab in tab_iterator(self.data.first_tab) do
			table.insert(states, { focus = (tab == self.data.curr_tab and selected) })
		end

		return states
	end

	-- switch to next or previout tab
	function lay:switch_tab(tag, reverse)
		if reverse then
			self.data.curr_tab = self.data.curr_tab.prev
		else
			self.data.curr_tab = self.data.curr_tab.next
		end

		-- force refresh
		tag:emit_signal("tagged")
	end

	-- move client to next or previous tab, creates new tab if requested
	function lay:client_to_tab(client, add_new_tab, reverse)
		local new_tab

		if add_new_tab then
			-- create new tab and switch to it
			if reverse then
				-- add before
				new_tab = create_tab(self.data.curr_tab.prev, self.data.curr_tab)
				-- set new tab as first if needed
				if self.data.first_tab == self.data.curr_tab then
					self.data.first_tab = new_tab
				end
			else
				-- add after
				new_tab = create_tab(self.data.curr_tab, self.data.curr_tab.next)
			end
		else
			-- set new tab to prev or next tab
			new_tab = reverse and self.data.curr_tab.prev or self.data.curr_tab.next
		end

		-- remove tab from curr tab
		remove_client(self.data, self.data.curr_tab, client)

		-- re-add client to new tab
		insert_client(self.data, new_tab, client)

		-- set new tab as current
		self.data.curr_tab = new_tab

		-- force refresh
		client:emit_signal("manage")
	end

	-- get missing values from original layout
	return setmetatable(lay, {
		__index = lay.data.layout
	})
end

return setmetatable(tabbed, {
	__call = function(...)
		return tabbed.new(...)
	end
})