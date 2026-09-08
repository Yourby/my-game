# Prospektor (a.k.a Miner Dungeon) — Project Overview

Dokumen ini dibuat biar Claude (atau siapapun) bisa langsung paham project
ini di awal chat baru, tanpa perlu baca ulang histori chat yang panjang.
Kalau kamu (developer) mulai chat baru soal project ini, **upload file
ini duluan** dan bilang "aku punya project ini, lanjutin dari sini".

## Ringkasan Game

- Roblox game 2D top-down, genre mining/extraction survival + PvP loot-steal.
- Solo developer, masih belajar Roblox Studio dari nol — butuh penjelasan
  step-by-step, satu langkah/satu file per giliran.
- Workflow developer: desain/rencana di laptop pribadi, lalu eksekusi
  berat di warnet (internet stabil + testing multiplayer) seminggu sekali,
  12 jam/hari.
- Strategi rilis: ngebut ke beta dengan gameplay inti dulu (bukan nunggu
  semua fitur lengkap), untuk beta pertama target **3-4 map + 1 map event**
  dengan sistem giliran map (countdown, gilir map).
- **Urutan kerja yang disepakati**: selesaikan SATU map dengan SEMUA logic
  inti dulu (lava death, TNT, mining, enemy, escape timer, result screen)
  → baru replikasi ke map ke-2/3/4 → baru sistem rotasi/countdown antar-map
  → dekorasi gerak (obor, gelembung toxic sludge) dikerjain PALING AKHIR
  (murni kosmetik, nggak ngaruh gameplay).

### Mekanik inti
- Map = jalur floor berbatu di atas toxic sludge (lava, instant death).
  Tile yang bukan floor/wall/rock otomatis jadi toxic sludge.
- Mining crystal buat cargo % load; makin berat, makin lambat (mode normal).
- Escape = survive sampai timer habis (bukan capai titik keluar). Mati
  sebelum timer habis = gagal total, restart dari nol (no respawn-continue).
- PvP cuma TNT (nggak ada senjata lain), kena TNT = instant death, no HP system.
- Mati = cargo jatuh jadi loot bag fisik di lokasi kematian (atau tile
  aman terakhir kalau matinya di sludge) — siapa aja bisa ambil, bisa
  dirampok berantai.
- TNT: 3 fixed per sesi (no auto resupply, cuma dari loot), radius blast
  sebesar diamond, bisa instant-mine crystal, nggak bisa hancurkan rock,
  cuma bisa ditaro di tile floor (termasuk tile sendiri).
- Enemy "Ghost Skeleton": aggro zone 5x5 blok + 4 tile "tanduk" (29 tile
  total), delay 3s sebelum nyerang, leash 20 tile ke segala arah (area
  kejar 40x40), BFS pathfinding, nyerap semua cargo korban pas berhasil bunuh.
- Result screen: cargo %, crystal dibawa, jumlah skeleton dibunuh, sebab
  kematian kalau gagal.

## Status Sekarang (per sesi terakhir)

**SELESAI & JALAN:**
- Grid-locked movement (bukan physics bebas Roblox).
- Map generation dari Sprite Fusion export (`map.json` → `MapData.lua`)
  — semua tile floor/wall/rock/lava ter-generate otomatis dengan texture
  yang benar, rotasi benar, layering benar (nggak Z-fighting).
- Kamera top-down custom (scriptable, lookAt lurus ke bawah).
- Sistem kematian dasar kena hazard/lava (`ToxicSludgeDeath.server.lua`)
  — karakter langsung mati & berhenti total (nggak "bablas") begitu
  nginjek tile mematikan.
- HUD debug kecil (`TileIdHUD.client.lua`) buat lihat id+koordinat tile
  yang sedang diinjak, dipakai buat nyusun id mapping di atas.

