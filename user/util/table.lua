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

function table_.val_to_str(v)
	if "string" == type(v) then
		v = string.gsub(v, "\n", "\\n")
		if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v, '"', '\\"') .. '"'
	else
		return "table" == type(v) and table_.tostring(v) or
			tostring(v)
	end
end

function table_.key_to_str(k)
	if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
		return k
	else
		return "[" .. table_.val_to_str(k) .. "]"
	end
end

function table_.tostring(tbl)
	local result, done = {}, {}
	for k, v in ipairs(tbl) do
		table.insert(result, table_.val_to_str(v))
		done[k] = true
	end
	for k, v in pairs(tbl) do
		if not done[k] then
			table.insert(result,
				table_.key_to_str(k) .. "=" .. table_.val_to_str(v)
			)
		end
	end
	return "{" .. table.concat(result, ",") .. "}"
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return table_
