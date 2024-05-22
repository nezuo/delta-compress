--!strict

local types = {
	"nil",
	"string",
	"number",
	"boolean",
	"Vector2",
	"Vector3",
	"Vector2int16",
	"Vector3int16",
	"CFrame",
	"array",
	"dictionary",
	"arrayRemovals",
	"arrayAdditions",
	"arrayChanges",
	"arrayChangesRemovals",
	"arrayChangesAdditions",
	"dictionaryChanges",
	"dictionaryRemovals",
	"dictionaryRemovalsChanges",
}

local typeToId = {}
for id, type in types do
	typeToId[type] = id
end

local TypeId = {}

function TypeId.isArrayDiff(typeId: number): boolean
	return typeId == typeToId["arrayRemovals"]
		or typeId == typeToId["arrayAdditions"]
		or typeId == typeToId["arrayChanges"]
		or typeId == typeToId["arrayChangesRemovals"]
		or typeId == typeToId["arrayChangesAdditions"]
end

function TypeId.isDictionaryDiff(typeId: number): boolean
	return typeId == typeToId["dictionaryChanges"]
		or typeId == typeToId["dictionaryRemovals"]
		or typeId == typeToId["dictionaryRemovalsChanges"]
end

function TypeId.toType(typeId: number): string
	return types[typeId]
end

function TypeId.fromType(type: string): number
	return typeToId[type]
end

return TypeId
