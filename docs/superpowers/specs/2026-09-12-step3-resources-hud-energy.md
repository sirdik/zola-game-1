# Krok 3: Sběr surovin, HUD, energie

Roadmapa (CLAUDE.md), bod 3: "Sběr surovin + HUD s počítadly; síla, která
ubývá; u táboráku sníst syrové jídlo."

Tento dokument řeší implementační detaily. Herní koncept a vizuální styl
jsou v `CLAUDE.md` — zde se neopakují.

## Rozsah

V tomto kroku:
- `data/items.json` s houba/ostružina/malina/borůvka/jablko/oříšek/voda
- sběr surovin dotykem (mizí z mapy), voda proximity sběrem z `~` dlaždic
- sdílený týmový inventář + energie jako autoload (`game/autoload/`)
- energie pomalu ubývá, skok stojí navíc
- HUD: řádek ikon+počtů + pruh energie
- táborák: menu výběru jídla, snězení obnoví energii podle `energy_raw`

Mimo rozsah (pozdější kroky): vaření/recepty (krok 4), kostičky/plánky/
stavby (krok 5), zvířata (krok 6), coop (krok 7), co se stane při energii
0 (krok 8 — teď energie prostě zůstane na nule, nic dalšího se nestane).

## `data/items.json`

```json
{
  "items": [
    { "id": "mushroom", "name": "Houba", "map_char": "m", "color": "#F5F0E1", "energy_raw": 8 },
    { "id": "blackberry", "name": "Ostružina", "map_char": "b", "color": "#3B1F4D", "energy_raw": 8 },
    { "id": "raspberry", "name": "Malina", "map_char": "r", "color": "#C81E4B", "energy_raw": 8 },
    { "id": "blueberry", "name": "Borůvka", "map_char": "u", "color": "#4A6FA5", "energy_raw": 8 },
    { "id": "apple", "name": "Jablko", "map_char": "a", "color": "#D63447", "energy_raw": 8 },
    { "id": "hazelnut", "name": "Oříšek", "map_char": "n", "color": "#8B5A2B", "energy_raw": 8 },
    { "id": "water", "name": "Voda", "map_char": "~", "color": "#6BADD1", "energy_raw": 3 }
  ]
}
```

Pořadí v poli = pořadí v HUDu a v táborákovém menu. `color` je hex string,
parsuje se přes `Color.html()`. `water`'s `map_char` je `~`, stejný znak,
který level loader už používá pro dlaždici vody — vodu tedy nespawnuje
jako mizící pickup, ale jako zdroj s proximity sběrem (viz níže).

## Autoloady (`game/autoload/`, registrované v `project.godot`)

