-- SkeletonAI.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Ghost Skeleton -- musuh dungeon (bukan milik tim manapun, sesuai
-- dokumen master). Versi ini baru fitur DASAR biar bisa dites dulu:
--   - Sleeping di posisi rumah (home) sampai ada pemain masuk aggro zone.
--   - Delay 3 detik sebelum mulai ngejar (kasih waktu pemain reaksi).
--   - Kejar pakai BFS pathfinding di grid (bukan physics), dibatasi leash
--     (nggak akan ngejar lebih dari radius tertentu dari rumahnya).
--   - Kalau target kabur ngelewatin leash, Skeleton nyerah & balik rumah.
--   - Nyentuh pemain = instant kill (server-authoritative, sama kayak
--     ToxicSludgeDeath).
--
-- BELUM ada (nanti nyusul kalau versi dasar ini udah oke):
--   - Nyerap cargo korban (nunggu sistem mining/cargo dulu).
--   - Trigger dari TNT blast (nunggu sistem TNT).
--   - Konsep "sleeping kalau path ketutup mining" dari dokumen master
--     (nunggu sistem mining yang bisa ngubah map).
--   - Sprite/animasi asli (sementara pakai Part placeholder polos).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local MapQuery = require(ReplicatedStorage:WaitForChild("MapQuery"))

local TILE = GridConfig.TILE

-- ==== Konfigurasi ====
-- Daftar posisi "rumah" Skeleton (grid x,z). BARU 1 buat testing --
-- nanti tinggal tambah baris lagi kalau versi ini udah oke.
local SKELETON_HOMES = {
	{ gx = 75, gz = 20 },
}

local SPAWN_DELAY = 3 -- detik, nunggu sebelum mulai ngejar setelah ke-aggro
local LEASH_TILES = 20 -- radius kejar maksimal dari rumah (jadi area 40x40 total)
local MOVE_SPEED_TILES_PER_SEC = 3 -- sedikit lebih lambat dari pemain (4), biar bisa dikabur
local REPATH_INTERVAL = 0.3 -- detik, seberapa sering hitung ulang jalur BFS (nggak usah tiap frame, berat)

-- ==== Helper: cek 1 tile termasuk "aggro zone" (5x5 blok + 4 tile "tanduk") ====
local function isInAggroZone(homeGx, homeGz, gx, gz)
	local dx, dz = gx - homeGx, gz - homeGz
	-- Blok 5x5 (dari -2 sampai +2 di kedua sumbu)
	if math.abs(dx) <= 2 and math.abs(dz) <= 2 then
		return true
	end
	-- 4 tile "tanduk", nempel persis di tengah masing-masing sisi blok 5x5
	if (dx == 0 and math.abs(dz) == 3) or (dz == 0 and math.abs(dx) == 3) then
		return true
	end
	return false
end

local function isWithinLeash(homeGx, homeGz, gx, gz)
	return math.abs(gx - homeGx) <= LEASH_TILES and math.abs(gz - homeGz) <= LEASH_TILES
end

-- ==== Helper: BFS pathfinding sederhana di grid, dibatasi leash ====
-- Balikin list {..., {gx=,gz=}, ...} dari tile SETELAH start sampai goal,
-- atau nil kalau nggak ketemu jalur.
local function findPath(startGx, startGz, goalGx, goalGz, homeGx, homeGz)
	if startGx == goalGx and startGz == goalGz then
		return {}
	end

	local visited = {}
	local function key(gx, gz) return gx .. "," .. gz end
	visited[key(startGx, startGz)] = true

	local queue = { { gx = startGx, gz = startGz, path = {} } }
	local queueHead = 1

	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

	while queue[queueHead] do
		local current = queue[queueHead]
		queueHead += 1

		for _, dir in ipairs(DIRS) do
			local ngx, ngz = current.gx + dir[1], current.gz + dir[2]
			local k = key(ngx, ngz)
			if not visited[k] and isWithinLeash(homeGx, homeGz, ngx, ngz) and not MapQuery.IsSolid(ngx, ngz) then
				visited[k] = true
				local newPath = table.clone(current.path)
				table.insert(newPath, { gx = ngx, gz = ngz })
				if ngx == goalGx and ngz == goalGz then
					return newPath
				end
				table.insert(queue, { gx = ngx, gz = ngz, path = newPath })
			end
		end
	end

	return nil -- nggak ketemu jalur (kemungkinan target ketutup wall/rock total)
