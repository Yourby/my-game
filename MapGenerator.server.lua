-- MapGenerator.server.lua  (Script)
-- Tempatkan di: ServerScriptService
--
-- Baca MapData (hasil export "the citadel"), lalu:
--  1) Bikin Part per tile buat SEMUA area map -- floor/wall/rock dari
--     data asli, DAN tile "lava" (id 46) buat semua area yang nggak
--     kesebut floor/wall/rock. Semua diperlakukan seragam (Part+Decal
--     individual), BUKAN 1 Part raksasa flat lagi -- biar look-nya
--     natural 2D, bukan kayak 1 warna polos nutupin semua.
--  2) Daftarin semua tile itu ke MapQuery, biar GridMovement (dan nanti
--     sistem lain kayak TNT/mining) tau tile mana yang solid/mematikan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local MapQuery = require(ReplicatedStorage:WaitForChild("MapQuery"))
local MapData = require(ReplicatedStorage:WaitForChild("MapData"))

-- Lookup sederhana: nama layer -> Asset ID gambar tile polos untuk jenis itu.
-- "hazard" sengaja dibiarin kosong dulu -- id 46 (lava) yang jadi sumber
-- textur utama buat hazard, diisi lewat ID_TEXTURES di bawah begitu
-- gambar hijau polosnya udah di-crop & upload.
local TILE_TEXTURES = {
	floor = "rbxassetid://91101911532471",
	wall = "rbxassetid://77443611775918",
	rock = "rbxassetid://130663083880504",
}

-- Lookup TAMBAHAN buat custom per-tile spesifik, berbasis `id` asli dari
-- map.json (bukan cuma nama layer). Ini yang dipakai kalau kamu mau ganti
-- satu jenis tile tertentu aja (misal tepi transisi floor-sludge) tanpa
-- ganti SEMUA tile floor jadi ikutan berubah.
--
-- id 46 = tile "lava" (dulu kepakein sebagai id nyasar pas transisi
-- floor-sludge, sekarang direpurpose khusus buat gambar hijau polos
-- lava/toxic sludge -- isi Asset ID-nya begitu udah di-crop & upload).
local ID_TEXTURES = {
	[3] = "rbxassetid://91101911532471",
	[4] = "rbxassetid://123651518468630",
	[5] = "rbxassetid://94135987745512",
	[6] = "rbxassetid://84184238655263",
	[7] = "rbxassetid://132501085111374",
	[8] = "rbxassetid://87507740788270",
	[10] = "rbxassetid://75451690569098",
	[11] = "rbxassetid://107348207230666",
	[12] = "rbxassetid://100512839262119",
	[13] = "rbxassetid://131557947531871",
	[14] = "rbxassetid://116991723657840",
	[15] = "rbxassetid://132733794075067",
	[16] = "rbxassetid://139665209579553",
	[17] = "rbxassetid://77443611775918",
	[18] = "rbxassetid://100635206248785",
	[19] = "rbxassetid://101161336869532",
	[20] = "rbxassetid://134569350320463",
	[21] = "rbxassetid://97434384425658",
	[22] = "rbxassetid://105971424060469",
	[23] = "rbxassetid://125670074886289",
	[24] = "rbxassetid://75183814456306",
	[25] = "rbxassetid://125776627467393",
	[26] = "rbxassetid://97622054550001",
	[27] = "rbxassetid://107653031821607",
	[28] = "rbxassetid://96852733647084",
	[29] = "rbxassetid://113403035131995",
	[30] = "rbxassetid://75654518463893",
	[31] = "rbxassetid://107395903585402",
	[32] = "rbxassetid://118648673266623",
	[33] = "rbxassetid://131846866952741",
	[34] = "rbxassetid://74134033915133",
	[35] = "rbxassetid://121231474161092",
	[36] = "rbxassetid://140555076038262",
	[37] = "rbxassetid://101286965543279",
	[38] = "rbxassetid://119077583970809",
	[39] = "rbxassetid://121663008513030",
	[40] = "rbxassetid://136250408008924",
	[41] = "rbxassetid://92269249040388",
	[42] = "rbxassetid://90163329014892",
	[43] = "rbxassetid://88062387633103",
	[44] = "rbxassetid://125737230007745",
	[45] = "rbxassetid://78212201065314",
	[47] = "rbxassetid://78212201065314",
	[48] = "rbxassetid://74489007422101",
	[49] = "rbxassetid://103046847507180",
	[50] = "rbxassetid://99490879935603",
	[51] = "rbxassetid://123929164567295",
	[52] = "rbxassetid://114836679249244",
	[53] = "rbxassetid://107165849733350",
	[54] = "rbxassetid://113869116819093",
	[55] = "rbxassetid://124225509794840",
	[100] = "rbxassetid://80430381289912",
	[101] = "rbxassetid://110102641086444",
	[102] = "rbxassetid://105116104033170",
	[46] = "rbxassetid://125248984148880",
}

