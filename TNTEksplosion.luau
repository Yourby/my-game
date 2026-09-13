-- TNTExplosion.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Dengerin BindableEvent "TNTFuseEnded" (dipicu dari
-- TNTPlacement.server.lua begitu fuse 3-tick-nya abis), lalu eksekusi
-- ledakan beneran: hitung radius blast berbentuk diamond (Manhattan
-- distance <= 2 dari titik taro TNT), kasih efek visual ORANGE sekilas
-- di semua tile yang kena, dan bunuh SEMUA entitas hidup di dalamnya --
-- pemain (termasuk yang naro TNT itu sendiri & teman satu timnya),
-- Ghost Skeleton -- TANPA PENGECUALIAN, sesuai desain yang disepakati
-- ("TNT itu buta, nggak pandang bulu").
--
-- BELUM ADA (nanti nyusul, nunggu sistem lain selesai duluan):
--   - Instant-mine crystal di tile yang kena blast -- nunggu sistem
--     crystal/mining ada dulu.
--   - Trigger Ghost Skeleton yang lagi "sleeping"/"returning" buat
--     langsung ngejar pemain yang masang TNT-nya (udah dicatat sebagai
--     TODO di SkeletonAI.server.lua) -- ini butuh SkeletonAI expose
--     state-nya ke script luar dulu (sekarang state-nya ketutup rapat
--     di dalam closure per-Skeleton, nggak bisa diakses dari sini).
--     Kalau mau, ini bisa dikerjain abis file ini beres, sebagai
--     refactor kecil di SkeletonAI.
--   - Zombie (musuh milik tim) -- belum ada script-nya sama sekali di
--     project ini, jadi belum bisa ikut kena blast.
--   - TNT nggak bisa hancurkan rock -- belum relevan sekarang karena
--     belum ada sistem yang bisa "menghancurkan" tile rock sama sekali
--     (nunggu sistem mining). Kalau nanti ada, tinggal skip rock tile
--     di loop blast di bawah.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))

local TILE = GridConfig.TILE

local tntFuseEnded = ServerScriptService:WaitForChild("TNTFuseEnded")

-- ==== Konfigurasi ====
local BLAST_RADIUS = 2 -- Manhattan distance (|dx|+|dz| <= 2) = bentuk diamond 13 tile, sesuai pola yang udah dikonfirmasi
local EXPLOSION_VISUAL_DURATION = 0.25 -- detik, lama part orange nyala sebelum ilang
local COLOR_EXPLOSION = Color3.fromRGB(255, 140, 0) -- oranye

-- ==== Helper: daftar semua {gx,gz} dalam radius diamond dari titik asal ====
local function getBlastTiles(originGx, originGz)
	local tiles = {}
	for dx = -BLAST_RADIUS, BLAST_RADIUS do
		for dz = -BLAST_RADIUS, BLAST_RADIUS do
			if math.abs(dx) + math.abs(dz) <= BLAST_RADIUS then
				table.insert(tiles, { gx = originGx + dx, gz = originGz + dz })
			end
		end
	end
	return tiles
end

-- ==== Helper: efek visual sekilas per tile yang kena blast ====
-- Placeholder polos (Part oranye Neon) -- gampang diganti Decal/sprite
-- ledakan asli belakangan, tinggal ganti bagian bikin part ini doang,
-- logic kill di bawah nggak perlu diubah sama sekali.
local function spawnExplosionVisual(gx, gz)
	local worldPos = GridConfig.GridToWorld(gx, gz)
	local fx = Instance.new("Part")
	fx.Name = "TNTExplosionFX"
	fx.Anchored = true
	fx.CanCollide = false
	fx.Size = Vector3.new(TILE, TILE * 0.3, TILE)
	fx.Color = COLOR_EXPLOSION
	fx.Material = Enum.Material.Neon
	fx.Position = Vector3.new(worldPos.X, TILE * 0.15, worldPos.Z)
	fx.Parent = workspace
	Debris:AddItem(fx, EXPLOSION_VISUAL_DURATION)
end

-- ==== Bunuh semua pemain yang grid position-nya masuk blastTileSet ====
-- SENGAJA nggak ada pengecualian apapun -- termasuk pemain yang naro TNT
-- itu sendiri & teman satu timnya, sesuai desain yang udah disepakati.
local function killPlayersInBlast(blastTileSet)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChild("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then
			local pgx, pgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
			if blastTileSet[pgx .. "," .. pgz] then
				humanoid.Health = 0
			end
		end
	end
end

-- ==== Bunuh semua Ghost Skeleton yang grid position-nya masuk blastTileSet ====
-- Skeleton itu Part biasa bernama "GhostSkeleton" langsung di workspace
-- (lihat SkeletonAI.server.lua), BUKAN Model dengan Humanoid -- jadi
-- "bunuh" di sini artinya literally :Destroy() part-nya. SkeletonAI.server.lua
-- udah dikasih pengaman (cek part.Parent di Heartbeat-nya) biar nggak
-- error pas part-nya ilang begini.
local function killSkeletonsInBlast(blastTileSet)
	for _, instance in ipairs(workspace:GetChildren()) do
		if instance.Name == "GhostSkeleton" and instance:IsA("BasePart") then
			local gx, gz = GridConfig.WorldToGrid(instance.Position.X, instance.Position.Z)
			if blastTileSet[gx .. "," .. gz] then
				instance:Destroy()
			end
		end
	end
end

tntFuseEnded.Event:Connect(function(part)
	if not part or not part.Parent then
		return -- jaga-jaga kalau part udah kehapus duluan sebelum event sempat diproses
	end

	local originGx = part:GetAttribute("GridX")
	local originGz = part:GetAttribute("GridZ")
	if not (originGx and originGz) then
		warn("[TNTExplosion] TNT meledak tapi nggak punya Attribute GridX/GridZ, batal proses.")
		return
	end

	part:Destroy() -- TNT-nya sendiri hilang begitu meledak

	local blastTiles = getBlastTiles(originGx, originGz)
	local blastTileSet = {}
	for _, tile in ipairs(blastTiles) do
		blastTileSet[tile.gx .. "," .. tile.gz] = true
		spawnExplosionVisual(tile.gx, tile.gz)
	end

	killPlayersInBlast(blastTileSet)
	killSkeletonsInBlast(blastTileSet)
end)