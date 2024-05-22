--!strict

local Writer = {}

function Writer.new()
	local b = buffer.create(100)
	local offset = 0

	local writer = {}

	local function resize(targetSize: number)
		if buffer.len(b) >= targetSize then
			return
		end

		local newSize = math.ceil(targetSize * 1.5)
		local newBuffer = buffer.create(newSize)

		buffer.copy(newBuffer, 0, b)

		b = newBuffer
	end

	function writer.writeu8(value: number)
		resize(offset + 1)
		buffer.writeu8(b, offset, value)
		offset += 1
	end

	function writer.writeu16(value: number)
		resize(offset + 2)
		buffer.writeu16(b, offset, value)
		offset += 2
	end

	function writer.writeu32(value: number)
		resize(offset + 4)
		buffer.writeu32(b, offset, value)
		offset += 4
	end

	function writer.writei16(value: number)
		resize(offset + 2)
		buffer.writei16(b, offset, value)
		offset += 2
	end

	function writer.writef32(value: number)
		resize(offset + 4)
		buffer.writef32(b, offset, value)
		offset += 4
	end

	function writer.writef64(value: number)
		resize(offset + 8)
		buffer.writef64(b, offset, value)
		offset += 8
	end

	function writer.writestring(value: string)
		resize(offset + #value)
		buffer.writestring(b, offset, value)
		offset += #value
	end

	function writer.finish(): buffer?
		local final = buffer.create(offset)

		buffer.copy(final, 0, b, 0, offset)

		return final
	end

	return writer
end

export type Writer = typeof(Writer.new())

return Writer
