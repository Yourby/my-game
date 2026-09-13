local Players = game:GetService("Players")

local function hidePart(part)
	if part:IsA("BasePart") or part:IsA("Decal") then
		part.Transparency = 1
	end
end

local function hideCharacter(character)
	for _, part in ipairs(character:GetDescendants()) do
		hidePart(part)
	end
	character.DescendantAdded:Connect(hidePart)
end

local player = Players.LocalPlayer
if player.Character then
	hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)
