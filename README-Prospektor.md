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
- **Enemy AI dasar — Ghost Skeleton (`SkeletonAI.server.lua`) — SUDAH JALAN.**
  Lihat detail lengkap di bagian "Detail Implementasi Enemy AI (Ghost
  Skeleton)" di bawah. Ringkas: state machine sleeping → chasing →
  returning (+ spawnDelay buat edge case spawn), aggro zone 5x5 + 4 tile
  tanduk, leash 20 tile, BFS pathfinding di grid, repath cuma pas persis
  nyampe 1 tile (bukan di tengah transit), speed 3 tile/detik (lebih
  lambat dari pemain yang 4, biar bisa dikabur), sentuh pemain = instant
  kill server-authoritative (sama prinsipnya kayak `ToxicSludgeDeath`).
  Baru 1 home position (`{gx=66, gz=23}`) buat testing, gampang tambah
  lagi. Masih pakai placeholder visual (Part Neon polos, belum sprite).
  **Update:** loop Heartbeat-nya sekarang di-disconnect otomatis kalau
  part Skeleton dihancurkan dari luar (misal kena TNT), biar nggak error
  terus-terusan di Output setelah mati.
- **Combat TNT dasar — SUDAH JALAN.** Lihat detail lengkap di bagian
  "Detail Implementasi Combat TNT" di bawah. Ringkas: taro TNT di 9 tile
  (tile sendiri + 8 tetangga termasuk diagonal) lewat klik kanan (PC,
  `TNTInput.client.lua`) atau joystick aiming terpisah (mobile,
  `TNTMobileInput.client.lua`), fuse 1.25 detik dengan animasi
  hitam→putih 3x makin cepat (`TNTPlacement.server.lua`), lalu meledak
  (`TNTExplosion.server.lua`) — radius diamond Manhattan ≤2 (13 tile),
  bunuh SEMUA entitas hidup di dalamnya tanpa pengecualian (pemain
  sendiri, teman satu tim, skeleton), efek visual oranye sekilas. 3 TNT
  fixed per sesi per pemain (`Attribute "TNTCount"` di Player).

**BELUM DIKERJAKAN (roadmap urut):**
1. **Random crystal spawn + mining/cargo system — INI SELANJUTNYA**
2. Loot bag system (drop saat mati, bisa diambil orang lain)
3. Kill-feed notification
4. UI backend (14 mockup GUI sudah dibuat manual di Studio, belum
   disambungin ke logic)
5. Result screen
6. Setelah SEMUA di atas jalan di 1 map → replikasi ke map 2/3/4
7. Sistem rotasi/countdown antar-map (lobby)
8. Dekorasi gerak (obor di wall, gelembung di toxic sludge) — PALING AKHIR

**Nyusul belakangan buat Combat TNT (BUKAN blocker buat lanjut ke mining dulu):**
- Instant-mine crystal di tile yang kena blast (nunggu sistem
  crystal/mining di atas selesai duluan).
- TNT nggak bisa hancurkan rock — belum relevan karena belum ada sistem
  yang bisa "menghancurkan" tile sama sekali (nunggu mining).
- Ganti placeholder Part oranye jadi sprite ledakan asli yang udah kamu
  punya (tinggal ganti di `spawnExplosionVisual` di
  `TNTExplosion.server.lua`, logic kill nggak perlu diubah).
- Tampilin sisa `TNTCount` ke salah satu dari 14 GUI mockup.
- Zombie (musuh milik tim) belum ada script-nya sama sekali, jadi belum
  ikut kena blast TNT ataupun logic lain.

**Nyusul belakangan buat Enemy AI (BUKAN blocker):**
- Nyerap cargo korban saat berhasil bunuh (nunggu sistem mining/cargo di
  atas selesai duluan).
- Trigger chase dari ledakan TNT: kalau skel lagi `sleeping` ATAU
  `returning` dan area blast TNT masuk ke zona skel, langsung ngejar
  pemain yang masang TNT itu (diperlakukan sebagai kasus NORMAL masuk
  aggro zone → langsung chase, TANPA delay 3 detik). **Combat TNT-nya
  sendiri udah ada sekarang**, tapi ini belum diimplementasi karena
  butuh refactor kecil di `SkeletonAI.server.lua` dulu — state per
  Skeleton (`state.mode`) sekarang ketutup rapat di dalam closure,
  belum bisa diakses/dipicu dari script luar kayak `TNTExplosion.server.lua`.
- Konsep "sleeping kalau path ketutup mining" dari dokumen master
  (nunggu sistem mining yang bisa ngubah map).
