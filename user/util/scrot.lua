local awful = require("awful")
local naughty = require("naughty")

local redflat = require("redflat")

local scrot = { mt = {} }
scrot.base_cmd = "sleep 0.2; scrot -z -q 100"
scrot.clip_cmd = "xclip -i -selection c -t image/png < $f"
scrot.imgdir = os.getenv("HOME") .. "/images/scrot/"

scrot.options = {
	full = "",
	selection = "-s ",
	focused = "-u ",
}

local function do_scrot(opt, clipboard)
	opt = opt or "selection"

	local path = clipboard and "/tmp/scrot.png" or scrot.imgdir .. "%Y-%m-%d_%T_scrot.png"
	local location = clipboard and "clipboard" or scrot.imgdir

	local cmd = string.format("%s %s%s --exec '%s' && notify-send 'scrot' 'Screenshot taken to %s'",
	                          scrot.base_cmd, scrot.options[opt], path, scrot.clip_cmd, location)
	awful.spawn.with_shell(cmd)
end

local function init()
	scrot.menu = redflat.menu({
		items = {
			{ "Fullscreen > clipboard", function() do_scrot("full",      true) end  },
			{ "Selection  > clipboard", function() do_scrot("selection", true) end  },
			{ "Focused    > clipboard", function() do_scrot("focused",   true) end  },
			{ "Fullscreen > ~/images",  function() do_scrot("full",      false) end },
			{ "Selection  > ~/images",  function() do_scrot("selection", false) end },
			{ "Focused    > ~/images",  function() do_scrot("focused",   false) end },
		}
	})
end

function scrot.mt:__call(show_menu)
	if not scrot.menu then
		init()
	end

	if show_menu then
		scrot.menu:show()
	else
		do_scrot("selection", true)
	end
end

return setmetatable(scrot, scrot.mt)
