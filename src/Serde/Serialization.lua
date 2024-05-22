--!strict

local TypeId = require(script.Parent.Parent.TypeId)
local isArray = require(script.Parent.Parent.isArray)
local Writer = require(script.Parent.Parent.Buffer.Writer)
local Vlq = require(script.Parent.Parent.Vlq)

type Writer = Writer.Writer

local serializers = {}

local function serialize(writer: Writer.Writer, value: any)
	local valueType = typeof(value)

	local typeId, serializer
	if valueType == "table" then
		if isArray(value) then
			typeId = TypeId.fromType("array")
			serializer = serializers.array
		else
			typeId = TypeId.fromType("dictionary")
			serializer = serializers.dictionary
		end
	else
		typeId = TypeId.fromType(valueType)
		serializer = serializers[valueType]
	end

	if serializer == nil then
		error(`invalid type '{valueType}'`)
	else
		writer.writeu8(typeId)
		serializer(writer, value)
	end
end

function serializers.array(writer: Writer, value: {})
	Vlq.encode(writer, #value)

	for _, element in value do
		serialize(writer, element)
	end
end

function serializers.dictionary(writer: Writer, value: {})
	local keyCount = 0
	for _ in value do
		keyCount += 1
	end

	Vlq.encode(writer, keyCount)

	for key, element in value do
		serialize(writer, key)
		serialize(writer, element)
	end
end

serializers["nil"] = function() end

function serializers.string(writer: Writer, value: string)
	Vlq.encode(writer, #value)
	writer.writestring(value)
end

function serializers.number(writer: Writer, value: number)
	writer.writef64(value)
end

function serializers.boolean(writer: Writer, value: boolean)
	writer.writeu8(if value then 1 else 0)
end

function serializers.Vector2(writer: Writer, value: Vector2)
	writer.writef32(value.X)
	writer.writef32(value.Y)
end

function serializers.Vector3(writer: Writer, value: Vector3)
	writer.writef32(value.X)
	writer.writef32(value.Y)
	writer.writef32(value.Z)
end

function serializers.Vector2int16(writer: Writer, value: Vector2int16)
	writer.writei16(value.X)
	writer.writei16(value.Y)
end

function serializers.Vector3int16(writer: Writer, value: Vector3int16)
	writer.writei16(value.X)
	writer.writei16(value.Y)
	writer.writei16(value.Z)
end

function serializers.CFrame(writer: Writer, value: CFrame)
	local axis, angle = value:ToAxisAngle()
	axis *= angle

	writer.writef32(value.Position.X)
	writer.writef32(value.Position.Y)
	writer.writef32(value.Position.Z)
	writer.writef32(axis.X)
	writer.writef32(axis.Y)
	writer.writef32(axis.Z)
end

return {
	serializers = serializers,
	serialize = serialize,
}
