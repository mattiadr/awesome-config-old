local naughty = require("naughty")

local print = {}

-- convert table to string
local function tts(t)
	if type(t) ~= "table" then
		return tostring(t)
	end

	local str = ""
	for key, value in pairs(t) do
		str = str .. "\n" .. tostring(key) .. ": " .. tostring(value)
	end
	return str
end

-- print as notification
function print.n(obj)
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = tts(obj),
	})
end

-- print to file
function print.f(obj)
	local f = io.open("/home/mattiadr/awesome_log", "a")
	io.output(f)
	io.write(tts(obj))
	io.write("\n\n")
	io.close(f)
end

return print