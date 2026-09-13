-- TNTPlacement.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Validasi & eksekusi penempatan TNT. SENGAJA server-authoritative penuh
-- (sama prinsipnya kayak ToxicSludgeDeath & SkeletonAI) -- client (PC
-- klik kanan / joystick mobile) CUMA ngirim "aku mau naro di tile arah
-- (dx,dz) relatif dari posisiku", server yang mutusin valid/nggak &
-- eksekusi semuanya. Ini file KHUSUS urusan naro + fuse timer; logic
-- LEDAKAN (siapa aja yang mati, radius diamond, dll) ada di file
-- terpisah nanti (TNTExplosion.server.lua), disambungin lewat
-- BindableEvent "TNTFuseEnded" di bagian bawah file ini.
--
-- Spek yang udah disepakati:
--   - Bisa ditaro di tile sendiri ATAU 8 tile tetangga (termasuk
--     diagonal) -- jadi 9 pilihan tile total, offset (dx,dz) masing2
--     -1/0/1 di kedua sumbu.
--   - 3 TNT fixed per sesi per pemain, no auto resupply (nanti nambah
--     dari sistem loot, belum ada sekarang).
--   - Tile tujuan harus valid dipijak (bukan solid/wall/rock, DAN bukan
--     hazard/lava) -- TNT nggak bisa "mengambang" di sludge.
--   - Fuse 3 detik dengan animasi kelap-kelip, MAKIN CEPAT makin deket
--     ke detik terakhir (biar berasa "mau meledak").
--   - BELUM: efek ledakan itu sendiri (radius diamond, siapa aja yang
--     mati) -- itu tugas TNTExplosion.server.lua di langkah berikutnya.
--     File ini cuma "menyalakan sumbu", bukan yang "meledakkan".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local MapQuery = require(ReplicatedStorage:WaitForChild("MapQuery"))

local TILE = GridConfig.TILE

-- ==== Konfigurasi ====
local TNT_PER_SESSION = 90
local FUSE_TIME = 1.25 -- detik (total efektif fuse, lihat catatan di runFuseAnimation di bawah)

-- ==== RemoteEvent buat nerima request dari client (PC klik kanan / mobile joystick) ====
-- Payload yang dikirim client: offsetDx, offsetDz (masing2 harus -1, 0,
-- atau 1 -- di luar itu otomatis ditolak server). File input PC & mobile
-- nanti tinggal ngitung offset ini dari hasil klik/joystick, TIDAK perlu
-- tau apa-apa soal validasi tile/TNT count, itu semua kerjaan file ini.
local requestPlaceTNT = ReplicatedStorage:FindFirstChild("RequestPlaceTNT")
if not requestPlaceTNT then
	requestPlaceTNT = Instance.new("RemoteEvent")
	requestPlaceTNT.Name = "RequestPlaceTNT"
	requestPlaceTNT.Parent = ReplicatedStorage
end

-- ==== BindableEvent internal server, dipicu begitu fuse abis ====
-- TNTExplosion.server.lua (file berikutnya) tinggal :Connect() ke event
-- ini buat eksekusi ledakan. Server-only, makanya taro di
-- ServerScriptService (bukan ReplicatedStorage) -- client nggak perlu
-- dan nggak boleh bisa akses ini.
local tntFuseEnded = ServerScriptService:FindFirstChild("TNTFuseEnded")
if not tntFuseEnded then
	tntFuseEnded = Instance.new("BindableEvent")
	tntFuseEnded.Name = "TNTFuseEnded"
	tntFuseEnded.Parent = ServerScriptService
end

-- ==== Inisialisasi jatah TNT tiap pemain ====
-- Disimpen lewat Attribute di objek Player (otomatis direplikasi ke
-- client kalau nanti GUI mau nampilin sisa TNT -- tinggal baca Attribute
-- ini dari client, nggak perlu RemoteFunction/polling).
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("TNTCount", TNT_PER_SESSION)
end)

-- ==== Helper: 1 tile bisa ditaro TNT kalau sama persis kayak "bisa dipijak" ====
-- (bukan solid/wall/rock, DAN bukan hazard/lava) -- sengaja dipisah jadi
-- fungsi sendiri (bukan reuse langsung dari SkeletonAI, soalnya beda
-- Script/scope) tapi LOGIKANYA harus tetap sama.
local function isPlaceableTile(gx, gz)
	return not MapQuery.IsSolid(gx, gz) and not MapQuery.IsLethal(gx, gz)
end