- Sprite/animasi asli buat Ghost Skeleton (sementara placeholder Part polos).
- Tambah lebih banyak home position Skeleton di map (sekarang cuma 1
  buat testing).

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
| `SkeletonAI.server.lua` | Script | ServerScriptService | Enemy "Ghost Skeleton" — aggro/leash/BFS chase, sentuh pemain = instant kill. Lihat detail di bagian tersendiri di bawah. |
| `TNTPlacement.server.lua` | Script | ServerScriptService | Validasi & taro TNT di 9 tile (sendiri+8 tetangga), jalanin fuse 1.25 detik + animasi, fire `TNTFuseEnded` |
| `TNTInput.client.lua` | LocalScript | StarterPlayerScripts | Input PC: klik kanan tile → kirim offset ke server |
| `TNTMobileInput.client.lua` | LocalScript | StarterPlayerScripts | Input mobile: joystick aiming terpisah dari D-pad gerak, taro di pojok kanan bawah |
| `TNTExplosion.server.lua` | Script | ServerScriptService | Dengerin `TNTFuseEnded`, eksekusi ledakan (radius diamond, bunuh semua entitas, efek oranye). Lihat detail di bagian tersendiri di bawah. |
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

## Detail Implementasi Enemy AI (Ghost Skeleton)

`SkeletonAI.server.lua` — server-authoritative (sama filosofinya kayak
`ToxicSludgeDeath.server.lua`: keputusan "kena/nggak" nggak boleh
dicurangi client). Ini versi DASAR, sengaja disederhanakan biar cepat
dites; beberapa hal disebutkan di bagian roadmap "nyusul belakangan"
karena nunggu sistem lain (mining/cargo, TNT) selesai duluan.

**State machine per Skeleton** (`state.mode`):
- `sleeping` — diam di rumah (home). Begitu ADA pemain masuk aggro zone,
  langsung pindah ke `chasing` TANPA delay — ini kasus NORMAL.
- `spawnDelay` — HANYA terjadi kalau pas Skeleton baru spawn, ternyata
  udah ada pemain di dalam aggro zone-nya saat itu juga (misal pemain
  lagi mining pas Skeleton spawn deket dia). Kasih grace period
  `SPAWN_DELAY = 3` detik, lalu dicek ulang: kalau pemain itu MASIH di
  zone → lanjut `chasing`; kalau udah kabur duluan → balik `sleeping`.
- `chasing` — ngejar target lewat BFS pathfinding di grid (lihat di
  bawah). Kalau target keluar leash / disconnect / mati dan nggak ada
  pemain lain di aggro zone → nyerah, pindah ke `returning`.
- `returning` — jalan pulang ke home lewat BFS. Kalau pas jalan pulang
  ada pemain masuk aggro zone lagi, itu dianggap kasus NORMAL juga →
  langsung `chasing` lagi (tanpa delay). Begitu nyampe home → balik
  `sleeping`.

**Aggro zone** (`isInAggroZone`): blok 5x5 di sekitar home (-2..+2 di
kedua sumbu) + 4 tile "tanduk" yang nempel di tengah tiap sisi blok
(total 29 tile), persis sesuai desain di ringkasan game di atas.

**Leash** (`isWithinLeash`): kotak 20 tile ke segala arah dari home
(area total 40x40) — dicek pakai jarak per-sumbu (`math.abs(dx) <= 20`
dan `math.abs(dz) <= 20`), bukan jarak radius/euclidean.

**BFS pathfinding** (`findPath`): grid 4-arah (bukan diagonal), tile
harus `isWalkableTile` (bukan solid/wall/rock DAN bukan hazard/lava)
DAN masih dalam leash dari home. Repath (`REPATH_INTERVAL = 0.3` detik)
**cuma boleh terjadi pas Skeleton PERSIS baru nyampe 1 tile penuh**
(`arrivedTile == true`) atau pas emang belum punya path sama sekali —
sengaja TIDAK PERNAH di tengah-tengah transit antar tile, karena itu
penyebab lama Skeleton kelihatan "motong" diagonal kalau BFS nemu rute
baru pas lagi jalan.

**Kecepatan & kontak**: `MOVE_SPEED_TILES_PER_SEC = 3`, sengaja lebih
lambat dari kecepatan pemain (4 tile/detik di `GridMovement.client.lua`)
biar pemain masih bisa kabur. Kontak dicek per-frame di mode `chasing`:
kalau grid position Skeleton == grid position target → `humanoid.Health
= 0` (instant kill, sama prinsipnya kayak toxic sludge).

**Config saat ini**: baru 1 home di `SKELETON_HOMES` (`{gx=66, gz=23}`),
tinggal tambah baris lagi ke tabel itu kalau mau lebih dari 1 Skeleton.
Visual masih placeholder (Part polos warna putih, material Neon,
ukuran 0.7 tile) — gampang diganti Decal/sprite asli belakangan tanpa
ubah logic AI-nya sama sekali.

## Detail Implementasi Combat TNT

Alur kerja 4 file (sengaja dipisah per tanggung jawab, gampang di-tes/
di-utak-atik satu-satu):

