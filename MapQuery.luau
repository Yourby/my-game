-- MapQuery.lua  (ModuleScript)
-- Tempatkan di: ReplicatedStorage
--
-- Tempat NYIMPEN & NANYA data grid map (tile apa ada di posisi mana).
-- Ini "jembatan" antara map generator (yang nanti baca JSON Sprite Fusion
-- dan manggil SetTile untuk tiap tile) dan GridMovement (yang nanya
-- "boleh jalan ke sini nggak?" tiap kali player mau gerak).
--
-- SEKARANG: masih kosong/stub, semua tile dianggap "floor" (bisa dilewati)
-- supaya GridMovement bisa langsung dites di baseplate kosong. Begitu
-- generator map Sprite Fusion udah jadi, dia tinggal manggil SetTile()
-- untuk tiap tile sesuai layout JSON, dan MapQuery ini otomatis kepake.

local MapQuery = {}

-- tiles[gx][gz] = "floor" | "wall" | "rock" | "hazard"
local tiles = {}

local SOLID_TYPES = { wall = true, rock = true }
local LETHAL_TYPES = { hazard = true }

function MapQuery.SetTile(gx, gz, tileType)
	tiles[gx] = tiles[gx] or {}
	tiles[gx][gz] = tileType
end

function MapQuery.GetTile(gx, gz)
	local col = tiles[gx]
	if not col then
		return "floor" -- belum ada data = anggap kosong/floor (mode testing)
	end
	return col[gz] or "floor"
end

function MapQuery.IsSolid(gx, gz)
	return SOLID_TYPES[MapQuery.GetTile(gx, gz)] == true
end

function MapQuery.IsLethal(gx, gz)
	return LETHAL_TYPES[MapQuery.GetTile(gx, gz)] == true
end

return MapQuery