-- Beberapa id tile (biasanya tile "transisi" di tepi floor-ke-sludge)
-- kadang kebawa masuk ke layer `floor` pas export dari Sprite Fusion,
-- padahal secara DESAIN harusnya tetap dihitung mematikan kalau diinjak
-- (sama kayak Toxic Sludge biasa) -- cuma tampilannya aja yang beda
-- (gambar transisi, bukan hijau polos).
--
-- Isi tabel ini dengan id-id tile yang mau kamu paksa jadi "hazard"
-- (mematikan) meskipun dia ada di layer floor/wall/rock. Texture-nya
-- (dari ID_TEXTURES/TILE_TEXTURES di atas) TETAP dipakai seperti biasa --
-- yang berubah cuma logic gameplay-nya, bukan tampilannya.
--
-- Cara pakai:
--   HAZARD_OVERRIDE_IDS = { [7] = true, [9] = true, [20] = true }
local HAZARD_OVERRIDE_IDS = {
	-- Semua id floor KECUALI id 3 (main floor) dan beberapa id lain yang
	-- ternyata juga aman dipijak (102, 47, 6, 5) -- id wall (10-41) &
	-- rock nggak perlu disebut di sini karena mereka layer beda, nggak
	-- pernah kepake id yang sama.
	[4] = true, [7] = true, [8] = true, [9] = true,
	[42] = true, [43] = true, [44] = true, [45] = true, [46] = true,
	[48] = true, [49] = true, [50] = true, [51] = true,
	[52] = true, [53] = true, [54] = true, [55] = true,
	[100] = true, [101] = true,
}

-- Kadang posisi tertentu KETULIS id yang salah di map.json (misal lupa
-- dibedain pas desain di Sprite Fusion -- 3 tile beda desain kebetulan
-- ketulis id yang sama). Tabel ini bilang "posisi (x,y) ini SEBENARNYA
-- id sekian", jadi dia otomatis ikut pakai texture/hazard punya id itu
-- (dari ID_TEXTURES/HAZARD_OVERRIDE_IDS di atas) -- nggak perlu diulang
-- di tempat lain.
--
-- Ini dicek PALING DULU, sebelum id asli dari map.json dipakai.
-- Value boleh id yang udah ada, ATAU angka baru yang belum pernah dipakai
-- di map.json manapun (dipakai buat desain baru yang belum resmi punya id
-- -- sengaja pilih 100+ karena id asli map.json ini nggak ada yang segitu,
-- jadi nggak akan ketabrak). Nanti tinggal isi ID_TEXTURES[100] pas
-- gambarnya udah di-crop & upload.
local POSITION_ID_OVERRIDE = {
	-- Kelompok atas (awalnya kecatat sebagai id 46)
	-- CATATAN: (34,27) & (35,27) ketuker, udah dibetulin arahnya di bawah.
	[34] = { [26] = 7, [27] = 43, [28] = 6 },
	[35] = { [26] = 8, [27] = 44, [28] = 100, [29] = 101, [30] = 102 },
	-- Kelompok bawah (awalnya kecatat sebagai id 46, kecuali (31,34) id 3)
	-- CATATAN: (30,33) & (31,33) ketuker, udah dibetulin arahnya di bawah.
	[30] = { [29] = 48, [30] = 101, [31] = 101, [32] = 55, [33] = 43, [34] = 6 },
	[31] = { [32] = 8, [33] = 44, [34] = 5 },
	-- (96,46) awalnya di-delete, sekarang jadi floor id 50
	[96] = { [46] = 50 },
	-- 3 posisi ini awalnya di-delete, sekarang dikasih id spesifik
	[10] = { [16] = 52 },
	[11] = { [15] = 52 },
	[12] = { [14] = 44 },
}