1. **Input** (`TNTInput.client.lua` buat PC, `TNTMobileInput.client.lua`
   buat mobile) — nerjemahin gesture (klik kanan tile / geser+lepas
   joystick) jadi offset `(dx, dz)` relatif ke posisi pemain, masing2
   -1/0/1, lalu `RequestPlaceTNT:FireServer(dx, dz)`. File ini **nggak
   mutusin valid/nggaknya apapun** — semua validasi ulang di server.
   - PC: klik kanan tile manapun, dihitung dari `mouse.Hit` lalu
     dikonversi ke grid & dibandingkan sama posisi pemain.
   - Mobile: joystick TERPISAH dari D-pad gerak (pojok kanan bawah vs
     kiri bawah), 8 arah + dead zone tengah (= taro di tile sendiri),
     nunjukin simbol panah pas lagi digeser.
2. **Penempatan & fuse** (`TNTPlacement.server.lua`) — validasi ulang di
   server (jatah `TNTCount` di Attribute Player, tile harus salah satu
   dari 9 pilihan & bukan solid/hazard), taro Part TNT seukuran 1 tile,
   jalanin animasi fuse `FUSE_TIME=1.25` detik: hitam → putih (tick 1,
   jeda 0.55s) → hitam → putih (tick 2, jeda 0.38s) → hitam → putih
   (tick 3, jeda 0.20s) → **timing 3 tick ini di-HARDCODE, BUKAN
   dihitung otomatis dari `FUSE_TIME`** — kalau `FUSE_TIME` diubah,
   3 angka jeda itu harus diubah manual juga. Begitu tick terakhir abis,
   fire `TNTFuseEnded` (BindableEvent di ServerScriptService, server-only).
3. **Ledakan** (`TNTExplosion.server.lua`) — dengerin `TNTFuseEnded`,
   hitung semua tile dalam radius diamond (`|dx|+|dz| <= 2` dari titik
   taro, 13 tile total), munculin Part oranye Neon sekilas (0.25 detik)
   di tiap tile itu sebagai placeholder efek ledakan, lalu bunuh **SEMUA**
   entitas hidup yang grid position-nya masuk area itu — pemain (nggak
   ada pengecualian sama sekali, termasuk yang naro TNT-nya sendiri &
   teman satu timnya) dan Ghost Skeleton (`:Destroy()` part-nya).

**Kenapa Skeleton bisa ikut mati kena TNT:** `SkeletonAI.server.lua`
awalnya nggak pernah cek apakah part-nya masih ada pas loop
`RunService.Heartbeat` jalan tiap frame — kalau langsung `:Destroy()`
dari luar, bakal error terus-terusan. Sekarang loop itu ngecek
`part.Parent` di awal tiap frame, dan `:Disconnect()` diri sendiri kalau
part-nya udah hilang.

**Belum diimplementasi (lihat juga roadmap):** instant-mine crystal
(nunggu sistem mining), TNT nggak bisa hancurkan rock (belum relevan,
belum ada sistem hancurin tile), trigger bangunin Skeleton yang lagi
`sleeping`/`returning` dari blast TNT (butuh refactor `SkeletonAI` biar
state-nya bisa diakses dari luar), ganti placeholder oranye jadi sprite
ledakan asli, dan nampilin sisa `TNTCount` ke GUI.

## File Script Terlampir

Semua isi lengkap script di atas ada di file-file `.lua` yang menyertai
dokumen ini (nama file sama persis dengan yang disebut di tabel struktur
file). Selalu pakai isi file itu sebagai sumber kebenaran, JANGAN
menebak-nebak isinya dari deskripsi di dokumen ini saja.# Prospektor (a.k.a Miner Dungeon) — Project Overview

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
- **Enemy AI dasar — Ghost Skeleton (`SkeletonAI.server.lua`) — SUDAH JALAN.**
  Lihat detail lengkap di bagian "Detail Implementasi Enemy AI (Ghost
  Skeleton)" di bawah. Ringkas: state machine sleeping → chasing →
  returning (+ spawnDelay buat edge case spawn), aggro zone 5x5 + 4 tile
  tanduk, leash 20 tile, BFS pathfinding di grid, repath cuma pas persis
  nyampe 1 tile (bukan di tengah transit), speed 3 tile/detik (lebih
  lambat dari pemain yang 4, biar bisa dikabur), sentuh pemain = instant
  kill server-authoritative (sama prinsipnya kayak `ToxicSludgeDeath`).
  Baru 1 home position (`{gx=66, gz=23}`) buat testing, gampang tambah
  lagi. Masih pakai placeholder visual (Part Neon polos, belum sprite).
  **Update:** loop Heartbeat-nya sekarang di-disconnect otomatis kalau
  part Skeleton dihancurkan dari luar (misal kena TNT), biar nggak error
  terus-terusan di Output setelah mati.
- **Combat TNT dasar — SUDAH JALAN.** Lihat detail lengkap di bagian
  "Detail Implementasi Combat TNT" di bawah. Ringkas: taro TNT di 9 tile
  (tile sendiri + 8 tetangga termasuk diagonal) lewat klik kanan (PC,
  `TNTInput.client.lua`) atau joystick aiming terpisah (mobile,
  `TNTMobileInput.client.lua`), fuse 1.25 detik dengan animasi
  hitam→putih 3x makin cepat (`TNTPlacement.server.lua`), lalu meledak
  (`TNTExplosion.server.lua`) — radius diamond Manhattan ≤2 (13 tile),
  bunuh SEMUA entitas hidup di dalamnya tanpa pengecualian (pemain
  sendiri, teman satu tim, skeleton), efek visual oranye sekilas. 3 TNT
  fixed per sesi per pemain (`Attribute "TNTCount"` di Player).

