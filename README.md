# libpng-roblox
Do you dream to display png on roblox without going through the roblox asset system ? This lib can load PNG images and display them on roblox !

## What does it do
It's a module that allow users to display any PNG image in a roblox game.

## How does it internally work ?
PNG is just a standard formatting for images, it rellies on compression, formatting, chunks... In the form of bytes.

But then, this image have to be decompressed to be shown, and that's exactly the purpose of this module.

So when you have a byte stream of PNG, you just need to know how to read it to see the image !

## How do i get it
1. Import the rbxm model
2. Put it in `ReplicatedStorage`
3. You're done ! you can now use it !

## Why ?
For fun, it's useless since roblox allows image publishing with AssetID, but I'm sure somebody will find a use

## What about illegal images for roblox ?
I can't do anything about it, neither roblox can. I don't support people that displays non-roblox-TOS-compliant images with my module.

But it is possible to display anything so you can put anything on screen.

## Typical usage
(working example)
```luau
local PNG = require("@game/ReplicatedStorage/LibPNG")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")

-- first, get any image on the web, and convert the string you get into a buffer:
local link = "https://pbs.twimg.com/media/HAQGK8kWwAAEGSt.png"
local content = Http:GetAsync(link)
local data = buffer.fromstring(content)

-- then, you can create an image from the data
local image = PNG.newFromStream(data)

-- and the image is treated as an instance, so it can be anywhere you want as a GUI
local function addImageToPlayerGui(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CustomImageGui"
	image.Parent = gui -- like that
	gui.Parent = player.PlayerGui
end

-- since it's only server sided, you need to add it to each player
-- but you compute the image one time
Players.PlayerAdded:Connect(addImageToPlayerGui)
for _, player in ipairs(Players:GetPlayers()) do
	addImageToPlayerGui(player)
end
```

## Why does it take so long ?
The part that is the longest is the Instance creation. For an image of 800 by 800 pixels, it needs to allocate 800 * 800 pixels (instances), which is 640 000 allocation of instance (huge)

Optimising can be made in that part, but me is lazy.