-- ==== Helper: bikin animasi kelap-kelip yang MAKIN CEPAT mendekati detik terakhir ====
-- Part TNT itu Part biasa di workspace (Anchored), jadi properti kayak
-- Color/Transparency yang diubah di SINI (server) otomatis kereplikasi
-- ke semua client TANPA perlu LocalScript tambahan -- sama persis
-- caranya SkeletonAI gerakin part-nya cuma lewat part.Position di server.
-- ==== Animasi fuse TNT ====
-- Urutan:
-- TNT hitam
--     ?
-- putih singkat
--     ?
-- hitam
--     ?
-- putih lebih cepat
--     ?
-- hitam
--     ?
-- putih sangat cepat
--     ?
-- ledakan
--
-- Explosion ORANGE ditangani oleh TNTExplosion.server.lua
--
-- CATATAN: timing 3 tick di bawah (0.55 / 0.38 / 0.20 detik) di-HARDCODE
-- langsung, BUKAN dihitung otomatis dari FUSE_TIME. Total efektifnya
-- ~1.235 detik, sengaja dipasin deket ke FUSE_TIME=1.25. Kalau nanti
-- FUSE_TIME diubah, timing 3 angka wait ini HARUS diubah manual juga,
-- nggak otomatis nyesuaiin.
local COLOR_IDLE = Color3.fromRGB(20, 20, 20) -- hitam
local COLOR_FLASH = Color3.fromRGB(255, 255, 255) -- putih

local function runFuseAnimation(part, fuseTime)
	task.spawn(function()
		-- Total waktu dibagi menjadi 3 tahap.
		-- Tahap terakhir dibuat jauh lebih cepat supaya terasa
		-- seperti "tick... tick... TICK... DOR!"

		local FLASH_DURATION = 0.035

		-- =========================
		-- TICK 1
		-- =========================
		if not part.Parent then
			return
		end

		task.wait(0.55)

		if not part.Parent then
			return
		end

		part.Color = COLOR_FLASH
		task.wait(FLASH_DURATION)

		if not part.Parent then
			return
		end

		part.Color = COLOR_IDLE

		-- =========================
		-- TICK 2
		-- =========================
		task.wait(0.38)

		if not part.Parent then
			return
		end

		part.Color = COLOR_FLASH
		task.wait(FLASH_DURATION)

		if not part.Parent then
			return
		end

		part.Color = COLOR_IDLE

		-- =========================
		-- TICK 3 / LAST TICK
		-- =========================
		task.wait(0.20)

		if not part.Parent then
			return
		end

		part.Color = COLOR_FLASH
		task.wait(FLASH_DURATION)

		if not part.Parent then
			return
		end

		-- Setelah flash terakhir langsung kirim event ledakan
		tntFuseEnded:Fire(part)
	end)
end

-- ==== Eksekusi penempatan 1 TNT ====
local function placeTNT(player, targetGx, targetGz)
	local part = Instance.new("Part")
	part.Name = "TNT"
	part.Anchored = true
	part.CanCollide = false
	-- Ukuran = 1 tile PENUH (bukan 0.5x kayak sebelumnya) -- ini placeholder
	-- yang sengaja disamain ukurannya sama sprite ledakan yang udah kamu
	-- punya, biar pas nanti part ini diganti Decal sprite, nggak perlu
	-- ubah-ubah lagi ukuran/posisinya, tinggal ganti tampilannya doang.
	part.Size = Vector3.new(TILE, TILE, TILE)
	part.Color = COLOR_IDLE
	part.Material = Enum.Material.SmoothPlastic

	local worldPos = GridConfig.GridToWorld(targetGx, targetGz)
	part.Position = Vector3.new(worldPos.X, TILE * 0.5, worldPos.Z)

	-- Attribute ini yang bakal dibaca TNTExplosion.server.lua buat tau
	-- ini meledak di grid posisi mana & siapa yang naro (buat kill-feed
	-- nanti, MISALNYA "Budi diledakkan TNT miliknya sendiri").
	part:SetAttribute("GridX", targetGx)
	part:SetAttribute("GridZ", targetGz)
	part:SetAttribute("PlacedBy", player.UserId)

	part.Parent = workspace

	runFuseAnimation(part, FUSE_TIME)

	return part
end

-- ==== Handler request dari client ====
requestPlaceTNT.OnServerEvent:Connect(function(player, offsetDx, offsetDz)
	-- Validasi tipe & rentang offset -- JANGAN percaya client mentah-mentah,
	-- ini satu-satunya "pintu masuk" yang bisa dipanggil client kapan aja
	-- dengan payload apa aja lewat exploit, jadi semua dicek ulang di sini.
	if type(offsetDx) ~= "number" or type(offsetDz) ~= "number" then
		return
	end
	offsetDx, offsetDz = math.floor(offsetDx), math.floor(offsetDz)
	if offsetDx < -1 or offsetDx > 1 or offsetDz < -1 or offsetDz > 1 then
		return -- bukan salah satu dari 9 tile yang diperbolehkan (termasuk 0,0 = tile sendiri)
	end

	local tntCount = player:GetAttribute("TNTCount") or 0
	if tntCount <= 0 then
		return -- jatah TNT abis, nggak bisa naro lagi sampai dapet dari loot (nanti)
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not (hrp and humanoid and humanoid.Health > 0) then
		return -- pemain udah mati/nggak ada karakter, nggak masuk akal bisa naro
	end

	local playerGx, playerGz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)
	local targetGx, targetGz = playerGx + offsetDx, playerGz + offsetDz

	if not isPlaceableTile(targetGx, targetGz) then
		return -- tile tujuan solid (wall/rock) atau hazard/lava, nggak valid
	end

	player:SetAttribute("TNTCount", tntCount - 1)
	placeTNT(player, targetGx, targetGz)
end)