**BELUM DIKERJAKAN (roadmap urut):**
1. **Random crystal spawn + mining/cargo system — INI SELANJUTNYA**
2. Loot bag system (drop saat mati, bisa diambil orang lain)
3. Kill-feed notification
4. UI backend (14 mockup GUI sudah dibuat manual di Studio, belum
   disambungin ke logic)
5. Result screen
6. Setelah SEMUA di atas jalan di 1 map → replikasi ke map 2/3/4
7. Sistem rotasi/countdown antar-map (lobby)
8. Dekorasi gerak (obor di wall, gelembung di toxic sludge) — PALING AKHIR

**Nyusul belakangan buat Combat TNT (BUKAN blocker buat lanjut ke mining dulu):**
- Instant-mine crystal di tile yang kena blast (nunggu sistem
  crystal/mining di atas selesai duluan).
- TNT nggak bisa hancurkan rock — belum relevan karena belum ada sistem
  yang bisa "menghancurkan" tile sama sekali (nunggu mining).
- Ganti placeholder Part oranye jadi sprite ledakan asli yang udah kamu
  punya (tinggal ganti di `spawnExplosionVisual` di
  `TNTExplosion.server.lua`, logic kill nggak perlu diubah).
- Tampilin sisa `TNTCount` ke salah satu dari 14 GUI mockup.
- Zombie (musuh milik tim) belum ada script-nya sama sekali, jadi belum
  ikut kena blast TNT ataupun logic lain.

**Nyusul belakangan buat Enemy AI (BUKAN blocker):**
- Nyerap cargo korban saat berhasil bunuh (nunggu sistem mining/cargo di
  atas selesai duluan).
- Trigger chase dari ledakan TNT: kalau skel lagi `sleeping` ATAU
  `returning` dan area blast TNT masuk ke zona skel, langsung ngejar
  pemain yang masang TNT itu (diperlakukan sebagai kasus NORMAL masuk
  aggro zone → langsung chase, TANPA delay 3 detik). **Combat TNT-nya
  sendiri udah ada sekarang**, tapi ini belum diimplementasi karena
  butuh refactor kecil di `SkeletonAI.server.lua` dulu — state per
  Skeleton (`state.mode`) sekarang ketutup rapat di dalam closure,
  belum bisa diakses/dipicu dari script luar kayak `TNTExplosion.server.lua`.
- Konsep "sleeping kalau path ketutup mining" dari dokumen master
  (nunggu sistem mining yang bisa ngubah map).
- Sprite/animasi asli buat Ghost Skeleton (sementara placeholder Part polos).
- Tambah lebih banyak home position Skeleton di map (sekarang cuma 1
  buat testing).

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
| `SkeletonAI.server.lua` | Script | ServerScriptService | Enemy "Ghost Skeleton" — aggro/leash/BFS chase, sentuh pemain = instant kill. Lihat detail di bagian tersendiri di bawah. |
| `TNTPlacement.server.lua` | Script | ServerScriptService | Validasi & taro TNT di 9 tile (sendiri+8 tetangga), jalanin fuse 1.25 detik + animasi, fire `TNTFuseEnded` |
| `TNTInput.client.lua` | LocalScript | StarterPlayerScripts | Input PC: klik kanan tile → kirim offset ke server |
| `TNTMobileInput.client.lua` | LocalScript | StarterPlayerScripts | Input mobile: joystick aiming terpisah dari D-pad gerak, taro di pojok kanan bawah |
| `TNTExplosion.server.lua` | Script | ServerScriptService | Dengerin `TNTFuseEnded`, eksekusi ledakan (radius diamond, bunuh semua entitas, efek oranye). Lihat detail di bagian tersendiri di bawah. |
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

## Detail Implementasi Enemy AI (Ghost Skeleton)

`SkeletonAI.server.lua` — server-authoritative (sama filosofinya kayak
`ToxicSludgeDeath.server.lua`: keputusan "kena/nggak" nggak boleh
dicurangi client). Ini versi DASAR, sengaja disederhanakan biar cepat
dites; beberapa hal disebutkan di bagian roadmap "nyusul belakangan"
karena nunggu sistem lain (mining/cargo, TNT) selesai duluan.

**State machine per Skeleton** (`state.mode`):
- `sleeping` — diam di rumah (home). Begitu ADA pemain masuk aggro zone,
  langsung pindah ke `chasing` TANPA delay — ini kasus NORMAL.