Dva nové autoloady, v tomto pořadí (Game při `_ready()` čte `Items`, pořadí
v `[autoload]` sekci určuje pořadí inicializace):

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
```

### `Items` (`game/autoload/items.gd`)

`extends Node`. Při `_ready()` načte a naparsuje `data/items.json`
(`JSON.parse_string`), uloží do vnitřních `Dictionary` (podle `id` a podle
`map_char`) a `Array[String]` zachovávajícího pořadí ze souboru. Veřejné
metody: `get_by_id(item_id: String) -> Dictionary`,
`get_by_map_char(ch: String) -> Dictionary` (prázdný `Dictionary`, když
znak neodpovídá žádné položce), `all_ids() -> Array[String]`. Chyba
načtení/parsování → `push_warning()`, prázdné databáze (nikdy pád hry).

### `Game` (`game/autoload/game.gd`)

`extends Node`. Sdílený stav pro celý tým (i po zavedení coopu v kroku 7
zůstává jeden sdílený inventář/energie, ne per-hráč).

- `signal inventory_changed(item_id: String)`
- `signal energy_changed(value: float)`
- `const MAX_ENERGY := 100.0`
- `var energy: float = MAX_ENERGY`
- Interní `Dictionary` počtů, inicializovaná na 0 pro každé `Items.all_ids()`.
- `get_count(item_id: String) -> int`
- `add_item(item_id: String, amount: int = 1) -> void` — přičte, vyšle signál.
- `try_consume(item_id: String, amount: int = 1) -> bool` — vrátí `false`
  a nic nezmění, pokud není dost kusů; jinak odečte a vyšle signál.
- `drain(amount: float) -> void` / `restore(amount: float) -> void` —
  obě `clamp()`-ují `energy` do `[0, MAX_ENERGY]` a vyšlou `energy_changed`.

## Sběr surovin

### Pevné pickupy (houba, ostružina, malina, borůvka, jablko, oříšek)

`game/pickups/pickup.gd` + `game/pickups/Pickup.tscn` — jedna
znovupoužitelná scéna pro všechny typy (per CLAUDE.md: "food, block,
blueprint, horn: one reusable scene + data"). `Area3D` root,
`CollisionShape3D` (`SphereShape3D`, radius 0.4, `position = Vector3(0, 0.4, 0)`
— sedí na zemi), `MeshInstance3D` (`SphereMesh`, radius 0.25, stejná
pozice). `@export var item_id: String`. Level loader
při spawnu nastaví `material_override.albedo_color` z `Items.get_by_id(item_id)["color"]`
(přes `Color.html()`) — barva je tedy čistě z dat, ne natvrdo ve scéně
ani ve skriptu.

Chování (`pickup.gd`): na `body_entered`, pokud `body.is_in_group("players")`,
zavolá `Game.add_item(item_id)` a `queue_free()`.

### Voda (`game/pickups/water_source.gd`)

Samostatný skript (jiné chování než pickup — nezmizí, sbírá se opakovaně).
Přidá se jako `Area3D` + `CollisionShape3D` (`BoxShape3D`, size
`Vector3(2.0, 2.0, 2.0)`, `position = Vector3(0, 1.0, 0)` — stejný tvar
jako kolize kamene/stromu z kroku 2, dost vysoko, aby ho hráčova kapsle
spolehlivě protla) vedle existující vizuální `MeshInstance3D` vody
z kroku 2, na každé `~` dlaždici. Dokud je hráč uvnitř, každé 2 sekundy
`Game.add_item("water", 1)`.

```gdscript
extends Area3D

const COLLECT_INTERVAL := 2.0

var _timer: float = 0.0
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_timer = 0.0

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = false

func _process(delta: float) -> void:
	if not _player_inside:
		return
	_timer += delta
	if _timer >= COLLECT_INTERVAL:
		_timer -= COLLECT_INTERVAL
		Game.add_item("water", 1)
```

### Úprava `game/world/level_loader.gd`

`SKIP_CHARS` ztrácí `m b r u a n` (přesouvají se mezi implementované
znaky). V `match ch:` větvi: pro tyto znaky loader zjistí
`Items.get_by_map_char(ch)`; pokud není prázdné, instancuje `Pickup.tscn`,
nastaví `item_id` a barvu, umístí na `world_pos`. Pro `~` beze změny ve
vizuálu (stávající `_spawn_water`), navíc přidá `water_source.gd` na nový
`Area3D` na stejné pozici, jak je popsáno níže. `_spawn_campfire` (`F`)
se restrukturalizuje: nově vytvoří `Area3D` (skript `campfire.gd`) jako
rodiče, existující `MeshInstance3D` táboráku se stane jeho dítětem (stejný
vzor jako `StaticBody3D` u kamene/stromu v kroku 2) — viz sekce Táborák
níže pro přesný tvar kolize. `#`, `T`, `P`, `.` beze změny.

## Energie a pohyb (`game/player/player.gd`)

Nové konstanty na úrovni skriptu (vedle `@export var move_speed` apod.):
- `const IDLE_DRAIN := 0.5` (za sekundu, když se hráč nehýbe)
- `const MOVE_DRAIN := 1.0` (za sekundu, když se hráč hýbe)
- `const JUMP_DRAIN := 3.0` (jednorázově při skoku)

V současném `player.gd` se `move_direction.length() > 0.01` už jednou
testuje (řádek 30, kvůli natočení). Přidat energii do stejné podmínky,
beze změny logiky natočení:

