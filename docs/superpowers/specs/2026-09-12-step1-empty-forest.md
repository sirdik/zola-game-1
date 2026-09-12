# Krok 1: Prázdný pastelový les + pohyb hráče

Roadmapa (CLAUDE.md), bod 1: "Prázdný pastelový les: terén, obloha, světlo;
hráč 1 chodí a skáče (šipky + mezerník), kamera za ním."

Tento dokument řeší jen implementační detaily tohoto kroku. Herní koncept,
vizuální styl a celková architektura jsou popsané v `CLAUDE.md` — zde se
neopakují.

## Rozsah

V tomto kroku:
- terén (plochá pastelová plocha), obloha, světlo
- hráč 1 chodí (šipky) a skáče (mezerník)
- kamera třetí osoby za hráčem s mírným nadhledem

Mimo rozsah (pozdější kroky): level loader z `levels/*.txt`, sběr surovin,
HUD, vaření, kostičky/stavby, zvířata, coop hráč 2. Kamera se v tomto kroku
staví jako samostatný skript, ale bez logiky pro víc hráčů (ta přijde
v kroku 7).

## Scény a skripty

```
game/
├── theme/
│   └── palette.gd          # barevné konstanty (pastel_green, sky_blue,
│                            # peach, lavender, cream)
├── player/
│   ├── player.gd           # CharacterBody3D logika
│   └── Player.tscn
├── camera/
│   └── coop_camera.gd      # zatím: sleduje jednoho hráče (group "players")
└── world/
    └── Forest.tscn         # hlavní scéna, nastavena jako run/main_scene
```

### `game/theme/palette.gd`

`class_name Palette extends RefCounted` (nebo prostý `static` skript) se
statickými `Color` konstantami:
- `PASTEL_GREEN = Color8(168, 224, 160)`
- `SKY_BLUE = Color8(168, 216, 240)`
- `PEACH = Color8(255, 214, 179)`
- `LAVENDER = Color8(216, 200, 232)`
- `CREAM = Color8(255, 248, 231)`

Přesné odstíny může rodič/děti později doladit — jde hlavně o to, že
materiály barvy čtou odtud, ne natvrdo.

### `game/world/Forest.tscn`

- `Node3D` (root, `Forest`)
  - `WorldEnvironment` — `Environment` se `ProceduralSkyMaterial`
    (`sky_top_color` / `sky_horizon_color` odvozené z `Palette.SKY_BLUE`),
    jemný ambient, bez mlhy zatím.
  - `DirectionalLight3D` ("Sun") — teplé měkké světlo, `shadow_enabled = true`,
    mírný úhel (~-45° na ose X), aby vrhalo čitelné stíny.
  - `StaticBody3D` ("Ground")
    - `CollisionShape3D` — `BoxShape3D`, velikost 100×1×100 m
    - `MeshInstance3D` — `BoxMesh` stejné velikosti, `StandardMaterial3D`
      s `albedo_color = Palette.PASTEL_GREEN`
  - `CoopCamera` (Node3D se skriptem `coop_camera.gd`)
    - `SpringArm3D` (délka 4 m, `collision_mask` na terén/budoucí překážky)
      - `Camera3D` (current = true)
  - `Player1` — instance `Player.tscn`, pozice `Vector3(0, 1, 0)`

`run/main_scene` v `project.godot` nastavit na `res://game/world/Forest.tscn`,
ať jde spustit rovnou F5 v editoru.

### InputMap (`project.godot`, sekce `[input]`)

- `p1_move_forward` — Up šipka
- `p1_move_back` — Down šipka
- `p1_move_left` — Left šipka
- `p1_move_right` — Right šipka
- `p1_jump` — Space

(`p1_action` a `p2_*` akce se přidají v pozdějších krocích, kdy budou
potřeba — YAGNI teď.)

### `game/player/player.gd`

`extends CharacterBody3D`, `class_name Player`.

- `@export var player_number: int = 1`
- `@export var move_speed: float = 4.0` (m/s)
- `@export var jump_velocity: float = 5.0` (m/s, odpovídá výšce skoku
  ~1.2 m při gravitaci projektu)
- `_ready()`: `add_to_group("players")`
- `_physics_process(delta)`:
  - přečte vstup z `p{player_number}_move_*` akcí (sestaví se jako string,
    aby skript fungoval beze změny i pro hráče 2 v kroku 7)
  - směr pohybu se otočí podle horizontálního natočení aktuální kamery
    (aby "nahoru" na klávesnici znamenalo "od kamery")
  - gravitace (`ProjectSettings` default) se přičítá, když `!is_on_floor()`
  - skok: pokud `is_on_floor()` a stisknuto `p{n}_jump`, nastaví
    `velocity.y = jump_velocity`
  - `move_and_slide()`
  - hráč se natáčí (`look_at` na horizontální rovině) směrem pohybu

### `game/camera/coop_camera.gd`

`extends Node3D`.

- V `_ready()` najde cíl: první uzel ve skupině `"players"`.
- V `_process(delta)` plynule (lerp) sleduje pozici cíle (kamera samotná se
  jen posouvá nad/za hráče; rotaci a odstup od případných překážek řeší
  `SpringArm3D`).
- Veřejné rozhraní (`follow(target: Node3D)` nebo podobně) navržené tak, aby
  šlo v kroku 7 nahradit "jeden cíl" za "průměr pozic všech hráčů" beze
  změny zbytku scény.

## Assety

- Zkusit stáhnout jeden CC0 model postavičky (Quaternius) s animacemi
  idle/walk, uložit do `assets/models/`, zapsat do `assets/CREDITS.md`
  (autor, licence, zdroj).
- Pokud stažení/import selže nebo licence nesedí: dočasně `CapsuleMesh`
  obarvená přes `Palette`, bez blokování zbytku kroku — vyřeší se jako
  samostatná položka později.
- Zem zůstává barevná plocha z `Palette` — Kenney Nature Kit dlaždice
  (tráva/kameny/stromy) patří až do kroku 2 (level loader), protože krok 1
  má být podle zadání "prázdný" les.

## Ověření

- `godot --headless --path . --quit` po každé významnější změně, aby se
  odchytily chyby v parsování scén/skriptů dřív, než padnou na hráče.
- Hratelnostní pocit (plynulost pohybu, výška skoku, chování kamery)
  ověří rodič ručně v otevřeném Godot editoru — headless run to nedokáže
  posoudit.
- Po úpravě `.tscn` souborů připomenout reload scény v otevřeném editoru.