- `spawnDelay` — HANYA terjadi kalau pas Skeleton baru spawn, ternyata
  udah ada pemain di dalam aggro zone-nya saat itu juga (misal pemain
  lagi mining pas Skeleton spawn deket dia). Kasih grace period
  `SPAWN_DELAY = 3` detik, lalu dicek ulang: kalau pemain itu MASIH di
  zone → lanjut `chasing`; kalau udah kabur duluan → balik `sleeping`.
- `chasing` — ngejar target lewat BFS pathfinding di grid (lihat di
  bawah). Kalau target keluar leash / disconnect / mati dan nggak ada
  pemain lain di aggro zone → nyerah, pindah ke `returning`.
- `returning` — jalan pulang ke home lewat BFS. Kalau pas jalan pulang
  ada pemain masuk aggro zone lagi, itu dianggap kasus NORMAL juga →
  langsung `chasing` lagi (tanpa delay). Begitu nyampe home → balik
  `sleeping`.

**Aggro zone** (`isInAggroZone`): blok 5x5 di sekitar home (-2..+2 di
kedua sumbu) + 4 tile "tanduk" yang nempel di tengah tiap sisi blok
(total 29 tile), persis sesuai desain di ringkasan game di atas.

**Leash** (`isWithinLeash`): kotak 20 tile ke segala arah dari home
(area total 40x40) — dicek pakai jarak per-sumbu (`math.abs(dx) <= 20`
dan `math.abs(dz) <= 20`), bukan jarak radius/euclidean.

**BFS pathfinding** (`findPath`): grid 4-arah (bukan diagonal), tile
harus `isWalkableTile` (bukan solid/wall/rock DAN bukan hazard/lava)
DAN masih dalam leash dari home. Repath (`REPATH_INTERVAL = 0.3` detik)
**cuma boleh terjadi pas Skeleton PERSIS baru nyampe 1 tile penuh**
(`arrivedTile == true`) atau pas emang belum punya path sama sekali —
sengaja TIDAK PERNAH di tengah-tengah transit antar tile, karena itu
penyebab lama Skeleton kelihatan "motong" diagonal kalau BFS nemu rute
baru pas lagi jalan.

**Kecepatan & kontak**: `MOVE_SPEED_TILES_PER_SEC = 3`, sengaja lebih
lambat dari kecepatan pemain (4 tile/detik di `GridMovement.client.lua`)
biar pemain masih bisa kabur. Kontak dicek per-frame di mode `chasing`:
kalau grid position Skeleton == grid position target → `humanoid.Health
= 0` (instant kill, sama prinsipnya kayak toxic sludge).

**Config saat ini**: baru 1 home di `SKELETON_HOMES` (`{gx=66, gz=23}`),
tinggal tambah baris lagi ke tabel itu kalau mau lebih dari 1 Skeleton.
Visual masih placeholder (Part polos warna putih, material Neon,
ukuran 0.7 tile) — gampang diganti Decal/sprite asli belakangan tanpa
ubah logic AI-nya sama sekali.

## Detail Implementasi Combat TNT

Alur kerja 4 file (sengaja dipisah per tanggung jawab, gampang di-tes/
di-utak-atik satu-satu):

1. **Input** (`TNTInput.client.lua` buat PC, `TNTMobileInput.client.lua`
   buat mobile) — nerjemahin gesture (klik kanan tile / geser+lepas
   joystick) jadi offset `(dx, dz)` relatif ke posisi pemain, masing2
   -1/0/1, lalu `RequestPlaceTNT:FireServer(dx, dz)`. File ini **nggak
   mutusin valid/nggaknya apapun** — semua validasi ulang di server.
   - PC: klik kanan tile manapun, dihitung dari `mouse.Hit` lalu
     dikonversi ke grid & dibandingkan sama posisi pemain.
   - Mobile: joystick TERPISAH dari D-pad gerak (pojok kanan bawah vs
     kiri bawah), 8 arah + dead zone tengah (= taro di tile sendiri),
     nunjukin simbol panah pas lagi digeser.
2. **Penempatan & fuse** (`TNTPlacement.server.lua`) — validasi ulang di
   server (jatah `TNTCount` di Attribute Player, tile harus salah satu
   dari 9 pilihan & bukan solid/hazard), taro Part TNT seukuran 1 tile,
   jalanin animasi fuse `FUSE_TIME=1.25` detik: hitam → putih (tick 1,
   jeda 0.55s) → hitam → putih (tick 2, jeda 0.38s) → hitam → putih
   (tick 3, jeda 0.20s) → **timing 3 tick ini di-HARDCODE, BUKAN
   dihitung otomatis dari `FUSE_TIME`** — kalau `FUSE_TIME` diubah,
   3 angka jeda itu harus diubah manual juga. Begitu tick terakhir abis,
   fire `TNTFuseEnded` (BindableEvent di ServerScriptService, server-only).
