local io = io

local naughty = require("naughty")
local inspect = require("user/util/inspect")

local print = {}

-- print as notification
function print.n(obj)
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = inspect(obj),
	})
end

-- print to file
function print.f(obj)
	local f = io.open("/home/mattiadr/awesome_log", "a")
	io.output(f)
	io.write(inspect(obj))
	io.write("\n\n")
	io.close(f)
end

return print