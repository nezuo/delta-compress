--!strict

local Reader = require(script.Parent.Buffer.Reader)
local Writer = require(script.Parent.Buffer.Writer)

type Writer = Writer.Writer
type Reader = Reader.Reader

local Vlq = {}

function Vlq.encode(writer: Writer, length: number)
	repeat
		local byte = bit32.band(length, 0x7f)
		length = bit32.rshift(length, 7)

		if length > 0 then
			byte = bit32.bor(byte, 0x80)
		end

		writer.writeu8(byte)
	until length == 0
end

function Vlq.decode(reader: Reader): number
	local length = 0
	local shift = 0
	local byte

	repeat
		byte = reader.readu8()
		length = bit32.bor(length, bit32.lshift(bit32.band(byte, 0x7F), shift))
		shift = shift + 7
	until bit32.band(byte, 0x80) == 0

	return length
end

return Vlq