3. **Ledakan** (`TNTExplosion.server.lua`) — dengerin `TNTFuseEnded`,
   hitung semua tile dalam radius diamond (`|dx|+|dz| <= 2` dari titik
   taro, 13 tile total), munculin Part oranye Neon sekilas (0.25 detik)
   di tiap tile itu sebagai placeholder efek ledakan, lalu bunuh **SEMUA**
   entitas hidup yang grid position-nya masuk area itu — pemain (nggak
   ada pengecualian sama sekali, termasuk yang naro TNT-nya sendiri &
   teman satu timnya) dan Ghost Skeleton (`:Destroy()` part-nya).

**Kenapa Skeleton bisa ikut mati kena TNT:** `SkeletonAI.server.lua`
awalnya nggak pernah cek apakah part-nya masih ada pas loop
`RunService.Heartbeat` jalan tiap frame — kalau langsung `:Destroy()`
dari luar, bakal error terus-terusan. Sekarang loop itu ngecek
`part.Parent` di awal tiap frame, dan `:Disconnect()` diri sendiri kalau
part-nya udah hilang.

**Belum diimplementasi (lihat juga roadmap):** instant-mine crystal
(nunggu sistem mining), TNT nggak bisa hancurkan rock (belum relevan,
belum ada sistem hancurin tile), trigger bangunin Skeleton yang lagi
`sleeping`/`returning` dari blast TNT (butuh refactor `SkeletonAI` biar
state-nya bisa diakses dari luar), ganti placeholder oranye jadi sprite
ledakan asli, dan nampilin sisa `TNTCount` ke GUI.

## File Script Terlampir

Semua isi lengkap script di atas ada di file-file `.lua` yang menyertai
dokumen ini (nama file sama persis dengan yang disebut di tabel struktur
file). Selalu pakai isi file itu sebagai sumber kebenaran, JANGAN
menebak-nebak isinya dari deskripsi di dokumen ini saja.# Prospektor (a.k.a Miner Dungeon) — Project Overview

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
- **Enemy AI dasar — Ghost Skeleton (`SkeletonAI.server.lua`) — SUDAH JALAN.**
  Lihat detail lengkap di bagian "Detail Implementasi Enemy AI (Ghost
  Skeleton)" di bawah. Ringkas: state machine sleeping → chasing →
  returning (+ spawnDelay buat edge case spawn), aggro zone 5x5 + 4 tile
  tanduk, leash 20 tile, BFS pathfinding di grid, repath cuma pas persis
  nyampe 1 tile (bukan di tengah transit), speed 3 tile/detik (lebih
  lambat dari pemain yang 4, biar bisa dikabur), sentuh pemain = instant
  kill server-authoritative (sama prinsipnya kayak `ToxicSludgeDeath`).
  Baru 1 home position (`{gx=66, gz=23}`) buat testing, gampang tambah
  lagi. Masih pakai placeholder visual (Part Neon polos, belum sprite).
  **Update:** loop Heartbeat-nya sekarang di-disconnect otomatis kalau
  part Skeleton dihancurkan dari luar (misal kena TNT), biar nggak error
  terus-terusan di Output setelah mati.
- **Combat TNT dasar — SUDAH JALAN.** Lihat detail lengkap di bagian
  "Detail Implementasi Combat TNT" di bawah. Ringkas: taro TNT di 9 tile
  (tile sendiri + 8 tetangga termasuk diagonal) lewat klik kanan (PC,
  `TNTInput.client.lua`) atau joystick aiming terpisah (mobile,
  `TNTMobileInput.client.lua`), fuse 1.25 detik dengan animasi
  hitam→putih 3x makin cepat (`TNTPlacement.server.lua`), lalu meledak
  (`TNTExplosion.server.lua`) — radius diamond Manhattan ≤2 (13 tile),
  bunuh SEMUA entitas hidup di dalamnya tanpa pengecualian (pemain
  sendiri, teman satu tim, skeleton), efek visual oranye sekilas. 3 TNT
  fixed per sesi per pemain (`Attribute "TNTCount"` di Player).

**BELUM DIKERJAKAN (roadmap urut):**
1. **Random crystal spawn + mining/cargo system — INI SELANJUTNYA**
2. Loot bag system (drop saat mati, bisa diambil orang lain)
3. Kill-feed notification
4. UI backend (14 mockup GUI sudah dibuat manual di Studio, belum
   disambungin ke logic)
5. Result screen
6. Setelah SEMUA di atas jalan di 1 map → replikasi ke map 2/3/4
7. Sistem rotasi/countdown antar-map (lobby)
8. Dekorasi gerak (obor di wall, gelembung di toxic sludge) — PALING AKHIR

**Nyusul belakangan buat Combat TNT (BUKAN blocker buat lanjut ke mining dulu):**
- Instant-mine crystal di tile yang kena blast (nunggu sistem
  crystal/mining di atas selesai duluan).
- TNT nggak bisa hancurkan rock — belum relevan karena belum ada sistem
  yang bisa "menghancurkan" tile sama sekali (nunggu mining).
- Ganti placeholder Part oranye jadi sprite ledakan asli yang udah kamu
  punya (tinggal ganti di `spawnExplosionVisual` di
  `TNTExplosion.server.lua`, logic kill nggak perlu diubah).
