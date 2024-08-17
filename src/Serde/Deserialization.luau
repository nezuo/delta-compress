--!strict

local TypeId = require(script.Parent.Parent.TypeId)
local Reader = require(script.Parent.Parent.Buffer.Reader)
local Vlq = require(script.Parent.Parent.Vlq)

type Reader = typeof(Reader.new(buffer.create(0)))

local deserializers = {}

local function deserialize(reader: Reader)
	local typeId = reader.readu8()
	local type = TypeId.toType(typeId)

	return deserializers[type](reader)
end

function deserializers.array(reader: Reader): {}
	local length = Vlq.decode(reader)

	local array = {}
	for _ = 1, length do
		table.insert(array, deserialize(reader))
	end

	return array
end

function deserializers.dictionary(reader: Reader): {}
	local keyCount = Vlq.decode(reader)

	local dictionary = {}
	for _ = 1, keyCount do
		local key = deserialize(reader)
		local value = deserialize(reader)

		dictionary[key] = value
	end

	return dictionary
end

deserializers["nil"] = function(): nil
	return nil
end

function deserializers.string(reader: Reader): string
	local length = Vlq.decode(reader)
	local value = reader.readstring(length)

	return value
end

function deserializers.number(reader: Reader): number
	return reader.readf64()
end

function deserializers.boolean(reader: Reader): boolean
	return if reader.readu8() == 1 then true else false
end

function deserializers.Vector2(reader: Reader): Vector2
	local x = reader.readf32()
	local y = reader.readf32()

	return Vector2.new(x, y)
end

function deserializers.Vector3(reader: Reader): Vector3
	local x = reader.readf32()
	local y = reader.readf32()
	local z = reader.readf32()

	return Vector3.new(x, y, z)
end

function deserializers.Vector2int16(reader: Reader): Vector2int16
	local x = reader.readi16()
	local y = reader.readi16()

	return Vector2int16.new(x, y)
end

function deserializers.Vector3int16(reader: Reader): Vector3int16
	local x = reader.readi16()
	local y = reader.readi16()
	local z = reader.readi16()

	return Vector3int16.new(x, y, z)
end

function deserializers.CFrame(reader: Reader): CFrame
	local position = Vector3.new(reader.readf32(), reader.readf32(), reader.readf32())
	local axisAngle = Vector3.new(reader.readf32(), reader.readf32(), reader.readf32())

	local angle = axisAngle.Magnitude

	if angle ~= 0 then
		return CFrame.fromAxisAngle(axisAngle, angle) + position
	else
		return CFrame.new(position)
	end
end

return deserializers
