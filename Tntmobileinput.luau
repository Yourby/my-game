-- TNTMobileInput.client.lua  (LocalScript)
-- Tempatkan di: StarterPlayerScripts
--
-- Input MOBILE buat naro TNT: joystick TERPISAH dari D-pad gerak
-- (GridMovement.client.lua), taro di pojok KANAN bawah layar (D-pad
-- gerak ada di kiri bawah, biar nggak numpuk/ganggu jempol yang sama).
--
-- Cara pakai: geser joystick ini ke salah satu dari 8 arah buat milih
-- tile tetangga mana yang mau ditaro TNT, lalu LEPAS buat konfirmasi &
-- kirim ke server. Kalau cuma tap tanpa geser sama sekali (joystick
-- balik ke tengah / masih di "dead zone"), itu dianggap "taro di tile
-- sendiri" -- ini VALID, bukan dibatalkan, sesuai desain (9 tile total:
-- tile sendiri + 8 tetangga).
--
-- SENGAJA nggak menghitung/validasi apapun soal tile-nya valid/nggak
-- atau jatah TNT di sini -- itu semua tetap tanggung jawab server
-- (TNTPlacement.server.lua). File ini CUMA nerjemahin gesture joystick
-- jadi offset (dx,dz), sama persis perannya kayak TNTInput.client.lua
-- buat klik kanan di PC.
--
-- Cuma dibikin/diaktifin kalau device-nya touch-enabled (mobile/tablet)
-- -- sama pola pengecekannya kayak buildMobileDPad() di
-- GridMovement.client.lua.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local requestPlaceTNT = ReplicatedStorage:WaitForChild("RequestPlaceTNT")

local TILE = GridConfig.TILE

local player = Players.LocalPlayer

if not UserInputService.TouchEnabled then
	return -- device PC/mouse, TNTInput.client.lua (klik kanan) yang jalan
end

-- Karakter di-track manual (bukan cuma sekali WaitForChild) karena
-- preview perlu tau posisi TERKINI pemain tiap frame -- termasuk kalau
-- pemain mati/respawn di tengah-tengah lagi nge-drag joystick.
local character = player.Character
local hrp = character and character:FindFirstChild("HumanoidRootPart")
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	hrp = newCharacter:WaitForChild("HumanoidRootPart")
end)

-- ==== Konfigurasi ====
local BASE_SIZE = 140
local KNOB_SIZE = 60
local DEAD_ZONE_FRACTION = 0.25 -- di bawah ini dianggap "nggak digeser" -> taro di tile sendiri

-- 8 arah, masing2 45 derajat, 0 derajat = kanan (dx=1,dz=0). Urutan
-- sengaja dimulai dari 0deg searah jarum jam biar gampang di-index pakai
-- rumus octant di bawah. Ingat: layar itu Y makin besar = makin ke
-- BAWAH, jadi dz positif = bawah -- ini match sama konvensi yang sama
-- dipakai GridMovement.client.lua.
local DIRECTION_OFFSETS = {
	[0] = { dx = 1, dz = 0 }, -- kanan
	[1] = { dx = 1, dz = 1 }, -- kanan-bawah
	[2] = { dx = 0, dz = 1 }, -- bawah
	[3] = { dx = -1, dz = 1 }, -- kiri-bawah
	[4] = { dx = -1, dz = 0 }, -- kiri
	[5] = { dx = -1, dz = -1 }, -- kiri-atas
	[6] = { dx = 0, dz = -1 }, -- atas
	[7] = { dx = 1, dz = -1 }, -- kanan-atas
}
local DIRECTION_LABELS = {
	[0] = "?", [1] = "?", [2] = "?", [3] = "?",
	[4] = "?", [5] = "?", [6] = "?", [7] = "?",
}

-- ==== Bikin UI joystick ====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TNTJoystick"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local base = Instance.new("Frame")
base.Name = "TNTJoystickBase"
base.Size = UDim2.new(0, BASE_SIZE, 0, BASE_SIZE)
base.AnchorPoint = Vector2.new(1, 1)
base.Position = UDim2.new(1, -30, 1, -110)
base.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
base.BackgroundTransparency = 0.4
base.BorderSizePixel = 0
base.Parent = screenGui
local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(1, 0)
baseCorner.Parent = base

local directionLabel = Instance.new("TextLabel")
directionLabel.Name = "DirectionLabel"
directionLabel.Size = UDim2.new(1, 0, 0, 24)
directionLabel.AnchorPoint = Vector2.new(0.5, 1)
directionLabel.Position = UDim2.new(0.5, 0, 0, -6)
directionLabel.BackgroundTransparency = 1
directionLabel.Text = ""
directionLabel.TextColor3 = Color3.fromRGB(255, 160, 60)
directionLabel.TextScaled = true
directionLabel.Font = Enum.Font.GothamBold
directionLabel.Parent = base