- Tampilin sisa `TNTCount` ke salah satu dari 14 GUI mockup.
- Zombie (musuh milik tim) belum ada script-nya sama sekali, jadi belum
  ikut kena blast TNT ataupun logic lain.

**Nyusul belakangan buat Enemy AI (BUKAN blocker):**
- Nyerap cargo korban saat berhasil bunuh (nunggu sistem mining/cargo di
  atas selesai duluan).
- Trigger chase dari ledakan TNT: kalau skel lagi `sleeping` ATAU
  `returning` dan area blast TNT masuk ke zona skel, langsung ngejar
  pemain yang masang TNT itu (diperlakukan sebagai kasus NORMAL masuk
  aggro zone → langsung chase, TANPA delay 3 detik). **Combat TNT-nya
  sendiri udah ada sekarang**, tapi ini belum diimplementasi karena
  butuh refactor kecil di `SkeletonAI.server.lua` dulu — state per
  Skeleton (`state.mode`) sekarang ketutup rapat di dalam closure,
  belum bisa diakses/dipicu dari script luar kayak `TNTExplosion.server.lua`.
- Konsep "sleeping kalau path ketutup mining" dari dokumen master
  (nunggu sistem mining yang bisa ngubah map).
- Sprite/animasi asli buat Ghost Skeleton (sementara placeholder Part polos).
- Tambah lebih banyak home position Skeleton di map (sekarang cuma 1
  buat testing).

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
| `SkeletonAI.server.lua` | Script | ServerScriptService | Enemy "Ghost Skeleton" — aggro/leash/BFS chase, sentuh pemain = instant kill. Lihat detail di bagian tersendiri di bawah. |
| `TNTPlacement.server.lua` | Script | ServerScriptService | Validasi & taro TNT di 9 tile (sendiri+8 tetangga), jalanin fuse 1.25 detik + animasi, fire `TNTFuseEnded` |
| `TNTInput.client.lua` | LocalScript | StarterPlayerScripts | Input PC: klik kanan tile → kirim offset ke server |
| `TNTMobileInput.client.lua` | LocalScript | StarterPlayerScripts | Input mobile: joystick aiming terpisah dari D-pad gerak, taro di pojok kanan bawah |
| `TNTExplosion.server.lua` | Script | ServerScriptService | Dengerin `TNTFuseEnded`, eksekusi ledakan (radius diamond, bunuh semua entitas, efek oranye). Lihat detail di bagian tersendiri di bawah. |
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

## Detail Implementasi Enemy AI (Ghost Skeleton)

`SkeletonAI.server.lua` — server-authoritative (sama filosofinya kayak
`ToxicSludgeDeath.server.lua`: keputusan "kena/nggak" nggak boleh
dicurangi client). Ini versi DASAR, sengaja disederhanakan biar cepat
dites; beberapa hal disebutkan di bagian roadmap "nyusul belakangan"
karena nunggu sistem lain (mining/cargo, TNT) selesai duluan.

**State machine per Skeleton** (`state.mode`):
- `sleeping` — diam di rumah (home). Begitu ADA pemain masuk aggro zone,
  langsung pindah ke `chasing` TANPA delay — ini kasus NORMAL.
- `spawnDelay` — HANYA terjadi kalau pas Skeleton baru spawn, ternyata
  udah ada pemain di dalam aggro zone-nya saat itu juga (misal pemain
  lagi mining pas Skeleton spawn deket dia). Kasih grace period
  `SPAWN_DELAY = 3` detik, lalu dicek ulang: kalau pemain itu MASIH di
  zone → lanjut `chasing`; kalau udah kabur duluan → balik `sleeping`.
- `chasing` — ngejar target lewat BFS pathfinding di grid (lihat di
  bawah). Kalau target keluar leash / disconnect / mati dan nggak ada
  pemain lain di aggro zone → nyerah, pindah ke `returning`.
- `returning` — jalan pulang ke home lewat BFS. Kalau pas jalan pulang
  ada pemain masuk aggro zone lagi, itu dianggap kasus NORMAL juga →
  langsung `chasing` lagi (tanpa delay). Begitu nyampe home → balik
  `sleeping`.

**Aggro zone** (`isInAggroZone`): blok 5x5 di sekitar home (-2..+2 di
kedua sumbu) + 4 tile "tanduk" yang nempel di tengah tiap sisi blok
(total 29 tile), persis sesuai desain di ringkasan game di atas.

**Leash** (`isWithinLeash`): kotak 20 tile ke segala arah dari home
(area total 40x40) — dicek pakai jarak per-sumbu (`math.abs(dx) <= 20`
dan `math.abs(dz) <= 20`), bukan jarak radius/euclidean.

