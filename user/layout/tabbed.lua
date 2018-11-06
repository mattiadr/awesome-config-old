local awful = require("awful")

local tabbed = {}

-- create a new tab and position it before the arg
local function new_tab(after)
	local tab = { clients = {} }

	if after then
		tab.prev = after.prev
		tab.next = after
	else
		tab.prev = tab
		tab.next = tab
	end

	return tab
end

function tabbed.arrange(data, param)
	--[[ param
	screen: 1
	useless_gap: 0
	clients: { 1: window/client, 2: window/client }
	workarea: { x: 0, y: 0, width: 1920, height: 1044 }
	padding: { left: 0, right: 0, top: 0, bottom: 0 }
	geometry: { x: 0, y: 0, width: 1920, height: 1080 }
	geometries: {}
	--]]

	-- for _, cl in ipairs(param.clients) do
	-- 	if not data.clients[cl] then
	-- 		-- add cl to data.client
	-- 		data.clients[cl] = curr_tab
	-- 	end
	-- end

	-- -- reinsert clients into param
	-- param.clients = {}
	-- for cl, tab in pairs(data.clients) do
	-- 	if not cl.valid then
	-- 		-- rempove client from data if window is no longer valid
	-- 		param.clients[cl] = nil
	-- 	elseif tab == data.curr_tab then
	-- 		table.insert(param.clients, cl)
	-- 		cl.hidden = false
	-- 	else
	-- 		cl.hidden = true
	-- 	end
	-- end

	-- call original layout arrange function
	return data.layout.arrange(param)
end

function tabbed:new(layout)
	-- init new layout table
	local lay = { data = { first_tab = nil, curr_tab = nil } }
	
	-- set properties in data
	lay.data.layout = layout
	lay.data.clients = {}
	setmetatable(lay.data.clients, { __mode = "k" })
	
	-- set layout name
	lay.name = layout.name
	
	-- set layout arrange function
	function lay.arrange(param)
		return tabbed.arrange(lay.data, param)
	end
	
	-- set layout mouse resize function
	function lay.mouse_resize_handler(...)
		return lay.data.layout.mouse_resize_handler(...)
	end

	return lay
end

return setmetatable(tabbed, {
	__call = function(...)
		return tabbed.new(...)
	end
})