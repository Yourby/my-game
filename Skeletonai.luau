-- SkeletonAI.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Ghost Skeleton -- musuh dungeon (bukan milik tim manapun, sesuai
-- dokumen master). Versi ini fitur DASAR biar bisa dites dulu:
--   - Sleeping di posisi rumah (home) sampai ada pemain masuk aggro zone.
--   - Delay 3 detik HANYA berlaku untuk kasus "skel baru spawn dan pas itu
--     juga udah ada player di dalam aggro zone-nya" (misal player lagi
--     mining pas skel spawn deket dia). Setelah 3 detik, dicek ulang:
--     kalau playernya MASIH di aggro zone -> baru mulai ngejar. Kalau
--     playernya udah kabur dari zone dalam 3 detik itu -> skel nggak jadi
--     ngejar, balik sleeping normal.
--   - Kasus NORMAL (skel udah lama sleeping di rumah, player baru masuk
--     aggro zone belakangan) -> LANGSUNG ngejar, TANPA delay. Delay cuma
--     buat skenario spawn di atas.
--   - Skel cuma spawn & jalan di tile yang bener-bener bisa dipijak
--     (bukan solid/wall/rock, DAN bukan hazard/lava) -- lihat isWalkableTile.
--   - Kejar pakai BFS pathfinding di grid (bukan physics), dibatasi leash
--     (nggak akan ngejar lebih dari radius tertentu dari rumahnya).
--   - Kalau target kabur ngelewatin leash (atau ilang/mati) dan nggak ada
--     target lain di aggro zone, Skeleton NYERAH dan JALAN BALIK ke rumah
--     (mode "returning"), baru bener-bener sleeping lagi setelah nyampe.
--     Kalau pas lagi jalan pulang ada player masuk aggro zone lagi, itu
--     kasus NORMAL juga -> langsung ngejar lagi (nggak delay).
--   - Nyentuh pemain = instant kill (server-authoritative, sama kayak
--     ToxicSludgeDeath).
--
-- BELUM ada (nanti nyusul kalau versi dasar ini udah oke):
--   - Nyerap cargo korban (nunggu sistem mining/cargo dulu).
--   - Trigger dari TNT blast (nunggu sistem TNT) -- spek: kalau skel lagi
--     "sleeping" ATAU "returning" (jalan pulang) terus ada TNT yang MELEDAK
--     dan area blast-nya masuk ke zona skel, skel langsung ngejar player
--     yang masang TNT itu (mirip kasus NORMAL masuk aggro zone -> langsung
--     chase, BUKAN kasus spawnDelay -> nggak pakai delay 3 detik).
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
	{ gx = 66, gz = 23 },
}

local SPAWN_DELAY = 3 -- detik, cuma dipakai buat kasus "player udah di zone pas skel spawn"
local LEASH_TILES = 20 -- radius kejar maksimal dari rumah (jadi area 40x40 total)
local MOVE_SPEED_TILES_PER_SEC = 3 -- sedikit lebih lambat dari pemain (4), biar bisa dikabur
local REPATH_INTERVAL = 0.3 -- detik, seberapa sering hitung ulang jalur BFS (nggak usah tiap frame, berat)

-- ==== Helper: 1 tile "bisa dipijak" kalau bukan solid (wall/rock) DAN bukan hazard/lava ====
local function isWalkableTile(gx, gz)
	return not MapQuery.IsSolid(gx, gz) and not MapQuery.IsLethal(gx, gz)
end

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

-- ==== Helper: BFS pathfinding sederhana di grid, dibatasi leash + walkable ====
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
			if not visited[k] and isWithinLeash(homeGx, homeGz, ngx, ngz) and isWalkableTile(ngx, ngz) then
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

-- ==== Helper: jalanin 1 langkah grid di sepanjang state.path ====
-- Selalu ambil tile PALING DEPAN (state.path[1]) & "buang" begitu nyampe --
-- jadi state.path itu representasi "tile-tile yang MASIH harus dilewatin",
-- bukan diindeks. Balikin true kalau FRAME INI skeleton persis nyampe di
-- 1 tile (dipakai buat mutusin kapan boleh repath -- lihat catatan di
-- pemanggil).
local function stepAlongPath(state, part, dt)
	if not (state.path and state.path[1]) then
		return false
	end
	local nextTile = state.path[1]
	local nextWorld = GridConfig.GridToWorld(nextTile.gx, nextTile.gz)
	local targetWorldPos = Vector3.new(nextWorld.X, TILE * 0.35, nextWorld.Z)
	local dist = (targetWorldPos - state.worldPos).Magnitude
	local step = MOVE_SPEED_TILES_PER_SEC * TILE * dt

	if dist <= step then
		state.worldPos = targetWorldPos
		state.gx, state.gz = nextTile.gx, nextTile.gz
		table.remove(state.path, 1)
		part.Position = state.worldPos
		return true
	else
		local direction = (targetWorldPos - state.worldPos).Unit
		state.worldPos += direction * step
		part.Position = state.worldPos
		return false
	end
end

