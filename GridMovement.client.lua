-- GridMovement.client.lua  (LocalScript)
-- Tempatkan di: StarterPlayerScripts
--
-- Menggantikan gerak bebas Roblox (Humanoid.MoveDirection + WalkSpeed)
-- dengan sistem grid-locked: karakter cuma pernah ada di DUA kondisi --
-- persis di tengah satu tile (diam), atau lagi berpindah ke tile
-- tetangga yang udah divalidasi aman sebelum mulai gerak (animasi
-- interpolasi). Sama persis prinsipnya kayak versi prototype HTML kita.
--
-- Setelah script ini aktif, Humanoid.MoveDirection TIDAK dipakai lagi
-- buat nentuin arah hadap/animasi -- gantinya lewat Attribute
-- "IsMoving" dan "Facing" di objek Character, yang perlu dibaca ulang
-- oleh SpriteController (lihat catatan di bagian bawah file ini).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local MapQuery = require(ReplicatedStorage:WaitForChild("MapQuery"))

local player = Players.LocalPlayer

local SPEED_TILES_PER_SEC = 4 -- samain/tuning belakangan sesuai rasanya

-- ==== Input state (keyboard + tombol mobile custom, disatuin di sini) ====
local keysDown = { up = false, down = false, left = false, right = false }

local KEY_MAP = {
	[Enum.KeyCode.W] = "up", [Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.S] = "down", [Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local dir = KEY_MAP[input.KeyCode]
	if dir then keysDown[dir] = true end
end)
UserInputService.InputEnded:Connect(function(input)
	local dir = KEY_MAP[input.KeyCode]
	if dir then keysDown[dir] = false end
end)

-- ==== D-pad custom buat mobile (dibangun lewat kode, bukan digambar manual) ====
local function buildMobileDPad()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GridDPad"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local function makeButton(name, position, dir)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 56, 0, 56)
		btn.Position = position
		btn.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
		btn.BackgroundTransparency = 0.4
		btn.BorderSizePixel = 0
		btn.Text = ({ up = "▲", down = "▼", left = "◀", right = "▶" })[dir]
		btn.TextColor3 = Color3.fromRGB(255, 210, 127)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				keysDown[dir] = true
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				keysDown[dir] = false
			end
		end)
		btn.Parent = screenGui
	end

	-- posisi ala d-pad, nempel pojok kiri bawah (samain feel-nya sama versi HTML)
	makeButton("Up", UDim2.new(0, 74, 1, -220), "up")
	makeButton("Down", UDim2.new(0, 74, 1, -108), "down")
	makeButton("Left", UDim2.new(0, 18, 1, -164), "left")
	makeButton("Right", UDim2.new(0, 130, 1, -164), "right")
end

if UserInputService.TouchEnabled then
	buildMobileDPad()
end

-- ==== State gerak per-karakter ====
local state = {
	character = nil,
	hrp = nil,
	gx = 0, gz = 0,
	fromPos = Vector3.new(),
	toPos = Vector3.new(),
	moveT = 1, -- 1 = idle/nyampe, 0..1 = lagi transisi
	isMoving = false,
	facing = 1, -- 1 = kanan, -1 = kiri (buat dipakai SpriteController)
}

local function tileCenterWorld(gx, gz)
	local base = GridConfig.GridToWorld(gx, gz)
	return base
end

local function trySetGrid(character, hrp)
	local gx, gz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
	state.gx, state.gz = gx, gz
	local center = tileCenterWorld(gx, gz)
	state.fromPos = center
	state.toPos = center
	state.moveT = 1
	state.isMoving = false
end

local function onCharacterAdded(character)
	state.character = character
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")
	state.hrp = hrp

	-- matiin gerak fisik bawaan Roblox -- kita ambil alih total
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	trySetGrid(character, hrp)
	character:SetAttribute("IsMoving", false)
	character:SetAttribute("Facing", 1)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

local function tryStartMove(dx, dz)
	local ngx, ngz = state.gx + dx, state.gz + dz
	if MapQuery.IsSolid(ngx, ngz) then return false end
	state.fromPos = state.toPos
	state.toPos = tileCenterWorld(ngx, ngz)
	state.gx, state.gz = ngx, ngz
	state.moveT = 0
	state.isMoving = true
	return true
end

RunService.RenderStepped:Connect(function(dt)
	local character = state.character
	local hrp = state.hrp
	if not character or not hrp or not hrp.Parent then return end

	-- Kalau karakter udah mati (misal kena tile hazard/lava, dibunuh sama
	-- ToxicSludgeDeath.server.lua), STOP total -- jangan lanjutin animasi
	-- gerak yang lagi berjalan, biar karakter kelihatan berhenti PAS di
	-- tile yang mematikan itu, bukan "bablas" nerusin ke tile berikutnya.
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return
	end

	if not state.isMoving then
		local dx, dz = 0, 0
		if keysDown.left then dx -= 1 end
		if keysDown.right then dx += 1 end
		if dx == 0 and keysDown.up then dz -= 1 end
		if dx == 0 and keysDown.down then dz += 1 end
		-- catatan: sumbu Z Roblox itu "maju" ke arah negatif secara konvensi kamera
		-- default, tapi karena kamera kita udah full custom (lookAt lurus ke
		-- bawah), up/down di sini dipetakan langsung dz negatif/positif biar
		-- konsisten sama arah visual di layar. Kalau kebalik pas dites, tinggal
		-- tukar tanda dz di dua baris di atas.

		if dx < 0 then state.facing = -1 end
		if dx > 0 then state.facing = 1 end

		if dx ~= 0 or dz ~= 0 then
			tryStartMove(dx, dz)
		end
	end

	if state.isMoving then
		state.moveT = math.min(1, state.moveT + dt * SPEED_TILES_PER_SEC)
		local pos = state.fromPos:Lerp(state.toPos, state.moveT)
		local currentCFrame = hrp.CFrame
		hrp.CFrame = CFrame.new(pos.X, currentCFrame.Position.Y, pos.Z) * (currentCFrame - currentCFrame.Position)
		hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		if state.moveT >= 1 then
			state.isMoving = false
		end
	end

	character:SetAttribute("IsMoving", state.isMoving)
	character:SetAttribute("Facing", state.facing)
end)

--[[
CATATAN PENTING buat SpriteController.lua kamu:

Sekarang animasi jalan/arah hadap HARUS baca dari attribute character ini,
BUKAN lagi dari `humanoid.MoveDirection` (soalnya humanoid udah nggak
gerak sendiri, jadi MoveDirection selalu diem/nggak reliable).

Ganti bagian ini di SpriteController:

    local moveDir = humanoid.MoveDirection
    local isMoving = moveDir.Magnitude > 0
    if moveDir.X > 0.01 then facingRight = true
    elseif moveDir.X < -0.01 then facingRight = false end

Jadi:
    local isMoving = character:GetAttribute("IsMoving") == true
    local facing = character:GetAttribute("Facing") or 1
    facingRight = facing > 0

Sisanya (logika animasi frame, dll) tetap sama persis, nggak perlu diubah.
]]
