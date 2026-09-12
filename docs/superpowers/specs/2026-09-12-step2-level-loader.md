# Krok 2: Level loader (les z textového souboru)

Roadmapa (CLAUDE.md), bod 2: "Level loader: `levels/forest_01.txt` →
stromy, kameny, voda, táborák, start."

Tento dokument řeší jen implementační detaily tohoto kroku. Formát mapy
je popsaný v `levels/CLAUDE.md` — zde se neopakuje, jen se z něj vychází.
Zahrnuje i opravu kamery (viz níže), protože tento krok jako první
přidává do světa překážky, které kamera potřebuje řešit stejně jako
potřebuje přestat záviset na natočení hráče (známý odložený problém
z kroku 1).

## Rozsah

V tomto kroku:
- načtení `levels/forest_01.txt`, vykreslení `#` `.` `T` `~` `P` `F`
- posun startovní pozice hráče na `P` z mapy (místo pevné `Vector3(0,0.05,0)`)
- oprava kamery: pevný světový offset místo závislosti na natočení hráče,
  `SpringArm3D` pro kolize s překážkami

Mimo rozsah (pozdější kroky): jídlo (m/b/r/u/a/n), kostičky (k), plánky
(H1) a staveniště (S1), zvířata (x/w/d/B), klakson (!), `[legend]`
sekce pro budovy. Tyto znaky mapa obsahuje, ale loader je v tomto kroku
tiše přeskočí — jsou to známé znaky z legendy, ne neznámé.

## Formát vstupu — připomenutí klíčových pravidel

Z `levels/CLAUDE.md`: 1 znak = 1 dlaždice (2×2 m), řádky začínající `;`
jsou komentář, `[legend]` sekce a vše za ní se pro tento krok ignoruje.
Neznámý znak (mimo legendu úplně, ne jen "zatím neimplementovaný") →
varování v logu + fialový otazníkový blok, nikdy pád hry. Řádky mapy
nemusí mít stejnou délku (děti budou dělat překlepy) — chybějící znaky
na konci kratšího řádku se berou jako tráva (`.`).

## Souřadnicový systém

`TILE_SIZE = 2.0`. Dlaždice na řádku `row`, sloupci `col` (0-indexováno
od horního levého rohu textu) má world pozici
`Vector3(col * TILE_SIZE, 0, row * TILE_SIZE)`. Žádné centrování kolem
počátku — nejjednodušší a dost dobré pro jednu mapu.

## Soubory a datový tok

```
game/world/
├── forest.gd            # zjednodušeno: jen obloha/ambient (beze změny
│                         # oproti kroku 1, jen odebrán kód pro Ground)
├── level_loader.gd       # NOVÝ: parsuje mapu, staví dlaždice, přesune hráče
└── Forest.tscn           # upraveno: Ground pryč, přidán uzel "Level"
                          # (Node3D + level_loader.gd), CoopCamera
                          # restrukturalizována (viz níže)
```

### `game/world/level_loader.gd`

`extends Node3D`, přiřazeno uzlu `Level` (dítě `Forest`).

- `@export var level_path: String = "res://levels/forest_01.txt"`
- `@export var player_path: NodePath = NodePath("../Player1")` — přímá
  cesta, ne group lookup (group `"players"` se plní až v `Player._ready()`,
  jehož pořadí vůči `Level._ready()` není garantované — přímá cesta je
  spolehlivá).
- `_ready()`:
  1. Načte a rozparsuje soubor (viz Parsování níže).
  2. Postaví zemní desku (stejná trojice uzlů jako v kroku 1: `StaticBody3D`
     + `CollisionShape3D` (`BoxShape3D`) + `MeshInstance3D` (`BoxMesh`),
     obě velikosti `cols * TILE_SIZE` × 1 × `rows * TILE_SIZE`, horní
     plocha na `y=0` stejně jako dřív) — nahrazuje krok 1's pevných
     100×100, barva `Palette.PASTEL_GREEN`.
  3. Pro každou buňku mřížky spawne odpovídající primitivum (viz Mapování
     níže) jako dítě `Level`, na spočtené world pozici.
  4. Pokud byl v mapě nalezen `P`, nastaví `get_node(player_path).global_position`
     na jeho world pozici (+ malá výška, aby hráč nezapadl do země —
     stejná konvence jako krok 1, `y = 0.05`). Pokud `P` chybí, zůstane
     hráč na své pozici ze scény (žádný pád).

### Parsování

- Přeskoč prázdné řádky a řádky začínající `;`.
- Řádek `[legend]` ukončuje čtení mřížky — vše od něj dál (včetně) se
  ignoruje v tomto kroku.
- Do té doby je každý řádek jeden řádek mřížky; `row` = pořadí od nuly.
- Najdi nejdelší řádek mřížky, `cols` = jeho délka. Kratší řádky: chybějící
  znaky = `.` (tráva).
- `H1`/`S1` v mřížce jsou dva samostatné znaky vedle sebe (`H`, pak `1`),
  ne jeden dvouznakový token — čti mřížku přísně znak po znaku, jinak by
  se posunulo zarovnání zbytku řádku. Číslice za `H`/`S` proto musí být
  ve výsledné tabulce (níže) mezi tiše přeskočenými znaky, ne mezi
  neznámými — jinak by loader zbytečně hlásil varování pro dokumentovanou,
  jen zatím neimplementovanou věc.