**SEDANG DIKERJAKAN / BUG AKTIF:**
- Ada tile yang KELIHATAN kayak wall/rock (pakai texture wall/rock,
  karena kebetulan reuse angka id yang sama) tapi ternyata TERCATAT di
  layer floor di data asli, jadi masih bisa ditembus padahal keliatan
  solid. Sudah ada perbaikan umum (force-solid kalau id ada di range
  wall 10-41 atau id rock 2), TAPI developer melaporkan `(68,13)` (id 21)
  masih bisa ditembus setelah perbaikan ini — LAGI DIDEBUG, belum solve.

**BELUM DIKERJAKAN (roadmap urut):**
1. ~~Toxic Sludge death detection~~ (sudah ada versi dasarnya, tapi ada
   bug tembus di atas yang perlu selesai duluan)
2. Enemy AI (Ghost Skeleton: aggro, leash, BFS chase)
3. Combat TNT (placement, blast radius, instant-mine crystal)
4. Random crystal spawn + mining/cargo system
5. Loot bag system (drop saat mati, bisa diambil orang lain)
6. Kill-feed notification
7. UI backend (14 mockup GUI sudah dibuat manual di Studio, belum
   disambungin ke logic)
8. Result screen
9. Setelah SEMUA di atas jalan di 1 map → replikasi ke map 2/3/4
10. Sistem rotasi/countdown antar-map (lobby)
11. Dekorasi gerak (obor di wall, gelembung di toxic sludge) — PALING AKHIR

## Struktur File Roblox

| File | Tipe | Lokasi di Roblox | Fungsi |
|---|---|---|---|
| `GridConfig.lua` | ModuleScript | ReplicatedStorage | Sumber kebenaran ukuran tile (`TILE=8`) & konversi grid↔world |
| `MapQuery.lua` | ModuleScript | ReplicatedStorage | Nyimpen & nanya data tile (`SetTile`, `IsSolid`, `IsLethal`) |
| `MapData.lua` | ModuleScript | ReplicatedStorage | Hasil export map.json dari Sprite Fusion (project "the citadel", 105x68 tile) |
| `MapGenerator.server.lua` | Script | ServerScriptService | **File paling kompleks.** Generate semua Part tile dari MapData, pasang texture, atur solid/hazard, dll. Lihat detail lookup table di bawah. |
| `GridMovement.client.lua` | LocalScript | StarterPlayerScripts | Gerak grid-locked (WASD/D-pad mobile), berhenti total kalau karakter mati |
| `SpriteController.client.lua` | LocalScript | StarterPlayerScripts | Animasi sprite jalan (flip kiri-kanan) baca Attribute dari GridMovement |
| `TileIdHUD.client.lua` | LocalScript | StarterPlayerScripts | HUD kecil pojok kanan atas, nunjukin id+koordinat tile yang diinjak (debug) |
| `ToxicSludgeDeath.server.lua` | Script | ServerScriptService | Bunuh karakter yang berdiri di tile `MapQuery.IsLethal()==true` |
| `CameraSetup` (belum sempat dikasih nama file resmi) | LocalScript | ? | Kamera scriptable top-down, `FOV=10`, `TARGET_WIDTH_STUDS=128` |

**Asset yang harus tetap ada & JANGAN dihapus:**
- Roblox account: `ELNAKA09`
- Spritesheet asli (sudah tidak dipakai, ditinggalkan): `125146350375133`
- 51+ tile texture individual (per-id), lihat `ID_TEXTURES` di `MapGenerator.server.lua`

## Konsep Kunci `MapGenerator.server.lua` (WAJIB paham sebelum ubah apapun)

Tiap tile punya `layer.name` asli dari map.json (`floor`/`wall`/`rock`) DAN
`tile.id` asli. Ada beberapa layer lookup, urutan prioritas:

1. **`DELETE_POSITIONS`** — posisi yang di-skip TOTAL (dianggap kosong),
   biasanya tile nyasar/salah taruh. (Sekarang kosong, semua kasus lama
   udah dipindah ke override lain.)