local knob = Instance.new("Frame")
knob.Name = "TNTJoystickKnob"
knob.Size = UDim2.new(0, KNOB_SIZE, 0, KNOB_SIZE)
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.new(0.5, 0, 0.5, 0)
knob.BackgroundColor3 = Color3.fromRGB(255, 100, 40)
knob.BackgroundTransparency = 0.15
knob.BorderSizePixel = 0
knob.Parent = base
local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1, 0)
knobCorner.Parent = knob

-- ==== Preview TNT di tile target (KLIEN-ONLY, murni visual) ====
-- Part transparan yang nempel di tile yang lagi "diarah" -- MUNCUL
-- selama joystick lagi digeser, ILANG lagi begitu dilepas (soalnya abis
-- itu TNT ASLI dari server yang muncul, kalau server nge-approve).
-- SENGAJA nggak nge-cek valid/nggaknya tile di sini (itu tugas server) --
-- preview ini cuma bantu pemain LIHAT kira-kira TNT bakal jatuh di mana,
-- bukan indikator "pasti bisa ditaro di situ".
local previewPart = Instance.new("Part")
previewPart.Name = "TNTPlacementPreview"
previewPart.Anchored = true
previewPart.CanCollide = false
previewPart.CanQuery = false -- biar nggak ketangkep raycast/mouse.Hit siapapun
previewPart.Size = Vector3.new(TILE, TILE, TILE)
previewPart.Color = Color3.fromRGB(20, 20, 20) -- sama kayak warna idle TNT asli
previewPart.Material = Enum.Material.SmoothPlastic
previewPart.Transparency = 1 -- mulai nggak keliatan, cuma nyala pas lagi dragging
previewPart.Parent = workspace

local PREVIEW_TRANSPARENCY = 0.55

-- ==== State drag ====
local dragging = false
local activeInput = nil
local selectedDx, selectedDz = 0, 0 -- default (0,0) = tile sendiri

local function resetKnob()
	knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	directionLabel.Text = ""
	selectedDx, selectedDz = 0, 0
end

local function updatePreviewPosition()
	if not (dragging and hrp) then
		return
	end
	local playerGx, playerGz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
	local worldPos = GridConfig.GridToWorld(playerGx + selectedDx, playerGz + selectedDz)
	previewPart.Position = Vector3.new(worldPos.X, TILE * 0.5, worldPos.Z)
end

local function showPreview()
	previewPart.Transparency = PREVIEW_TRANSPARENCY
	updatePreviewPosition()
end

local function hidePreview()
	previewPart.Transparency = 1
end

local function updateFromScreenPos(screenPos)
	local center = base.AbsolutePosition + base.AbsoluteSize / 2
	local delta = Vector2.new(screenPos.X, screenPos.Y) - center
	local maxRadius = base.AbsoluteSize.X / 2
	local dist = delta.Magnitude

	-- Knob nggak boleh keluar lingkaran base -- clamp kalau jari geser
	-- lebih jauh dari radius base.
	local clampedDelta = dist > maxRadius and (delta.Unit * maxRadius) or delta
	knob.Position = UDim2.new(0.5, clampedDelta.X, 0.5, clampedDelta.Y)

	if dist < maxRadius * DEAD_ZONE_FRACTION then
		-- Masih di dead zone tengah -> dianggap "taro di tile sendiri"
		selectedDx, selectedDz = 0, 0
		directionLabel.Text = "?"
		updatePreviewPosition()
		return
	end

	-- Bagi lingkaran jadi 8 sektor 45 derajat, offset 22.5 derajat biar
	-- tiap sektor CENTERED di kelipatan 45 (bukan mulai dari 0).
	local angleDeg = math.deg(math.atan2(delta.Y, delta.X))
	if angleDeg < 0 then
		angleDeg += 360
	end
	local octant = math.floor((angleDeg + 22.5) / 45) % 8

	local dir = DIRECTION_OFFSETS[octant]
	selectedDx, selectedDz = dir.dx, dir.dz
	directionLabel.Text = DIRECTION_LABELS[octant]
	updatePreviewPosition()
end

-- Jaga-jaga: pemain bisa gerak pakai D-pad (jempol lain) SAMBIL lagi
-- nge-drag joystick TNT ini (multi-touch, dua jempol beda tugas) --
-- kalau cuma update posisi preview pas jari TNT gerak doang (di
-- updateFromScreenPos), preview bakal "ketinggalan" pas pemain jalan
-- tapi jempol TNT-nya diem di 1 titik. Makanya preview-nya JUGA
-- di-refresh tiap frame lewat Heartbeat, bukan cuma pas ada gesture baru.
RunService.Heartbeat:Connect(function()
	if dragging then
		updatePreviewPosition()
	end
end)

base.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	dragging = true
	activeInput = input
	showPreview()
	updateFromScreenPos(input.Position)
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == activeInput then
		updateFromScreenPos(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeInput then
		-- Lepas jari = konfirmasi taro TNT ke arah yang lagi dipilih
		-- (termasuk (0,0) buat tile sendiri kalau nggak digeser sama sekali).
		requestPlaceTNT:FireServer(selectedDx, selectedDz)

		dragging = false
		activeInput = nil
		hidePreview()
		resetKnob()
	end
end)