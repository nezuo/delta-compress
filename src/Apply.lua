--!strict

local Reader = require(script.Parent.Buffer.Reader)
local Deserialization = require(script.Parent.Serde.Deserialization)
local TypeId = require(script.Parent.TypeId)
local Vlq = require(script.Parent.Vlq)
local isArray = require(script.Parent.isArray)

type Reader = Reader.Reader

local applyDictionary
local applyArray

local function deserialize(reader: Reader)
	local typeId = reader.readu8()
	local type = TypeId.toType(typeId)

	return Deserialization[type](reader)
end

local function applyValue(reader: Reader, type: string, old: any, immutable: boolean)
	local new = Deserialization[type](reader)

	if immutable then
		return new
	end

	if typeof(old) ~= "table" or typeof(new) ~= "table" then
		return new
	end

	if isArray(new) then
		table.clear(old)

		for i, value in new do
			old[i] = value
		end
	else
		table.clear(old)

		for key, value in new do
			old[key] = value
		end
	end

	return old
end

local function applyChange(reader: Reader, old: {}, new: {}, key: any, immutable: boolean)
	local typeId = reader.readu8()
	local changeType = TypeId.toType(typeId)

	if TypeId.isArrayDiff(typeId) then
		new[key] = applyArray(reader, changeType, old[key], immutable)
	elseif TypeId.isDictionaryDiff(typeId) then
		new[key] = applyDictionary(reader, changeType, old[key], immutable)
	else
		new[key] = applyValue(reader, changeType, old[key], immutable)
	end
end

function applyArray(reader: Reader, arrayType: string, old: {}, immutable: boolean): {}
	local hasRemovals = arrayType == "arrayRemovals" or arrayType == "arrayChangesRemovals"
	local hasAdditions = arrayType == "arrayAdditions" or arrayType == "arrayChangesAdditions"
	local hasChanges = arrayType ~= "arrayRemovals" and arrayType ~= "arrayAdditions"

	local removals = if hasRemovals then Vlq.decode(reader) else 0
	local additions = if hasAdditions then Vlq.decode(reader) else 0

	local new = if immutable then table.create(#old - removals + additions) else old

	if immutable then
		table.move(old, 1, #old - removals, 1, new)
	end

	if hasRemovals and not immutable then
		for _ = 1, removals do
			table.remove(new, #new)
		end
	end

	if hasAdditions then
		for _ = 1, additions do
			table.insert(new, deserialize(reader))
		end
	end

	if hasChanges then
		local changeCount = Vlq.decode(reader)

		for _ = 1, changeCount do
			local index = Vlq.decode(reader)

			applyChange(reader, old, new, index, immutable)
		end
	end

	return new
end

function applyDictionary(reader: Reader.Reader, dictionaryType: string, old: {}, immutable: boolean): {}
	local new = if immutable then table.clone(old) else old

	local hasRemovals = dictionaryType ~= "dictionaryChanges"
	local hasChanges = dictionaryType ~= "dictionaryRemovals"

	if hasRemovals then
		local count = Vlq.decode(reader)

		for _ = 1, count do
			local key = deserialize(reader)

			new[key] = nil
		end
	end

	if hasChanges then
		local count = Vlq.decode(reader)

		for _ = 1, count do
			local key = deserialize(reader)

			applyChange(reader, old, new, key, immutable)
		end
	end

	return new
end

local function apply(old: {}, diff: buffer, immutable: boolean): any
	local reader = Reader.new(diff)

	local typeId = reader.readu8()
	local type = TypeId.toType(typeId)

	if TypeId.isDictionaryDiff(typeId) then
		return applyDictionary(reader, type, old, immutable)
	elseif TypeId.isArrayDiff(typeId) then
		return applyArray(reader, type, old, immutable)
	else
		return applyValue(reader, type, old, immutable)
	end
end

--[=[
	Applies a diff created by [DeltaCompress.diff] immutably. The `old` value passed won't mutated, instead, a new value will be returned.

	```lua
	local old = { coins = 10, completedTutorial = true }
	local new = { coins = 320, completedTutorial = true }
	local diff = DeltaCompress.diff(old, new)

	local applied = DeltaCompress.applyImmutable(old, diff)

	print(applied) -- { coins = 320, completedTutorial = true }

	-- `old` didn't change since the diff was applied immutably.
	print(old) -- { coins = 10, completedTutorial = true }
	```

	@within DeltaCompress
	@param old any
	@param diff buffer
	@return any
]=]
local function applyImmutable(old: any, diff: buffer): any
	return apply(old, diff, true)
end

--[=[
	Applies a diff created by [DeltaCompress.diff] mutably. The `old` value passed will be mutated.

	```lua
	local old = { coins = 10, completedTutorial = true }
	local new = { coins = 320, completedTutorial = true }
	local diff = DeltaCompress.diff(old, new)

	local applied = DeltaCompress.applyMutable(old, diff)

	print(applied) -- { coins = 320, completedTutorial = true }

	-- `old` was mutated and returned, `applied` and `old` are the same table.
	print(applied == old) -- true
	```

	Though tables are updated mutably, other data types have to be returned from the function:
	```lua
	local old = 100
	local new = "hello"
	local diff = DeltaCompress.diff(old, new)

	local applied = DeltaCompress.applyMutable(old, diff)

	print(applied) -- "hello"
	```

	@within DeltaCompress
	@param old any
	@param diff buffer
	@return any
]=]
local function applyMutable(old: any, diff: buffer): any
	return apply(old, diff, false)
end

return {
	applyImmutable = applyImmutable,
	applyMutable = applyMutable,
}
