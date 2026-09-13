local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local COLS = 4
local ROWS = 3
local TOTAL_FRAMES = 10
local FRAME_DURATION = 0.1

local player = Players.LocalPlayer
local spriteCharacter = workspace:WaitForChild("SpriteCharacter")
local decal = spriteCharacter:WaitForChild("Decal")

local currentFrame = 0
local timer = 0
local facingRight = true -- default hadap kanan, ganti ke false kalau ternyata kebalik

local function setFrame(frameIndex)
	local col = frameIndex % COLS
	local row = math.floor(frameIndex / COLS)
	local scaleX = 1 / COLS
	local scaleY = 1 / ROWS
	local offsetX = col * scaleX
	local offsetY = row * scaleY

	if facingRight then
		decal.UVScale = Vector2.new(scaleX, scaleY)
		decal.UVOffset = Vector2.new(offsetX, offsetY)
	else
		decal.UVScale = Vector2.new(-scaleX, scaleY)
		decal.UVOffset = Vector2.new(offsetX + scaleX, offsetY)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	spriteCharacter.Position = Vector3.new(hrp.Position.X, spriteCharacter.Position.Y, hrp.Position.Z)

	-- CATATAN: dulu bagian ini baca humanoid.MoveDirection, sekarang baca
	-- Attribute yang di-set sama GridMovement.client.lua, soalnya Humanoid
	-- udah nggak gerak sendiri lagi (WalkSpeed dimatiin di GridMovement).
	local isMoving = character:GetAttribute("IsMoving") == true
	local facing = character:GetAttribute("Facing") or 1
	facingRight = facing > 0

	if isMoving then
		timer = timer + dt
		if timer >= FRAME_DURATION then
			timer = 0
			currentFrame = (currentFrame + 1) % TOTAL_FRAMES
			setFrame(currentFrame)
		end
	else
		currentFrame = 0
		timer = 0
		setFrame(currentFrame)
	end
end)