--!strict
--!optimize 2
-- CRC32 implementation in Luau (exactly matches zlib.crc32)

local crc32Table: { number }?

local function generateCRC32Table()
	crc32Table = table.create(256, 0)
	for i = 0, 255 do
		local c = i
		for _ = 1, 8 do
			if bit32.band(c, 1) ~= 0 then
				c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1))
			else
				c = bit32.rshift(c, 1)
			end
			c = bit32.band(c, 0xFFFFFFFF)
		end
		crc32Table[i + 1] = c
	end
end

return function(data: buffer): number
	if not crc32Table then
		generateCRC32Table()
	end
	assert(crc32Table)
	local crc = 0xFFFFFFFF
	for i = 0, buffer.len(data) - 1 do
		local byte = buffer.readu8(data, i)
		local idx = bit32.band(bit32.bxor(crc, byte), 0xFF) + 1
		crc = bit32.bxor(crc32Table[idx], bit32.rshift(crc, 8))
		crc = bit32.band(crc, 0xFFFFFFFF)
	end

	return bit32.bxor(crc, 0xFFFFFFFF)
end
