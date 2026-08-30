--!strict
-- Small dependency-free table helpers shared across server and client.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in (value :: any) do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (copy :: any) :: T
end

-- Recursively fills any keys missing from `target` with the value from
-- `defaults`, without overwriting anything the target already has. Used by
-- the data schema/migration system so old save files gain new fields with
-- sane defaults instead of erroring on nil-index.
function TableUtil.reconcile(target: { [any]: any }, defaults: { [any]: any }): { [any]: any }
	for key, defaultValue in defaults do
		local existing = target[key]
		if existing == nil then
			target[key] = TableUtil.deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(existing) == "table" then
			TableUtil.reconcile(existing, defaultValue)
		end
	end
	return target
end

function TableUtil.freeze<T>(value: T): T
	if type(value) == "table" then
		for _, v in (value :: any) do
			TableUtil.freeze(v)
		end
		table.freeze(value :: any)
	end
	return value
end

return TableUtil
