--!strict

local TypeId = require(script.Parent.TypeId)
local Vlq = require(script.Parent.Vlq)
local isArray = require(script.Parent.isArray)
local Writer = require(script.Parent.Buffer.Writer)
local Serialization = require(script.Parent.Serde.Serialization)

type Writer = Writer.Writer

type ArrayDiff = {
	removals: number,
	additions: { any },
	changes: { [number]: any },
	arrayDiffs: { [number]: ArrayDiff },
	dictionaryDiffs: { [number]: DictionaryDiff },
	changeCount: number,
}

type DictionaryDiff = {
	removals: { [any]: boolean },
	removalCount: number,
	changes: { [any]: any },
	arrayDiffs: { [any]: ArrayDiff },
	dictionaryDiffs: { [any]: DictionaryDiff },
	changeCount: number,
}

local diffDictionary, diffArray
local writeArrayDiff, writeDictionaryDiff

local function diffValue(
	oldValue: any,
	newValue: any,
	key: any,
	arrayDiffs: { [number]: ArrayDiff },
	dictionaryDiffs: { [number]: DictionaryDiff },
	changes: { [number]: any }
): boolean
	if typeof(oldValue) ~= "table" or typeof(newValue) ~= "table" then
		if oldValue ~= newValue then
			changes[key] = newValue
			return true
		end

		return false
	end

	if isArray(oldValue) and isArray(newValue) then
		local diff = diffArray(oldValue, newValue)

		if diff then
			arrayDiffs[key] = diff
			return true
		else
			return false
		end
	elseif not isArray(oldValue) and not isArray(newValue) then
		local diff = diffDictionary(oldValue, newValue)

		if diff then
			dictionaryDiffs[key] = diff
			return true
		else
			return false
		end
	else
		changes[key] = newValue
		return true
	end
end

