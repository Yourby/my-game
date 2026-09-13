-- GridConfig.lua  (ModuleScript)
-- Tempatkan di: ReplicatedStorage
--
-- Sumber kebenaran tunggal buat ukuran tile & konversi koordinat.
-- Dipakai bareng oleh map generator, MapQuery, dan GridMovement.

local GridConfig = {}

GridConfig.TILE = 8 -- 1 tile grid = 8 stud (sesuai yang udah kamu tetapkan)

-- Grid (gx, gz) -> posisi dunia (Vector3). Y sengaja dikosongin (0) di sini
-- karena tinggi lantai itu urusan si Part masing-masing, bukan grid math.
function GridConfig.GridToWorld(gx, gz)
	local t = GridConfig.TILE
	return Vector3.new(gx * t + t / 2, 0, gz * t + t / 2)
end

-- Posisi dunia (x, z angka biasa, BUKAN Vector3) -> index grid (dibulatkan ke tile)
function GridConfig.WorldToGrid(x, z)
	local t = GridConfig.TILE
	return math.floor(x / t), math.floor(z / t)
end

return GridConfig