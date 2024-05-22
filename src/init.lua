local diff = require(script.diff)
local Apply = require(script.Apply)

return {
	diff = diff,
	applyImmutable = Apply.applyImmutable,
	applyMutable = Apply.applyMutable,
}
