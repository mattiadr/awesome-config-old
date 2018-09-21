local awful = require("awful")

local table_ = {}

-- Functions
-----------------------------------------------------------------------------------------------------------------------

-- Merge two awful.rules into one
------------------------------------------------------------
function table_.merge_rules(r1, r2)
	local ret = awful.util.table.clone(r1)

	for k, v in pairs(r2) do
		if type(v) == "table" and ret[k] and type(ret[k]) == "table" then
			for _, e in pairs(v) do
				table.insert(ret[k], e)
			end
		else
			ret[k] = v
		end
	end

	return ret
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return table_