```gdscript
if move_direction.length() > 0.01:
	Game.drain(MOVE_DRAIN * delta)
	var target_angle := atan2(-move_direction.x, -move_direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
else:
	Game.drain(IDLE_DRAIN * delta)
```

Skok: řádek 23-24 (`elif Input.is_action_just_pressed(_action("jump")): velocity.y = jump_velocity`)
doplnit o `Game.drain(JUMP_DRAIN)` na stejném řádku/bloku.

`Game.drain()` si sama ohlídá `clamp` na 0 — `player.gd` nemusí nic
kontrolovat.

## InputMap: `p1_action`

Nová akce v `project.godot`, klávesa Enter (`physical_keycode = 4194309`).
Používá ji táborák (viz níže); pozdější kroky (sebrání kostičky, pohlazení
zvířete, klakson) budou používat stejnou akci.

## Táborák (`game/cooking/campfire.gd`)

Přidá se `Area3D` + `CollisionShape3D` (`SphereShape3D`, radius 1.5,
`position = Vector3(0, 0.5, 0)` — kolem existující vizuální
`MeshInstance3D` táboráku z kroku 2, jehož váleček má výšku 0.4 na
`y=0.2`) na `Campfire` vizuál z kroku 2. Sleduje `body_entered`/`body_exited`
(skupina `"players"`) pro stav "hráč v dosahu". V `_process` — pokud je hráč
v dosahu a `Input.is_action_just_pressed("p1_action")`, zavolá na HUD
(najde ho přes skupinu `"hud"`) `hud.open_eat_menu()`. Pokud hráč opustí
dosah, zatímco je menu otevřené, zavolá `hud.close_eat_menu()`.

## HUD (`game/ui/hud.gd` + `game/ui/HUD.tscn`)

`CanvasLayer`, přidá se do skupiny `"hud"` v `_ready()`. Tři děti:

- **ResourceBar** (`HBoxContainer`) — pro každé `Items.all_ids()` jeden
  pár ikona (barevný `ColorRect`, barva z dat) + `Label` s počtem
  (`Game.get_count(id)`), aktualizuje se na `Game.inventory_changed`.
- **EnergyBar** — `ColorRect` s šířkou úměrnou `Game.energy / Game.MAX_ENERGY`,
  aktualizuje se na `Game.energy_changed`.
- **EatMenu** (`Control`, `visible = false` výchozí) — `VBoxContainer` s
  jedním řádkem na typ jídla, který hráč má aspoň 1× (jméno + počet);
  aktuálně vybraná položka zvýrazněná (např. jasnější barva pozadí).
  Pokud hráč nemá žádné jídlo, jeden řádek s textem "Nemáš žádné jídlo!".

`open_eat_menu()`: naplní seznam z `Game`, zviditelní `EatMenu`, nastaví
výběr na první položku. Dokud je menu otevřené, `_unhandled_input`
(nebo `_process` čtoucí `Input.is_action_just_pressed`) reaguje na
`p1_move_forward`/`p1_move_back` (posun výběru nahoru/dolů) a `p1_action`
(potvrzení: `Game.try_consume(id)` + `Game.restore(Items.get_by_id(id)["energy_raw"])`,
pak zavře menu). `close_eat_menu()`: skryje `EatMenu`.

Instance `HUD.tscn` se přidá do `game/world/Forest.tscn` jako dítě
`Forest` (sourozenec `Level`/`CoopCamera`/`Player1`) — `CanvasLayer` se
kreslí přes 3D scénu automaticky, pozice v souboru nezáleží.

## Ověření

- `godot --headless --path . --quit` po každé významnější změně.
- Ruční kontrola: sebrání surovin (dotykem zmizí, HUD počet naskočí),
  stání u vody (voda přibývá po ~2 s), energie pomalu klesá (rychleji při
  pohybu, skok ubere navíc), u táboráku akce otevře menu, výběr šipkami
  a potvrzení akcí sní jídlo a zvedne energii, opuštění táboráku menu
  zavře.