-- Posisi-posisi ini kecatat id 46 di map.json, tapi ternyata bukan bagian
-- dari desain manapun (nyasar/numpuk salah tempat pas di Sprite Fusion).
-- Tile di posisi ini SENGAJA di-skip total -- nggak dibikin Part sama
-- sekali dari data floor/wall/rock -- jadi otomatis jatuh ke tile lava
-- (bagian 2 di bawah), sama kayak area kosong lainnya.
local DELETE_POSITIONS = {
}

-- 7 posisi ini punya tile WALL yang UDAH BENAR di layer atas (jangan
-- diapa-apain) -- tapi di level BAWAHNYA (setinggi floor) kosong total,
-- padahal harusnya ada hazard/lava juga di situ (numpuk bareng wall,
-- BUKAN gantiin). Ini dipakai buat NAMBAHIN 1 Part hazard tambahan di
-- posisi yang sama, tanpa nyentuh registrasi wall yang udah benar di
-- MapQuery.
local EXTRA_HAZARD_UNDER_WALL = {
	[16] = { [53] = true },
	[17] = { [53] = true },
	[18] = { [53] = true },
	[19] = { [53] = true },
	[20] = { [53] = true },
	[33] = { [60] = true },
	[34] = { [60] = true },
}

local TILE = GridConfig.TILE

-- Posisi-posisi ini ASLINYA kosong (nggak tercatat di layer floor/wall/rock
-- manapun di map.json -- jadi sebelumnya jatuh ke lava). Tabel ini bilang
-- "posisi (x,y) ini sebenernya harus jadi tile FLOOR dengan id sekian",
-- dipakai di bagian 2 (pengisi tile kosong) di bawah, SEBELUM dia jatuh
-- ke lava. Beda sama POSITION_ID_OVERRIDE (yang cuma buat tile yang
-- SUDAH tercatat di layer floor/wall/rock).
local EXTRA_FLOOR_TILES = {
	[23] = { [27] = 7 },
	[24] = { [27] = 54 },
	[25] = { [27] = 54 },
	[26] = { [27] = 54 },
	[27] = { [26] = 48, [27] = 49 },
}

-- Mode debug (lama): label ngambang di ATAS TIAP TILE, kebanyakan &
-- bikin bingung karena numpuk semua sekaligus. Dimatiin -- diganti sama
-- Attribute per tile (nggak keliatan) + HUD kecil di pojok layar lewat
-- TileIdHUD.client.lua, yang cuma nunjukin id tile yang SEDANG diinjek
-- karakter, satu per satu.
local DEBUG_SHOW_IDS = false

