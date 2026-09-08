-- TileIdHUD.client.lua  (LocalScript)
-- Tempatkan di: StarterPlayerScripts
--
-- HUD kecil di pojok kiri atas layar, nunjukin id & koordinat tile yang
-- SEDANG diinjek karakter -- gantinya label ngambang di semua tile
-- sekaligus (yang bikin bingung karena numpuk semua). Cuma 1 baris teks,
-- update otomatis pas karakter pindah tile.
--
-- Cara matiin nanti kalau udah nggak perlu debug lagi: cukup hapus/
-- disable script ini dari StarterPlayerScripts, nggak ada bagian lain
-- yang perlu diubah.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))

local player = Players.LocalPlayer
local mapFolder = workspace:WaitForChild("MapTiles")

-- Urutan cek: rock/wall duluan (itu yang "menang"/keliatan di atas kalau
-- numpuk sama floor, sesuai LAYER_HEIGHT/LAYER_ORDER di MapGenerator),
-- floor belakangan sebagai fallback.
local LAYER_CHECK_ORDER = { "rock", "wall", "floor" }

-- ==== Bikin UI ====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TileIdHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "TileIdLabel"
label.Size = UDim2.new(0, 220, 0, 32)
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -12, 0, 12)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "Tile: -"
label.Parent = screenGui

local lastGx, lastGz = nil, nil

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local gx, gz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
	if gx == lastGx and gz == lastGz then return end -- belum pindah tile, nggak perlu update
	lastGx, lastGz = gx, gz

	local foundPart = nil
	for _, layerName in ipairs(LAYER_CHECK_ORDER) do
		local partName = string.format("%s_%d_%d", layerName, gx, gz)
		local candidate = mapFolder:FindFirstChild(partName)
		if candidate then
			foundPart = candidate
			break
		end
	end

	if foundPart then
		local id = foundPart:GetAttribute("EffectiveId")
		label.Text = string.format("Tile: id %s  (%d,%d)", tostring(id), gx, gz)
	else
		label.Text = string.format("Tile: hazard/kosong  (%d,%d)", gx, gz)
	end
end)
