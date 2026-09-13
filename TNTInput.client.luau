-- TNTInput.client.lua  (LocalScript)
-- Tempatkan di: StarterPlayerScripts
--
-- Input PC buat naro TNT: klik kanan di salah satu dari 9 tile valid
-- (tile sendiri + 8 tetangga termasuk diagonal) di sekitar karakter.
-- File ini CUMA nerjemahin "tile mana yang di-klik" jadi offset (dx,dz)
-- relatif ke posisi karakter, terus kirim ke server lewat
-- RequestPlaceTNT -- semua validasi beneran (jatah TNT, tile valid,
-- dll) tetap di server (TNTPlacement.server.lua), file ini nggak
-- mutusin apa-apa, cuma "penerjemah klik".
--
-- Input mobile (joystick TNT) NYUSUL di file terpisah -- sengaja nggak
-- digabung di sini biar gampang di-tes/di-utak-atik masing-masing tanpa
-- ganggu yang lain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage:WaitForChild("GridConfig"))
local requestPlaceTNT = ReplicatedStorage:WaitForChild("RequestPlaceTNT")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Debounce simpel biar 1 klik kanan = 1 kali request, nggak numpuk kalau
-- misal event-nya kepanggil dobel karena hal lain (jarang, tapi jaga-jaga).
local lastClickTime = 0
local CLICK_COOLDOWN = 0.15

mouse.Button2Down:Connect(function()
	local now = os.clock()
	if now - lastClickTime < CLICK_COOLDOWN then
		return
	end
	lastClickTime = now

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- mouse.Hit = titik di world tempat ray dari kamera ke posisi mouse
	-- kena part pertama (jalan normal walau kamera kita full custom
	-- top-down, karena mouse.Hit itu selalu ngikutin CFrame kamera yang
	-- aktif, apapun jenisnya). Tile floor/wall/rock semua Part beneran
	-- di workspace jadi otomatis kena ray ini.
	local hit = mouse.Hit
	if not hit then
		return
	end

	local targetGx, targetGz = GridConfig.WorldToGrid(hit.Position.X, hit.Position.Z)
	local playerGx, playerGz = GridConfig.WorldToGrid(hrp.Position.X, hrp.Position.Z)

	local dx = targetGx - playerGx
	local dz = targetGz - playerGz

	-- Kalau yang di-klik BUKAN salah satu dari 9 tile valid (terlalu
	-- jauh), diemin aja di sini -- nggak perlu kirim ke server sama
	-- sekali (server juga bakal nolak, tapi ngirit round-trip network
	-- buat klik yang jelas-jelas nggak valid).
	if dx < -1 or dx > 1 or dz < -1 or dz > 1 then
		return
	end

	requestPlaceTNT:FireServer(dx, dz)
end)