local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local TILE = 8
local TARGET_WIDTH_STUDS = TILE * 16 -- 128
local FOV = 10

local function updateCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable

	local centerX, centerZ = 0, 0
	local player = Players.LocalPlayer
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			centerX = hrp.Position.X
			centerZ = hrp.Position.Z
		end
	end

	local vp = camera.ViewportSize
	local aspect = vp.X / vp.Y
	local vFov = math.rad(FOV)
	local hFov = 2 * math.atan(math.tan(vFov/2) * aspect)
	local distance = (TARGET_WIDTH_STUDS/2) / math.tan(hFov/2)

	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(
		Vector3.new(centerX, distance, centerZ),
		Vector3.new(centerX, 0, centerZ),
		Vector3.new(0, 0, -1)
	)
end

RunService:BindToRenderStep("CameraSetup", Enum.RenderPriority.Camera.Value + 1, updateCamera)