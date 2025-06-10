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
```luau
-- first, get any image on the web, and convert the string you get into a buffer:
local content = Http:GetAsync("https://media.discordapp.net/attachments/675792739274850326/1376535762710954004/moi.png?ex=684974d4&is=68482354&hm=a30e6195460b171eb288944873a87253510c6153648c230758f0f9f614f5e725&=&quality=lossless&width=930&height=930")
local data = buffer.fromstring(content)

-- then, you can create an image from the data
local image = PNG.newFromStream(data)

-- and the image is treated as an instance, so it can be anywhere you want as a GUI
image.Parent = Players.LocalPlayer.PlayerGui
```

## Why does it take so long ?
The part that is the longest is the Instance creation. For an image of 800 by 800 pixels, it needs to allocate 800 * 800 pixels (instances), which is 640 000 allocation of instance (huge)

Optimising can be made in that part, but me is lazy.