**BFS pathfinding** (`findPath`): grid 4-arah (bukan diagonal), tile
harus `isWalkableTile` (bukan solid/wall/rock DAN bukan hazard/lava)
DAN masih dalam leash dari home. Repath (`REPATH_INTERVAL = 0.3` detik)
**cuma boleh terjadi pas Skeleton PERSIS baru nyampe 1 tile penuh**
(`arrivedTile == true`) atau pas emang belum punya path sama sekali —
sengaja TIDAK PERNAH di tengah-tengah transit antar tile, karena itu
penyebab lama Skeleton kelihatan "motong" diagonal kalau BFS nemu rute
baru pas lagi jalan.

**Kecepatan & kontak**: `MOVE_SPEED_TILES_PER_SEC = 3`, sengaja lebih
lambat dari kecepatan pemain (4 tile/detik di `GridMovement.client.lua`)
biar pemain masih bisa kabur. Kontak dicek per-frame di mode `chasing`:
kalau grid position Skeleton == grid position target → `humanoid.Health
= 0` (instant kill, sama prinsipnya kayak toxic sludge).

**Config saat ini**: baru 1 home di `SKELETON_HOMES` (`{gx=66, gz=23}`),
tinggal tambah baris lagi ke tabel itu kalau mau lebih dari 1 Skeleton.
Visual masih placeholder (Part polos warna putih, material Neon,
ukuran 0.7 tile) — gampang diganti Decal/sprite asli belakangan tanpa
ubah logic AI-nya sama sekali.

## Detail Implementasi Combat TNT

Alur kerja 4 file (sengaja dipisah per tanggung jawab, gampang di-tes/
di-utak-atik satu-satu):

1. **Input** (`TNTInput.client.lua` buat PC, `TNTMobileInput.client.lua`
   buat mobile) — nerjemahin gesture (klik kanan tile / geser+lepas
   joystick) jadi offset `(dx, dz)` relatif ke posisi pemain, masing2
   -1/0/1, lalu `RequestPlaceTNT:FireServer(dx, dz)`. File ini **nggak
   mutusin valid/nggaknya apapun** — semua validasi ulang di server.
   - PC: klik kanan tile manapun, dihitung dari `mouse.Hit` lalu
     dikonversi ke grid & dibandingkan sama posisi pemain.
   - Mobile: joystick TERPISAH dari D-pad gerak (pojok kanan bawah vs
     kiri bawah), 8 arah + dead zone tengah (= taro di tile sendiri),
     nunjukin simbol panah pas lagi digeser.
2. **Penempatan & fuse** (`TNTPlacement.server.lua`) — validasi ulang di
   server (jatah `TNTCount` di Attribute Player, tile harus salah satu
   dari 9 pilihan & bukan solid/hazard), taro Part TNT seukuran 1 tile,
   jalanin animasi fuse `FUSE_TIME=1.25` detik: hitam → putih (tick 1,
   jeda 0.55s) → hitam → putih (tick 2, jeda 0.38s) → hitam → putih
   (tick 3, jeda 0.20s) → **timing 3 tick ini di-HARDCODE, BUKAN
   dihitung otomatis dari `FUSE_TIME`** — kalau `FUSE_TIME` diubah,
   3 angka jeda itu harus diubah manual juga. Begitu tick terakhir abis,
   fire `TNTFuseEnded` (BindableEvent di ServerScriptService, server-only).
3. **Ledakan** (`TNTExplosion.server.lua`) — dengerin `TNTFuseEnded`,
   hitung semua tile dalam radius diamond (`|dx|+|dz| <= 2` dari titik
   taro, 13 tile total), munculin Part oranye Neon sekilas (0.25 detik)
   di tiap tile itu sebagai placeholder efek ledakan, lalu bunuh **SEMUA**
   entitas hidup yang grid position-nya masuk area itu — pemain (nggak
   ada pengecualian sama sekali, termasuk yang naro TNT-nya sendiri &
   teman satu timnya) dan Ghost Skeleton (`:Destroy()` part-nya).

**Kenapa Skeleton bisa ikut mati kena TNT:** `SkeletonAI.server.lua`
awalnya nggak pernah cek apakah part-nya masih ada pas loop
`RunService.Heartbeat` jalan tiap frame — kalau langsung `:Destroy()`
dari luar, bakal error terus-terusan. Sekarang loop itu ngecek
`part.Parent` di awal tiap frame, dan `:Disconnect()` diri sendiri kalau
part-nya udah hilang.

**Belum diimplementasi (lihat juga roadmap):** instant-mine crystal
(nunggu sistem mining), TNT nggak bisa hancurkan rock (belum relevan,
belum ada sistem hancurin tile), trigger bangunin Skeleton yang lagi
`sleeping`/`returning` dari blast TNT (butuh refactor `SkeletonAI` biar
state-nya bisa diakses dari luar), ganti placeholder oranye jadi sprite
ledakan asli, dan nampilin sisa `TNTCount` ke GUI.

## File Script Terlampir

Semua isi lengkap script di atas ada di file-file `.lua` yang menyertai
dokumen ini (nama file sama persis dengan yang disebut di tabel struktur
file). Selalu pakai isi file itu sebagai sumber kebenaran, JANGAN
menebak-nebak isinya dari deskripsi di dokumen ini saja.
