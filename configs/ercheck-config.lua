local naughty = require("naughty")

critical_no_timeout = naughty.config.presets.critical
critical_no_timeout.timeout = 0

if awesome.startup_errors then
	naughty.notify({
		preset = critical_no_timeout,
		title  = "Oops, there were errors during startup!",
		text   = awesome.startup_error
	})
end

do
	local in_error = false
	awesome.connect_signal(
		"debug::error",
		function (err)
			if in_error then return end
			in_error = true

			naughty.notify({
				preset  = critical_no_timeout,
				title   = "Oops, an error happened!",
				text    = err
			})
			in_error = false
		end
	)
end