function diffArray(old: {}, new: {}): ArrayDiff?
	if old == new then
		return nil
	end

	local removals = 0
	local additions = {}

	if #old > #new then
		removals = #old - #new
	elseif #new > #old then
		for i = #old + 1, #new do
			table.insert(additions, new[i])
		end
	end

	local changes = {}
	local arrayDiffs = {}
	local dictionaryDiffs = {}
	local changeCount = 0

	for i = 1, math.min(#old, #new) do
		local oldValue = old[i]
		local newValue = new[i]

		if diffValue(oldValue, newValue, i, arrayDiffs, dictionaryDiffs, changes) then
			changeCount += 1
		end
	end

	if removals > 0 or #additions > 0 or changeCount > 0 then
		return {
			removals = removals,
			additions = additions,
			changes = changes,
			arrayDiffs = arrayDiffs,
			dictionaryDiffs = dictionaryDiffs,
			changeCount = changeCount,
		}
	end

	return nil
end

function diffDictionary(old: {}, new: {}): DictionaryDiff?
	if old == new then
		return nil
	end

	local removals = {}
	local removalCount = 0
	for key in old do
		if new[key] == nil then
			removals[key] = true
			removalCount += 1
		end
	end

	local changes = {}
	local arrayDiffs = {}
	local dictionaryDiffs = {}
	local changeCount = 0

	for key, newValue in new do
		local oldValue = old[key]

		if diffValue(oldValue, newValue, key, arrayDiffs, dictionaryDiffs, changes) then
			changeCount += 1
		end
	end

	if removalCount > 0 or changeCount > 0 then
		return {
			removals = removals,
			removalCount = removalCount,
			changes = changes,
			arrayDiffs = arrayDiffs,
			dictionaryDiffs = dictionaryDiffs,
			changeCount = changeCount,
		}
	end

	return nil
end

function writeArrayDiff(writer: Writer, arrayDiff: ArrayDiff)
	local removals = arrayDiff.removals
	local additions = arrayDiff.additions
	local changeCount = arrayDiff.changeCount

	local function writeRemovals()
		Vlq.encode(writer, removals)
	end

	local function writeAdditions()
		Vlq.encode(writer, #additions)

		for _, addition in additions do
			Serialization.serialize(writer, addition)
		end
	end

	local function writeChanges()
		Vlq.encode(writer, changeCount)

		for i, change in arrayDiff.changes do
			Vlq.encode(writer, i)
			Serialization.serialize(writer, change)
		end

		for i, nestedArrayDiff in arrayDiff.arrayDiffs do
			Vlq.encode(writer, i)
			writeArrayDiff(writer, nestedArrayDiff)
		end

		for i, dictionaryDiff in arrayDiff.dictionaryDiffs do
			Vlq.encode(writer, i)
			writeDictionaryDiff(writer, dictionaryDiff)
		end
	end

	if changeCount > 0 then
		if removals > 0 then
			writer.writeu8(TypeId.fromType("arrayChangesRemovals"))
			writeRemovals()
			writeChanges()
		elseif #additions > 0 then
			writer.writeu8(TypeId.fromType("arrayChangesAdditions"))
			writeAdditions()
			writeChanges()
		else
			writer.writeu8(TypeId.fromType("arrayChanges"))
			writeChanges()
		end
	elseif removals > 0 then
		writer.writeu8(TypeId.fromType("arrayRemovals"))
		writeRemovals()
	elseif #additions > 0 then
		writer.writeu8(TypeId.fromType("arrayAdditions"))
		writeAdditions()
	end
end

function writeDictionaryDiff(writer: Writer, dictionaryDiff: DictionaryDiff)
	local removalCount = dictionaryDiff.removalCount
	local changeCount = dictionaryDiff.changeCount

	local typeId = TypeId.fromType(
		if removalCount > 0 and changeCount > 0
			then "dictionaryRemovalsChanges"
			else if removalCount > 0 then "dictionaryRemovals" else "dictionaryChanges"
	)

	writer.writeu8(typeId)

	if removalCount > 0 then
		Vlq.encode(writer, removalCount)
	end

	for key in dictionaryDiff.removals do
		Serialization.serialize(writer, key)
	end

	if changeCount > 0 then
		Vlq.encode(writer, changeCount)
	end

	for key, value in dictionaryDiff.changes do
		Serialization.serialize(writer, key)
		Serialization.serialize(writer, value)
	end

	for key, nestedArrayDiff in dictionaryDiff.arrayDiffs do
		Serialization.serialize(writer, key)
		writeArrayDiff(writer, nestedArrayDiff)
	end

	for key, nestedDictionaryDiff in dictionaryDiff.dictionaryDiffs do
		Serialization.serialize(writer, key)
		writeDictionaryDiff(writer, nestedDictionaryDiff)
	end
end

--[=[
	Calculates the difference between `old` and `new` and returns it as a `buffer`. If `old` and `new` are identical, it returns `nil`.

	```lua
	local old = { coins = 10, completedTutorial = true }
	local new = { coins = 320, completedTutorial = true }

	local diff = DeltaCompress.diff(old, new) -- Returns a buffer that encodes the change in coins.
	```

	@within DeltaCompress
	@param old any
	@param new any
	@return buffer? -- A buffer representing the difference, or `nil` if there are no differences.
]=]
local function diff(old: any, new: any): buffer?
	local writer = Writer.new()

	if typeof(old) == "table" and typeof(new) == "table" then
		if isArray(old) then
			if not isArray(new) then
				Serialization.serialize(writer, new)
			else
				local arrayDiff = diffArray(old, new)

				if arrayDiff ~= nil then
					writeArrayDiff(writer, arrayDiff)
				else
					return nil
				end
			end
		else
			if isArray(new) then
				Serialization.serialize(writer, new)
			else
				local dictionaryDiff = diffDictionary(old, new)

				if dictionaryDiff ~= nil then
					writeDictionaryDiff(writer, dictionaryDiff)
				else
					return nil
				end
			end
		end

		return writer.finish()
	else
		Serialization.serialize(writer, new)

		return writer.finish()
	end
end

return diff
