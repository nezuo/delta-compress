local Apply = require(script.Apply)
local Diff = require(script.Diff)

--[=[
	@class DeltaCompress
]=]

return {
	diffImmutable = Diff.diffImmutable,
	diffMutable = Diff.diffMutable,
	applyImmutable = Apply.applyImmutable,
	applyMutable = Apply.applyMutable,
}
