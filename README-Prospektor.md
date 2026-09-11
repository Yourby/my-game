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

## Keputusan Game Mode (PENTING)

Sumber kebenaran soal desain game & Team Mode: **`README_MASTER_ROBLOX_DUNGEON_GAME.md`**
(dokumen terpisah, developer yang pegang filenya — dokumen matchmaking
"min 30 pemain / tim isi 5" yang sempat dibahas itu SALAH KIRIM, bukan
buat game ini, diabaikan total).

Ringkasan penting:
- **Team Mode = mode default.** Tim isi **4 pemain** (bukan 5). Normal
  Mode (1vsAll, konsep lama) jadi mode tambahan.
- Role: Miner, Carrier (4x capacity, buat konsolidasi cargo BUKAN reward
  multiplier), Runner (mobilitas, BUKAN cuma "beli TNT"), Guardian
  (lindungin Carrier). Role = spesialisasi, nggak wajib.
- Zombie (musuh milik tim, dikeluarin buat nge-pressure tim lain) beda
  sama Skeleton (musuh dungeon murni, ada konsep sleeping/wake/path).
- Lootbag TETAP full-value, tapi ada despawn timer (~20-30 detik) biar
  nggak numpuk sampai akhir match.
- **Movement TETAP WASD/D-pad** (dokumen master nyaranin klik-tile, tapi
  developer udah putuskan pertahankan WASD yang udah jalan — ini
  keputusan sadar, bukan kelupaan).
- Sistem matchmaking penuh (voting, min player, mid-match join) BELUM
  dibangun sekarang — pakai sistem tim sederhana dulu buat beta (lihat
  roadmap di bawah).

## Status Sekarang (per sesi terakhir)

**SELESAI & JALAN — MAP FULLY RESOLVED:**
- Grid-locked movement (bukan physics bebas Roblox).
- Map generation dari Sprite Fusion export (`map.json` → `MapData.lua`)
  — semua tile floor/wall/rock/lava ter-generate otomatis dengan texture
  yang benar, rotasi benar, layering benar (nggak Z-fighting).
- Kamera top-down custom (scriptable, lookAt lurus ke bawah).
- Sistem kematian dasar kena hazard/lava (`ToxicSludgeDeath.server.lua`)
  — karakter langsung mati & berhenti total (nggak "bablas") begitu
  nginjek tile mematikan.
- Tile wall/rock BENERAN solid (nggak bisa ditembus) — termasuk kasus
  tile yang salah taruh LAYER di Sprite Fusion (lihat
  `POSITION_LAYER_OVERRIDE` di tabel bawah).
- HUD debug kecil (`TileIdHUD.client.lua`) buat lihat id+koordinat tile
  yang sedang diinjak, dipakai buat nyusun semua id mapping di atas.
- **Developer sudah konfirmasi semua bug map beres per sesi ini — siap
  lanjut ke Enemy AI.**

**BELUM DIKERJAKAN (roadmap urut):**
1. **Enemy AI (Ghost Skeleton: aggro, leash, BFS chase) — INI SELANJUTNYA**
2. Combat TNT (placement, blast radius, instant-mine crystal)
3. Random crystal spawn + mining/cargo system
4. Loot bag system (drop saat mati, bisa diambil orang lain)
5. Kill-feed notification
6. UI backend (14 mockup GUI sudah dibuat manual di Studio, belum
   disambungin ke logic)
7. Result screen
8. Setelah SEMUA di atas jalan di 1 map → replikasi ke map 2/3/4
9. Sistem rotasi/countdown antar-map (lobby)
10. Dekorasi gerak (obor di wall, gelembung di toxic sludge) — PALING AKHIR

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
| `CameraSetup.client.lua` | LocalScript | StarterPlayerScripts | Kamera scriptable top-down, `FOV=10`, `TARGET_WIDTH_STUDS=128`. **Versi yang dipakai SEKARANG = versi original (tanpa clamp)** — ada juga versi dengan clamp batas map yang disiapkan tapi TIDAK dipakai di map ini (disimpen buat map lain nanti yang punya dinding besar di pinggir). |

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
   floor), 5, 6, 45, 47, 102 yang AMAN dipijak. SEMUA id floor lainnya
   (4,7,8,9,42,43,44,46,48,49,50,51,52,53,54,55,100,101) itu MEMATIKAN.**
6. **Aturan `isWallOrRockId`** — kalau id efektif ada di range 10-41
   (wall) atau id 2 (rock), tile itu DIPAKSA solid, nggak peduli
   tercatat di layer apa. ID wall resmi: **10-41**. ID rock: **2**.
7. **`POSITION_LAYER_OVERRIDE`** — PRIORITAS PALING TINGGI dari semua
   override. Buat tile yang salah taruh LAYER (bukan cuma salah id) di
   Sprite Fusion — misal beberapa tile ditaro di layer `rock`/`wall`
   padahal harusnya floor/hazard biasa, jadi ketarik solid otomatis.
   Tabel ini paksa total jadi `"floor"` (aman) atau `"hazard"` (mati)
   di posisi tertentu, skip SEMUA aturan solid/id lainnya.
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
- **PENTING — ModuleScript TIDAK direplikasi server↔client.** Sempat
  ada bug besar: wall/rock kelihatan solid tapi karakter tetap bisa
  nembus. Ternyata `MapQuery.lua` (ModuleScript) diisi datanya lewat
  `SetTile()` di SERVER (`MapGenerator.server.lua`), tapi dibaca lewat
  `IsSolid()` di CLIENT (`GridMovement.client.lua`). Server & tiap
  client di Roblox itu masing-masing punya KOPIAN SENDIRI dari
  ModuleScript yang sama — nggak ada state yang otomatis nyambung
  antara keduanya. Solusi: data yang perlu dibaca client (solid,
  lethal, dll) HARUS disimpan lewat mekanisme yang direplikasi Roblox
  — Attribute di Instance (dipakai di sini: `part:SetAttribute("Solid", ...)`),
  RemoteEvent, atau CollectionService tag — BUKAN lewat state internal
  ModuleScript. Kalau nanti nambah sistem baru yang client perlu tau
  statusnya, selalu cek: ini dibaca dari client atau server? Kalau
  client, jangan andalkan ModuleScript buat state yang di-set server.

- **Kamera bisa "nembus" ke Baseplate default di ujung/tepi map** kalau
  map nggak punya dinding besar di pinggir. Solusi yang dipakai di map
  ini: perlebar area lava (`PADDING_TILES=16` di section 2 MapGenerator)
  jauh melewati batas asli map, JANGAN pakai clamp kamera (itu bikin
  kamera "berhenti ngikutin" karakter di ujung, terasa aneh buat map
  yang emang nggak butuh boundary tegas). Clamp kamera baru relevan buat
  map lain yang punya dinding besar di pinggir.

## File Script Terlampir

Semua isi lengkap script di atas ada di file-file `.lua` yang menyertai
dokumen ini (nama file sama persis dengan yang disebut di tabel struktur
file). Selalu pakai isi file itu sebagai sumber kebenaran, JANGAN
menebak-nebak isinya dari deskripsi di dokumen ini saja.
