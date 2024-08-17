--!strict

local Reader = {}

function Reader.new(b: buffer)
	local offset = 0

	local reader = {}

	function reader.readu8()
		local value = buffer.readu8(b, offset)
		offset += 1
		return value
	end

	function reader.readu16()
		local value = buffer.readu16(b, offset)
		offset += 2
		return value
	end

	function reader.readu32()
		local value = buffer.readu32(b, offset)
		offset += 4
		return value
	end

	function reader.readi16()
		local value = buffer.readi16(b, offset)
		offset += 2
		return value
	end

	function reader.readf32()
		local value = buffer.readf32(b, offset)
		offset += 4
		return value
	end

	function reader.readf64()
		local value = buffer.readf64(b, offset)
		offset += 8
		return value
	end

	function reader.readstring(length: number)
		local value = buffer.readstring(b, offset, length)
		offset += length
		return value
	end

	return reader
end

export type Reader = typeof(Reader.new(buffer.create(0)))

return Reader
