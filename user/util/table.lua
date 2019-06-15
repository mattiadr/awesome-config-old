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

-- Replace the content of a table with another
------------------------------------------------------------
function table_.replace_with(t1, t2)
	-- empty table 1
	for k, _ in pairs(t1) do t1[k] = nil end
	-- copy all values of table 2 to table 1
	for k, _ in pairs(t2) do t1[k] = t2[k] end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return table_
