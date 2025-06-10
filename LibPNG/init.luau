--!strict
--!optimize 2

local Deflate = require(script.ManualDeflate)
local crc32 = require(script.CRC32)

local PNGClass = {}
local PNG = {}
local M_PNG = { __index = PNG }

local COLOR_MAP = {
	[0] = 1,
	[2] = 3,
	[3] = 1,
	[4] = 2,
	[6] = 4,
}

export type PNG = typeof(setmetatable({} :: {
	strips: { buffer },
	width: number,
	height: number,
	data: buffer,
	bitDepth: number,
	colorType: number,
	compression: number,
	filterMethod: number,
	interlace: number,
}, M_PNG))

--// usefull functions

-- for type 4 png, to predict paeth stuff
local function paethPredictor(a: number, b: number, c: number): number
	local p = a + b - c
	local pa = math.abs(p - a)
	local pb = math.abs(p - b)
	local pc = math.abs(p - c)
	if pa <= pb and pa <= pc then
		return a
	elseif pb <= pc then
		return b
	else
		return c
	end
end

-- basically, each line you get by decompressing the huffman with deflate, you
-- get a line like [byte][data], and depending on the byte, the compression changes
local function unfilterScanline(filterType: number, scanline: buffer, prevScanline: buffer?, bpp: number): buffer
	local length = buffer.len(scanline)
	local result = buffer.create(length)
	
	local filter: ((number, number, number, number) -> number)? = ({
		[0] = function(raw: number, left: number, up: number, upLeft: number): number
			return raw
		end,
		function(raw: number, left: number, up: number, upLeft: number): number
			return (raw + left) % 256
		end,
		function(raw: number, left: number, up: number, upLeft: number): number
			return (raw + up) % 256
		end,
		function(raw: number, left: number, up: number, upLeft: number): number
			return (raw + bit32.rshift(left + up, 1) % 256)
		end,
		function(raw: number, left: number, up: number, upLeft: number): number
			return (raw + paethPredictor(left, up, upLeft)) % 256
		end,
	})[filterType]
	
	if (not filter) then
		error(`Unknown filter type: {filterType}`)
	end

	for i = 0, length - 1 do
		local raw = buffer.readu8(scanline, i)
		local left = if i >= bpp then buffer.readu8(result, i - bpp) else 0
		local up = if prevScanline then buffer.readu8(prevScanline, i) else 0
		local upLeft = if prevScanline and i >= bpp then buffer.readu8(prevScanline, i - bpp) else 0
		buffer.writeu8(result, i, filter(raw, left, up, upLeft))
	end

	return result
end

-- handle big endian ass number
@native
local function readBigEndian32(b: buffer, off: number)
	return bit32.byteswap(buffer.readu32(b, off))
end

-- display a buffer like a boss
local function formatBufferData(b: buffer): string
	local res = ""
	for i = 0, buffer.len(b) - 1 do
		local c = buffer.readu8(b, i)
		if (c < 32) or (c > 122) then
			res ..= string.format("\\x%02x", c)
		else
			res ..= string.char(c)
		end
	end
	return res
end

-- calculate the perfect camera distance
local function calculateCameraDistance(viewportSize: Vector2, worldSize: Vector2, fovDegrees: number)
	local fovV = math.rad(fovDegrees or 70)
	local aspect = viewportSize.X / viewportSize.Y
	local fovH = 2 * math.atan(math.tan(fovV/2) * aspect)

	local dHeight = worldSize.Y / (2 * math.tan(fovV / 2))
	local dWidth = worldSize.X / (2 * math.tan(fovH / 2))

	return math.max(dHeight, dWidth)
end

--// PNG methods