local function addDebugIdLabel(part, tileId, gx, gz)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DebugIdLabel"
	billboard.Size = UDim2.new(0, 60, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s\n(%d,%d)", tostring(tileId), gx, gz)
	label.Parent = billboard
end

local mapFolder = Instance.new("Folder")
mapFolder.Name = "MapTiles"
mapFolder.Parent = workspace

-- Tinggi (Y) tiap layer, sengaja dibedain SEDIKIT (bukan ketinggian
-- gameplay, cuma buat rendering) -- soalnya kalau semua Part numpuk pas
-- di Y yang sama, Roblox jadi Z-fighting (nggak konsisten mana yang
-- tampil paling atas kalau ada 2 layer di posisi yang sama). Rock & wall
-- sengaja dikasih lebih tinggi dari floor supaya SELALU keliatan di atas
-- floor kalau ada tumpukan. Hazard/lava disamain sama floor (dasar).
local LAYER_HEIGHT = {
	floor = 0,
	wall = 0.1,
	rock = 0.1,
	hazard = 0,
}

-- Urutan proses TETAP (bukan ikut urutan asli map.json) -- floor duluan,
-- wall & rock belakangan. Ini penting bukan cuma buat visual, tapi juga
-- buat logic: kalau 1 posisi kepakein floor DAN wall/rock sekaligus,
-- yang didaftarin ke MapQuery itu yang PALING TERAKHIR diproses --
-- dengan urutan ini, wall/rock yang menang (solid), bukan floor.
local LAYER_ORDER = { "floor", "wall", "rock" }

local layersByName = {}
for _, layer in ipairs(MapData.layers) do
	layersByName[layer.name] = layer
end

-- ==== helper: tempel Decal polos ke sebuah Part berdasarkan id efektif/layer ====
local function applyTileTexture(part, layerName, effectiveId)
	local assetId = ID_TEXTURES[effectiveId] or TILE_TEXTURES[layerName]
	if not assetId then
		-- Belum ada texture buat id ini (biasanya karena belum di-crop &
		-- upload, misal id 46/lava yang masih nunggu gambar hijau
		-- polosnya). Daripada tile-nya invisible total (karena Part
		-- sendiri udah Transparency=1), kasih placeholder warna hijau
		-- neon sementara -- sama kayak tampilan background lama -- biar
		-- tetap kelihatan/gampang dites selagi nunggu texture asli siap.
		part.Transparency = 0
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(120, 214, 0)
		return
	end

	-- Decal dipakai (bukan SurfaceGui+ImageLabel lagi) karena sekarang
	-- 1 gambar = 1 tile utuh -- nggak perlu potong pixel, Decal otomatis
	-- nge-stretch gambar itu pas ke satu permukaan. Jauh lebih ringan
	-- buat performance karena cuma 1 instance per tile (bukan 2).
	local decal = Instance.new("Decal")
	decal.Name = "TileTexture"
	decal.Face = Enum.NormalId.Top
	decal.Texture = assetId
	decal.Parent = part
end

-- ==== helper: bikin 1 Part tile lengkap (dipakai buat floor/wall/rock DAN lava) ====
local function createTilePart(layerName, gx, gz, effectiveId, solid)
	local part = Instance.new("Part")
	part.Name = string.format("%s_%d_%d", layerName, gx, gz)
	part.Anchored = true
	part.CanCollide = solid
	part.Size = Vector3.new(TILE, 1, TILE)
	-- Part-nya sendiri dibuat nggak keliatan -- cuma Decal di atas yang
	-- tampil. Kalau nggak, 5 sisi Part yang nggak kepakein Decal bakal
	-- keliatan sebagai kotak abu-abu polos, apalagi di bagian gambar yang
	-- transparan (misal pinggiran rock yang nggak persegi penuh).
	part.Transparency = 1

	local worldPos = GridConfig.GridToWorld(gx, gz)
	local layerY = LAYER_HEIGHT[layerName] or 0
	part.Position = Vector3.new(worldPos.X, layerY, worldPos.Z)
	-- Disamain kayak SpriteCharacter: Decal.Face=Top butuh Part-nya
	-- sendiri yang diputer 180 derajat, bukan gambarnya, biar arah
	-- tampilan konsisten sama seluruh object lain di game ini.
	part.Orientation = Vector3.new(0, -180, 0)

	applyTileTexture(part, layerName, effectiveId)
	part.Parent = mapFolder

	-- Disimpen sebagai Attribute (nggak keliatan) biar HUD client
	-- (TileIdHUD.client.lua) bisa baca id tile yang sedang diinjek
	-- karakter, tanpa perlu label ngambang di semua tile sekaligus.
	part:SetAttribute("EffectiveId", effectiveId)

	if DEBUG_SHOW_IDS then
		addDebugIdLabel(part, effectiveId, gx, gz)
	end

	return part
end

-- ==== 1) Generate Part per tile untuk layer floor/wall/rock ====
local explicitlySet = {} -- explicitlySet[gx][gz] = true kalau udah diisi dari data asli (dan bukan yang di-delete)