end

-- ==== Bikin 1 Skeleton dari 1 home position ====
local function createSkeleton(homeGx, homeGz)
	local homeWorld = GridConfig.GridToWorld(homeGx, homeGz)

	-- Placeholder visual polos (belum ada sprite asli) -- gampang diganti
	-- belakangan pakai Decal kayak SpriteCharacter, tanpa ubah logic AI.
	local part = Instance.new("Part")
	part.Name = "GhostSkeleton"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(TILE * 0.7, TILE * 0.7, TILE * 0.7)
	part.Color = Color3.fromRGB(230, 230, 230)
	part.Material = Enum.Material.Neon
	part.Position = Vector3.new(homeWorld.X, TILE * 0.35, homeWorld.Z)
	part.Parent = workspace

	local state = {
		gx = homeGx,
		gz = homeGz,
		worldPos = Vector3.new(homeWorld.X, TILE * 0.35, homeWorld.Z),
		awake = false,
		aggroTimer = 0,
		target = nil, -- Player yang lagi dikejar
		path = nil,
		pathIndex = 1,
		repathCooldown = 0,
	}

	-- ==== Cari target: pemain mana aja yang lagi di aggro zone ====
	local function findAggroTarget()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChild("Humanoid")
			if hrp and humanoid and humanoid.Health > 0 then
				local pgx, pgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
				if isInAggroZone(homeGx, homeGz, pgx, pgz) then
					return player
				end
			end
		end
		return nil
	end

	local function targetStillValid(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not (hrp and humanoid and humanoid.Health > 0) then
			return false
		end
		local pgx, pgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
		return isWithinLeash(homeGx, homeGz, pgx, pgz)
	end

	RunService.Heartbeat:Connect(function(dt)
		if not state.awake then
			-- Sleeping: cek tiap frame apakah ada pemain masuk aggro zone
			local found = findAggroTarget()
			if found then
				state.awake = true
				state.aggroTimer = SPAWN_DELAY
				state.target = found
			end
			return
		end

		-- Delay sebelum mulai ngejar (kasih waktu pemain reaksi)
		if state.aggroTimer > 0 then
			state.aggroTimer -= dt
			return
		end

		-- Kalau target udah invalid (mati/keluar leash), coba cari target baru
		-- di aggro zone; kalau nggak ada, balik tidur & pulang ke rumah.
		if not state.target or not targetStillValid(state.target) then
			local found = findAggroTarget()
			if found then
				state.target = found
			else
				state.awake = false
				state.target = nil
				state.path = nil
				return
			end
		end

		-- Hitung ulang jalur BFS secara berkala (bukan tiap frame, berat)
		state.repathCooldown -= dt
		if state.repathCooldown <= 0 then
			state.repathCooldown = REPATH_INTERVAL
			local character = state.target.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local tgx, tgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
				state.path = findPath(state.gx, state.gz, tgx, tgz, homeGx, homeGz)
				state.pathIndex = 1
			end
		end

		-- Jalanin 1 langkah grid ke arah tile berikutnya di path
		if state.path and state.path[state.pathIndex] then
			local nextTile = state.path[state.pathIndex]
			local nextWorld = GridConfig.GridToWorld(nextTile.gx, nextTile.gz)
			local targetWorldPos = Vector3.new(nextWorld.X, TILE * 0.35, nextWorld.Z)
			local dist = (targetWorldPos - state.worldPos).Magnitude
			local step = MOVE_SPEED_TILES_PER_SEC * TILE * dt

			if dist <= step then
				state.worldPos = targetWorldPos
				state.gx, state.gz = nextTile.gx, nextTile.gz
				state.pathIndex += 1
			else
				local direction = (targetWorldPos - state.worldPos).Unit
				state.worldPos += direction * step
			end
			part.Position = state.worldPos
		end

		-- Cek kontak sama target: 1 tile yang sama = kena
		local character = state.target.Character
		local humanoid = character and character:FindFirstChild("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp and humanoid.Health > 0 then
			local pgx, pgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
			if pgx == state.gx and pgz == state.gz then
				humanoid.Health = 0
				-- TODO nanti: serap cargo korban begitu sistem mining/cargo ada.
			end
		end
	end)

	return part
end

for _, home in ipairs(SKELETON_HOMES) do
	createSkeleton(home.gx, home.gz)
end

print(("[SkeletonAI] %d Ghost Skeleton ter-spawn."):format(#SKELETON_HOMES))