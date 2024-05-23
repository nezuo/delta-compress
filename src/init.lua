local diff = require(script.diff)
local Apply = require(script.Apply)

--[=[
	@class DeltaCompress
]=]

return {
	diff = diff,
	applyImmutable = Apply.applyImmutable,
	applyMutable = Apply.applyMutable,
}