### Mapování znak → vizuál

| Znak | Chování | Vizuál |
|---|---|---|
| `.` (tráva) | žádný spawn, jen podkladová zemní deska | — |
| `#` (kámen/zeď) | `StaticBody3D` + `CollisionShape3D` (`BoxShape3D`) + `MeshInstance3D` (`BoxMesh`), 2×2×2, na `y=1` (sedí na zemi) | šedá (`Color(0.6, 0.6, 0.62)`) |
| `T` (strom) | `StaticBody3D` + `CollisionShape3D` (`CylinderShape3D`, r=0.4, h=2.0, na `y=1`, pro kmen) + `MeshInstance3D` kmen (`CylinderMesh`, r=0.3, h=2.0, na `y=1`) + `MeshInstance3D` koruna (`CylinderMesh` s `top_radius=0` — tj. kužel, `bottom_radius=1.2`, h=2.5, na `y=3`) | kmen hnědá `Color(0.55, 0.4, 0.28)`, koruna `Palette.PASTEL_GREEN.darkened(0.3)` |
| `~` (voda) | `MeshInstance3D` (`BoxMesh`, plochý, 2×0.1×2, na `y=0.05`), **bez kolize** — chodí se přes ni | modrá, nová konstanta `Palette.WATER_BLUE = Color(0.42, 0.68, 0.82)` |
| `F` (táborák) | `MeshInstance3D` (`CylinderMesh`, malý, r=0.3, h=0.4, na `y=0.2`), **bez kolize** | oranžová `Color(0.85, 0.45, 0.2)` |
| `P` (start) | žádný vizuál, jen zapamatovaná pozice pro přesun hráče | — |
| cokoliv jiného mimo legendu | `push_warning()` s pozicí a znakem + `MeshInstance3D` (`BoxMesh`, 2×1×2, na `y=0.5`), **bez kolize** | fialová `Color(0.8, 0.2, 0.8)` otazníkový placeholder |
| `m` `b` `r` `u` `a` `n` `k` `x` `w` `d` `B` `!` `H` `S` a číslice `0`-`9` | tiše přeskočit (žádný spawn, žádné varování) | — |

`Palette.WATER_BLUE` se přidá do `game/theme/palette.gd` vedle
stávajících pěti konstant.

### Úprava `game/world/Forest.tscn`

- Odebrat uzel `Ground` (StaticBody3D/CollisionShape3D/MeshInstance3D) —
  nahrazuje ho dynamicky stavěná zem v `level_loader.gd`.
- Přidat uzel `Level` (`Node3D`, skript `level_loader.gd`) jako dítě
  `Forest`, **před** `CoopCamera` a `Player1` v pořadí uzlů (pořadí
  siblingů v `.tscn` odpovídá pořadí `_ready()` volání).
- `forest.gd` beze změny v logice — jen se z něj smaže kód, který mazal
  materiál `Ground` uzlu (ten uzel už neexistuje).

### Oprava kamery: `game/camera/coop_camera.gd` + `Forest.tscn`

Nahrazuje dosavadní `CoopCamera` (skriptovaný `Camera3D`, závislý na
natočení hráče — známý problém z kroku 1) tímto rigem:

```
[node name="CoopCamera" type="Node3D" parent="."]
script = coop_camera.gd

[node name="SpringArm3D" type="SpringArm3D" parent="CoopCamera"]
position = Vector3(0, 1.6, 0)
rotation_degrees = Vector3(-20, 0, 0)
spring_length = 4.0

[node name="Camera3D" type="Camera3D" parent="CoopCamera/SpringArm3D"]
current = true
```

`coop_camera.gd`:

```gdscript
class_name CoopCamera
extends Node3D

@export var follow_speed: float = 5.0

var _target: Node3D

func _ready() -> void:
	call_deferred("_find_target")

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_target = players[0] as Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
		return
	var target_pos: Vector3 = _target.global_transform.origin
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)
```

Rig se **nikdy neotáčí** — jen posouvá svou pozici k pozici hráče. Sklon
dolů (`-20°`) a vzdálenost (`spring_length`) jsou pevné na `SpringArm3D`.
`SpringArm3D` automaticky přitáhne `Camera3D` blíž, když mezi kamerou
a rigem je překážka (výchozí `collision_mask` zachytí `#`/`T` `StaticBody3D`,
protože jsou na výchozí vrstvě 1, stejně jako zem). `player.gd` se **nemění**
— jeho pohyb podle `camera.global_transform.basis` funguje beze změny,
jen teď je ta basis pořád stejná (kamera se neotáčí), takže šipky budou
mít pořád stejný směr vůči obrazovce bez ohledu na natočení postavy.

## Ověření

- `godot --headless --path . --quit` po každé významnější změně.
- Ruční kontrola v editoru: reload `Forest.tscn`, hráč se objeví u `P`
  na mapě (ne uprostřed), viditelné stromy/kameny/voda/táborák podle
  `levels/forest_01.txt`, kamera drží stálý směr při chůzi do stran
  (žádné "otáčení plošiny"), a při chůzi za strom/kámen se kamera
  přiblíží místo prokouknutí skrz.
