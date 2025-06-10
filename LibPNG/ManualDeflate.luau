--!strict
--!optimize 2

local LibDeflate = require(script.Parent.LibDeflate)
local ManualDeflate = {}

function ManualDeflate.decompress(data: string): string
	if #data < 6 then
		error("Too short for zlib")
	end

	local cmf = string.byte(data, 1)
	local flg = string.byte(data, 2)

	if (cmf % 16) ~= 8 then
		error("Unsupported compression method")
	end
	if ((cmf * 256 + flg) % 31) ~= 0 then
		error("Invalid zlib header checksum")
	end

	local deflateData = data:sub(3, -5)
	local result, _ = LibDeflate:DecompressDeflate(deflateData)
	if not result then
		error("Decompression failed")
	end
	return result
end

return ManualDeflate