2. **`POSITION_ID_OVERRIDE`** — override id SPESIFIK per koordinat (buat
   tile yang kecatat id salah di map.json, atau berbagi id sama tile lain
   yang beda desain).
3. **`EXTRA_FLOOR_TILES`** — posisi yang ASLINYA kosong di map.json,
   diubah jadi floor (aman dipijak) dengan id tertentu.
4. **`EXTRA_HAZARD_UNDER_WALL`** — nambahin Part hazard TAMBAHAN (numpuk,
   BUKAN gantiin) di bawah tile wall yang sudah benar, buat 7 posisi
   yang di floor-levelnya kosong padahal harusnya hazard.
5. **`HAZARD_OVERRIDE_IDS`** — daftar id yang dipaksa MEMATIKAN (hazard)
   walau tercatat di layer floor. **Aturan gameplay: cuma id 3 (main
   floor), 5, 6, 47, 102 yang AMAN dipijak. SEMUA id floor lainnya
   (4,7,8,9,42,43,44,45,46,48,49,50,51,52,53,54,55,100,101) itu MEMATIKAN.**
6. **Aturan `isWallOrRockId`** — kalau id efektif ada di range 10-41
   (wall) atau id 2 (rock), tile itu DIPAKSA solid, nggak peduli
   tercatat di layer apa. ID wall resmi: **10-41**. ID rock: **2**.
7. **`LAYER_ORDER`** — floor diproses duluan, wall, baru rock. Yang
   diproses TERAKHIR menang kalau ada tumpang tindih di posisi yang sama.
8. **`LAYER_HEIGHT`** — floor=0, wall/rock=0.1 (dinaikin sedikit biar
   nggak Z-fighting sama floor), hazard=0 (sejajar floor — JANGAN dibuat
   beda tinggi/jurang, pernah dicoba dan bikin karakter kerlap-kerlip
   pas gerak).
9. **id 46 = lava/hazard** (bukan id nyasar lagi seperti awalnya) — semua
   tile kosong/hazard di seluruh map SERAGAM pakai id 46, developer cuma
   perlu upload 1 gambar polos buat semua.
10. Tile Part transparan total (`Transparency=1`, cuma Decal yang keliatan)
    biar sisi kotak Part nggak keliatan pas ada bagian texture yang
    transparan (misal pinggiran rock nggak persegi penuh).
11. Semua tile Part `Orientation = (0,-180,0)` — WAJIB, karena `Decal.Face=Top`
    di Roblox butuh Part-nya sendiri yang diputer 180° (Decal nggak punya
    property rotasi sendiri). Ini bukan bug, ini cara resmi Roblox.

**Bug yang sudah kejadian & dipelajari (jangan diulang):**
- Pernah kehapus baris `local TILE = GridConfig.TILE` pas refactor besar
  → semua tile jadi ukuran 0.001 (minimum Roblox) → map keliatan kosong
  total. Selalu cek variabel inti kayak ini masih ada tiap refactor besar.
- Pernah ada duplikat key `[34]` di tabel `POSITION_ID_OVERRIDE` (2 baris
  beda nulis `[34] = {...}`) → di Lua, yang belakangan nimpa yang duluan
  TANPA ERROR. Selalu cek duplikat key kalau nambah entry ke tabel
  bertingkat.
- Idiom Lua `a and false or b` itu BERBAHAYA/gampang salah kalau `a`
  bisa true (karena hasilnya tetap jatuh ke `b`, bukan `false`, gara-gara
  Lua nggak punya ternary asli). Kalau nemu pattern ini di kode dan ada
  bug aneh soal boolean, ini yang harus dicurigai duluan.

## File Script Terlampir

Semua isi lengkap script di atas ada di file-file `.lua` yang menyertai
dokumen ini (nama file sama persis dengan yang disebut di tabel struktur
file). Selalu pakai isi file itu sebagai sumber kebenaran, JANGAN
menebak-nebak isinya dari deskripsi di dokumen ini saja.