for _, layerName in ipairs(LAYER_ORDER) do
	local layer = layersByName[layerName]
	if layer then
		for _, tile in ipairs(layer.tiles) do
			local isDeleted = DELETE_POSITIONS[tile.x] and DELETE_POSITIONS[tile.x][tile.y]
			if not isDeleted then
				-- Id "efektif": kalau posisi ini ada di POSITION_ID_OVERRIDE, pakai
				-- id remap itu; kalau nggak, pakai id asli dari map.json.
				local effectiveId = (POSITION_ID_OVERRIDE[tile.x] and POSITION_ID_OVERRIDE[tile.x][tile.y]) or tile.id

				-- Kalau id efektif ini masuk RANGE id wall (10-41) atau id
				-- rock (2), PAKSA jadi solid -- nggak peduli tile ini
				-- "resminya" tercatat di layer floor. Ini nutupin kasus tile
				-- yang keliatan kayak rock/wall (pakai texture wall/rock)
				-- tapi kesalahan taruh nempel di layer floor pas di Sprite
				-- Fusion, jadi nembus padahal keliatannya solid.
				local isWallOrRockId = (effectiveId >= 10 and effectiveId <= 41) or effectiveId == 2

				-- Kalau id efektif ini ada di daftar override, perlakukan sebagai
				-- hazard (mematikan, tidak solid) walaupun dia tercatat di layer
				-- floor/wall/rock -- tampilan (texture) TIDAK terpengaruh sama
				-- sekali, cuma logic gameplay-nya yang berubah.
				local isForcedHazard = HAZARD_OVERRIDE_IDS[effectiveId] == true
				local registeredLayerName = isForcedHazard and "hazard" or (isWallOrRockId and "wall") or layer.name
				local solid = isForcedHazard and false or (isWallOrRockId or layer.solid)

				createTilePart(layer.name, tile.x, tile.y, effectiveId, solid)

				MapQuery.SetTile(tile.x, tile.y, registeredLayerName)
				explicitlySet[tile.x] = explicitlySet[tile.x] or {}
				explicitlySet[tile.x][tile.y] = true
			end
		end
	end
end

-- ==== 2) Sisa tile yang nggak kesebut floor/wall/rock (termasuk yang
--         di-delete di atas) = tile lava individual (id 46), mematikan --
--         KECUALI yang ada di EXTRA_FLOOR_TILES, itu jadi floor biasa ====
local LAVA_ID = 46
local floorSolid = (layersByName.floor and layersByName.floor.solid) or false
for gx = 0, MapData.mapWidth - 1 do
	for gz = 0, MapData.mapHeight - 1 do
		local alreadySet = explicitlySet[gx] and explicitlySet[gx][gz]
		if not alreadySet then
			local extraFloorId = EXTRA_FLOOR_TILES[gx] and EXTRA_FLOOR_TILES[gx][gz]
			if extraFloorId then
				createTilePart("floor", gx, gz, extraFloorId, floorSolid)
				MapQuery.SetTile(gx, gz, "floor")
			else
				createTilePart("hazard", gx, gz, LAVA_ID, false)
				MapQuery.SetTile(gx, gz, "hazard")
			end
		end
	end
end

-- ==== 3) Hazard TAMBAHAN di bawah tile wall yang udah benar (numpuk,
--         BUKAN gantiin) -- wall di atasnya TETAP seperti biasa, MapQuery
--         TIDAK diubah (registrasi solid/wall tetap menang) ====
for gx, row in pairs(EXTRA_HAZARD_UNDER_WALL) do
	for gz, _ in pairs(row) do
		createTilePart("hazard", gx, gz, LAVA_ID, false)
	end
end

print(("[MapGenerator] Selesai. %d x %d tile ter-generate.")
	:format(MapData.mapWidth, MapData.mapHeight))
