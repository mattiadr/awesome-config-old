local awful = require("awful")

local tabbed = {}

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

	return data.layout.arrange(param)
end

function tabbed:new(layout)
	local lay = { data = {} }
	lay.data.layout = layout

	lay.name = layout.name

	function lay.arrange(param)
		return tabbed.arrange(lay.data, param)
	end

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