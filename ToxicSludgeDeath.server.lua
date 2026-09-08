-- ToxicSludgeDeath.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Ngecek tiap frame: karakter tiap pemain lagi berdiri di tile mematikan
-- (hazard/lava, lihat MapQuery.IsLethal) atau nggak. Kalau iya, langsung
-- bunuh karakternya (instant death, sesuai desain game -- nggak ada
-- damage bertahap, nggak ada HP berkurang pelan-pelan).
--
-- SENGAJA jalan di SERVER (bukan LocalScript) -- ini soal fairness/
-- kejujuran game (kematian), jadi nggak boleh bisa "dicurangi" dari sisi
-- client manapun. GridMovement.client.lua cuma ngatur GERAK & ANIMASI,
-- keputusan "kamu mati atau nggak" itu SELALU final di server ini.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local MapQuery = require(ReplicatedStorage:WaitForChild("MapQuery"))

-- debounce per karakter, biar nggak manggil TakeDamage berkali-kali
-- dalam 1 frame yang sama / sebelum humanoid beneran mati & di-respawn
local alreadyKilled = {}

local function onCharacterAdded(character)
	alreadyKilled[character] = false
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			alreadyKilled[character] = nil
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end)

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and not alreadyKilled[character] then
			local humanoid = character:FindFirstChild("Humanoid")
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if humanoid and hrp and humanoid.Health > 0 then
				local gx, gz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
				if MapQuery.IsLethal(gx, gz) then
					alreadyKilled[character] = true
					humanoid.Health = 0
					-- TODO nanti: hook ke sini buat drop loot bag di posisi
					-- terakhir yang aman & tampilin result screen, begitu
					-- sistem cargo/inventory & result screen udah ada.
				end
			end
		end
	end
end)
