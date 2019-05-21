local awful = require("awful")
local beautiful = require("beautiful")

local sl = {}
sl.path = "/tmp/i3lock_img.png"
sl.cmd = {
	img_edit   = [[corrupter -mag 3 -boffset 10 -meanabber 5 "%s" ]] .. sl.path,
	lock_color = "i3lock -p default -c %s",
	lock_img   = "i3lock -p default -i " .. sl.path,
}

function sl.convert_wallpaper(wallpaper)
	awful.spawn(string.format(sl.cmd.img_edit, wallpaper))
end

function sl.lock_screen()
	if type(beautiful.wallpaper) == "string" then
		if string.sub(beautiful.wallpaper, 1, 1) == "#" then
			awful.spawn(string.format(sl.cmd.lock_color, beautiful.wallpaper))
		else
			awful.spawn(sl.cmd.lock_img)
		end
	end
end

return sl
