local Reader = require(script.Parent.Buffer.Reader)
local Writer = require(script.Parent.Buffer.Writer)
local Vlq = require(script.Parent.Vlq)

return function(x)
	local function check(length: number)
		local writer = Writer.new()

		Vlq.encode(writer, length)

		local b = writer.finish()

		local expectedBytes = math.max(math.ceil(math.log(length + 1, 128)), 1)

		assert(buffer.len(b) == expectedBytes, "buffer length didn't match expected bytes")

		local reader = Reader.new(b)

		assert(Vlq.decode(reader) == length, "lengths don't match")
	end

	x.test("check different lengths", function()
		check(0)
		check(60)
		check(127)
		check(128)
		check(240)
		check(523)
		check(3218932)
	end)
end