-- get the next header of the PNG
@native
function PNG:nextHeader(): (buffer, buffer)
	local self = self :: PNG
	local chunkSize = readBigEndian32(self.data, 0)
	local chunkType = buffer.create(4)
	buffer.copy(chunkType, 0, self.data, 4, 4)

	local chunkData = buffer.create(chunkSize)
	buffer.copy(chunkData, 0, self.data, 8, chunkSize)

	local crcOffset = 8 + chunkSize
	local crcStored = readBigEndian32(self.data, crcOffset)
	local crcBuf = buffer.create(4 + chunkSize)
	buffer.copy(crcBuf, 0, chunkType, 0, 4)
	buffer.copy(crcBuf, 4, chunkData, 0, chunkSize)
	
	local crcReal = crc32(crcBuf)
	if crcReal ~= crcStored then
		error("CRC verification failed")
	end

	local nextOffset = crcOffset + 4
	local remaining = buffer.len(self.data) - nextOffset
	local nextBuf = buffer.create(remaining)
	buffer.copy(nextBuf, 0, self.data, nextOffset, remaining)

	self.data = nextBuf
	return chunkType, chunkData
end

-- parse a IHDR chunk, so basically it querries all infos
@native
function PNG:parseIHDR(data: buffer)
	local self = self :: PNG
	self.width = readBigEndian32(data, 0)
	self.height = readBigEndian32(data, 4)
	self.bitDepth = buffer.readu8(data, 8)
	self.colorType = buffer.readu8(data, 9)
	self.compression = buffer.readu8(data, 10) -- dont give a fuck
	self.filterMethod = buffer.readu8(data, 11) -- dont give a fuck as well
	self.interlace = buffer.readu8(data, 12) -- dont give more fucks
end