-- ==== Bikin 1 Skeleton dari 1 home position ====
local function createSkeleton(homeGx, homeGz)
	if not isWalkableTile(homeGx, homeGz) then
		warn(("[SkeletonAI] Home (%d,%d) bukan tile floor yang bisa dipijak, skip spawn."):format(homeGx, homeGz))
		return nil
	end

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

	-- mode: "sleeping" | "spawnDelay" | "chasing" | "returning"
	local state = {
		gx = homeGx,
		gz = homeGz,
		worldPos = Vector3.new(homeWorld.X, TILE * 0.35, homeWorld.Z),
		mode = "sleeping",
		aggroTimer = 0,
		target = nil, -- Player yang lagi dikejar / dipantau pas spawnDelay
		path = nil,
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

	local function isTargetStillInAggroZone(player)
		local character = player and player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not (hrp and humanoid and humanoid.Health > 0) then
			return false
		end
		local pgx, pgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
		return isInAggroZone(homeGx, homeGz, pgx, pgz)
	end

	-- ==== Cek kondisi PAS SPAWN: kalau udah ada player di aggro zone ====
	-- saat ini juga, itu kasus KHUSUS -> kasih grace period (SPAWN_DELAY)
	-- dulu, baru dicek ulang. Kalau nggak ada player di zone saat spawn,
	-- ya sleeping normal (nanti begitu ada yang masuk, langsung ngejar).
	do
		local spawnTarget = findAggroTarget()
		if spawnTarget then
			state.mode = "spawnDelay"
			state.aggroTimer = SPAWN_DELAY
			state.target = spawnTarget
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		if state.mode == "sleeping" then
			-- Sleeping normal: begitu ada pemain masuk aggro zone, LANGSUNG
			-- ngejar, TANPA delay (delay cuma buat kasus "spawnDelay" di atas).
			local found = findAggroTarget()
			if found then
				state.mode = "chasing"
				state.target = found
				state.path = nil
				state.repathCooldown = 0
			end
			return
		end

		if state.mode == "spawnDelay" then
			state.aggroTimer -= dt
			if state.aggroTimer > 0 then
				return
			end
			-- Grace period abis: cek ulang, playernya masih di aggro zone
			-- atau udah kabur duluan?
			if isTargetStillInAggroZone(state.target) then
				state.mode = "chasing"
				state.path = nil
				state.repathCooldown = 0
			else
				state.mode = "sleeping"
				state.target = nil
			end
			return
		end

		if state.mode == "returning" then
			-- Pas jalan pulang, kalau ada player masuk aggro zone lagi, itu
			-- kasus NORMAL (bukan spawn) -> langsung ngejar lagi, nggak delay.
			local found = findAggroTarget()
			if found then
				state.mode = "chasing"
				state.target = found
				state.path = nil
				state.repathCooldown = 0
				return
			end

			if state.path then
				stepAlongPath(state, part, dt)
				if state.gx == homeGx and state.gz == homeGz then
					state.mode = "sleeping"
					state.path = nil
				end
			else
				-- Jalur pulang nggak ketemu (edge case) -> langsung taro balik
				-- di rumah daripada macet selamanya.
				state.gx, state.gz = homeGx, homeGz
				state.worldPos = Vector3.new(homeWorld.X, TILE * 0.35, homeWorld.Z)
				part.Position = state.worldPos
				state.mode = "sleeping"
			end
			return
		end

		-- state.mode == "chasing"
		if not state.target or not targetStillValid(state.target) then
			local found = findAggroTarget()
			if found then
				state.target = found
				state.path = nil
				state.repathCooldown = 0
			else
				-- Nggak ada target valid lagi (kabur keleher leash / mati /
				-- ilang) -> nyerah, jalan balik ke rumah dulu.
				state.mode = "returning"
				state.target = nil
				state.path = findPath(state.gx, state.gz, homeGx, homeGz, homeGx, homeGz)
				return
			end
		end

		-- Jalanin 1 langkah di path yang ADA SEKARANG dulu (kalau ada).
		state.repathCooldown -= dt
		local arrivedTile = false
		if state.path and state.path[1] then
			arrivedTile = stepAlongPath(state, part, dt)
		end

		-- PENTING: repath (ganti isi state.path) CUMA boleh kejadian pas
		-- skeleton PERSIS baru nyampe 1 tile (arrivedTile == true) atau pas
		-- emang belum punya path sama sekali. TIDAK PERNAH di tengah-tengah
		-- transit antar tile -- itu penyebab lama skeleton keliatan "motong"
		-- diagonal kalau BFS nemu rute lebih deket pas lagi jalan.
		local needsPath = not state.path or #state.path == 0
		if arrivedTile or (needsPath and state.repathCooldown <= 0) then
			state.repathCooldown = REPATH_INTERVAL
			local character = state.target.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local tgx, tgz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
				state.path = findPath(state.gx, state.gz, tgx, tgz, homeGx, homeGz)
				if not state.path then
					-- DEBUG: kalau ini muncul terus di Output, berarti tile di
					-- sekitar skel/player nggak walkable atau ketutup wall/rock.
					warn(("[SkeletonAI] BFS gagal cari jalur dari (%d,%d) ke (%d,%d)"):format(state.gx, state.gz, tgx, tgz))
				end
			end
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
