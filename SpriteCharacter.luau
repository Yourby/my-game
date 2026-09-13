local Players = game:GetService("Players")

local function hideCharacter(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.Transparency = 1
		end
	end
end

local player = Players.LocalPlayer
                                      if player.Character then
	hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)

