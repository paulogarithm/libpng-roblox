--!strict

local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local PNG = require(Replicated.LibPNG)

local content = Http:GetAsync("https://media.discordapp.net/attachments/675792739274850326/1376535762710954004/moi.png?ex=684974d4&is=68482354&hm=a30e6195460b171eb288944873a87253510c6153648c230758f0f9f614f5e725&=&quality=lossless&width=930&height=930")
local data = buffer.fromstring(content)

local function parseData()
	local image = PNG.newFromStream(data)
	image.Parent = StarterGui.ScreenGui
	for _, player in ipairs(Players:GetPlayers()) do
		RunService.Heartbeat:Wait()
		image:Clone().Parent = player.PlayerGui
	end
end

task.spawn(parseData)