-- parses every IDAT until IEND
@native
function PNG:parseIDATStream(firstData: buffer)
	local self = self :: PNG
	local concat = { firstData }

	while true do
		local chunkType, chunkData = self:nextHeader()
		local name = buffer.tostring(chunkType)
		if name == "IDAT" then
			table.insert(concat, chunkData)
		elseif name == "IEND" then
			break
		else
			self:parseAnyChunk(chunkType, chunkData)
		end
	end

	local totalSize = 0
	for _, b in concat do
		totalSize += buffer.len(b)
	end
	local allData = buffer.create(totalSize)
	local offset = 0
	for _, b in concat do
		local len = buffer.len(b)
		buffer.copy(allData, offset, b, 0, len)
		offset += len
	end

	local decompressedStr = Deflate.decompress(buffer.tostring(allData))
	local decompressed = buffer.fromstring(decompressedStr)

	local bpp = COLOR_MAP[self.colorType] * (self.bitDepth // 8)
	local lineSize = 1 + self.width * bpp
	local expected = self.height * lineSize
	if buffer.len(decompressed) < expected then
		error(`Incomplete image data: expected {expected}, got {buffer.len(decompressed)}`)
	end
	if self.bitDepth ~= 8 then
		error(`Unsupported bit depth: {self.bitDepth}`)
	end

	local prevLine = buffer.create(lineSize - 1)
	for i = 0, self.height - 1 do
		local start = i * lineSize
		local scanline = buffer.create(lineSize)
		buffer.copy(scanline, 0, decompressed, start, lineSize)

		local filterType = buffer.readu8(scanline, 0)
		local thisLine = buffer.create(lineSize - 1)
		buffer.copy(thisLine, 0, scanline, 1, lineSize - 1)

		local unfiltered = unfilterScanline(filterType, thisLine, prevLine, bpp)
		table.insert(self.strips, unfiltered)
		prevLine = unfiltered
	end
end

-- parse any chunks with the given chunkType
@native
function PNG:parseAnyChunk(chunkType: buffer, chunkData: buffer)
	local self = self :: PNG
	local t = buffer.tostring(chunkType)
	if t == "IHDR" then
		return self:parseIHDR(chunkData)
	elseif t == "IDAT" then
		return self:parseIDATStream(chunkData)
	else
		--warn(`{t}: skip chunk type (not implemented)`)
	end
end

-- first, check for signature
-- signature is [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
@native
function PNG:init(stream: buffer)
	local self = self :: PNG
	local sig0 = buffer.readu32(stream, 0)
	local sig1 = buffer.readu32(stream, 4)
	if sig0 ~= 0x474E5089 or sig1 ~= 0x0A1A0A0D then
		error("invalid png signature")
	end
	self.data = buffer.create(buffer.len(stream) - 8)
	buffer.copy(self.data, 0, stream, 8, buffer.len(self.data))
end

function PNG:render(pixelSize: number)
	local self = self :: PNG

	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, self.width * pixelSize, 0, self.height * pixelSize)
	container.BackgroundColor3 = Color3.new(0, 0, 0)
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Name = "PixelDisplay"
	container.AutomaticSize = Enum.AutomaticSize.None
	container.AnchorPoint = Vector2.new(.5, .5)
	container.Position = UDim2.new(.5, 0, .5, 0)

	for y, line in ipairs(self.strips) do
		task.wait()
		print(y)
		task.spawn(function()
			for i = 0, buffer.len(line) - 1, 3 do
				local x = (i - 1) // 3
				local r = buffer.readu8(line, i)
				local g = buffer.readu8(line, i + 1)
				local b = buffer.readu8(line, i + 2)
			
				local pixel = Instance.new("Frame")
				pixel.Size = UDim2.new(0, pixelSize, 0, pixelSize)
				pixel.Position = UDim2.new(0, x * pixelSize, 0, (y - 1) * pixelSize)
				pixel.BackgroundColor3 = Color3.fromRGB(r, g, b)
				pixel.BorderSizePixel = 0
				pixel.Name = "Pixel_" .. x .. "_" .. y
				pixel.Parent = container
			end	
		end)
	end
	return container
end

function PNG:render3D()
	local self = self :: PNG

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(0, self.width, 0, self.height)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.BorderSizePixel = 0
	viewport.Name = "PixelViewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
	viewport.CurrentCamera = Instance.new("Camera", viewport)
	
	local viewportSize = Vector2.new(self.width, self.height)
	local worldSize = viewportSize -- same (for now)
	local camDistance = calculateCameraDistance(viewportSize, worldSize, 70)
	
	assert(viewport.CurrentCamera).CFrame = CFrame.new(
		Vector3.new(self.width / 2, -self.height / 2, camDistance),
		Vector3.new(self.width / 2, -self.height / 2, 0)
	)

	local model = Instance.new("Model")
	model.Name = "PixelModel"
	model.Parent = viewport

	for y, line in ipairs(self.strips) do
		task.wait() -- avoid crash
		print(y)
		local foo = buffer.len(line) - 1
		for i = 0, foo, 3 do
			if i + 2 > foo then
				break
			end
			local x = (i - 1) // 3
			local r = buffer.readu8(line, i)
			local g = buffer.readu8(line, i + 1)
			local b = buffer.readu8(line, i + 2)

			local pixelPart = Instance.new("Part")
			pixelPart.Anchored = true
			pixelPart.CanCollide = false
			pixelPart.Size = Vector3.new(1, 1, 0.01)
			pixelPart.Position = Vector3.new(x * 1, -((y - 1) * 1), 0)
			pixelPart.Color = Color3.fromRGB(r, g, b)
			pixelPart.TopSurface = Enum.SurfaceType.Smooth
			pixelPart.BottomSurface = Enum.SurfaceType.Smooth
			pixelPart.Parent = model
		end
	end

	return viewport
end

--// metamethods

function M_PNG:__tostring()
	local self = self :: PNG
	return `<PNG {self.width}x{self.height}>`
end

--// class

-- load an image from stream (then i have to parse it and stuff)
function PNGClass.newFromStream(stream: buffer): Instance
	local self: PNG = setmetatable({
		strips = {},
		width = -1,
		height = -1,
		bitDepth = -1,
		colorType = -1,
		compression = -1,
		filterMethod = -1,
		interlace = -1,
		data = buffer.create(0),
	}, M_PNG)
	
	self:init(stream)
	while buffer.len(self.data) > 0 do
		local chunkType, chunkData = self:nextHeader()
		self:parseAnyChunk(chunkType, chunkData)
	end
	return self:render3D()
end

return PNGClass
