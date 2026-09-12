# Krok 5: Kostičky a stavby

Roadmapa (CLAUDE.md), bod 5: "Kostičky a plánky: sběr, staveniště,
animace přilétání, domeček."

Tento dokument řeší implementační detaily. Herní koncept, formát mapy
(`levels/CLAUDE.md`) a formát stavby (`data/CLAUDE.md`) jsou popsané
jinde — zde se neopakují.

## Rozsah

V tomto kroku:
- kostičky (`k`) a plánek domečku (`H`) se sbírají jako needitelné
  položky přes existující obecný pickup mechanismus z kroku 3
- staveniště (`S`) — vždy viditelné, po sebrání plánku se aktivuje
- `data/house.txt` (už existuje) se načte a stavba se skládá po
  jednotlivých kostičkách s animací letu

Mimo rozsah (pozdější kroky): věž a hrad (krok 8), typy kostiček
(dřevo/kámen/střecha zvlášť), kolize na hotové stavbě, zvuk "žbluňk"
(žádný audio systém zatím neexistuje — zvuky jsou krok 9), uložení
rozestavěnosti mezi sezeními hry (krok 8 "jednoduché uložení").

**Poznámka k obsahu:** `data/house.txt` (dětský návrh) má 60 kostiček
napříč 4 vrstvami — víc, než roadmapa odhadovala ("~15"), ale je to
existující obsah dětí, neupravuje se. Aktuální `levels/forest_01.txt`
má na mapě jen 8 `k` a 1 `H` — domeček se z této jedné mapy nedostaví
celý, což je v pořádku (postupné stavění "klidně na několik návštěv" —
i napříč budoucím přidáváním kostiček do mapy dětmi).

## Rozšíření `data/items.json`

Dvě nové položky, needitelné (nové pole `edible`, výchozí `true` když
chybí — stávajících 7 potravinových záznamů se nemění):

```json
{ "id": "block", "name": "Kostička", "map_char": "k", "color": "#C9A876", "energy_raw": 0, "edible": false },
{ "id": "blueprint_house", "name": "Plánek domečku", "map_char": "H", "color": "#F5E6C8", "energy_raw": 0, "edible": false, "unlocks_building": "house" }
```

`unlocks_building` je nové, volitelné pole — když ho `Game.add_item()`
uvidí u sebrané položky, zavolá `unlock_building()` (viz níže). `k` a `H`
tím pádem projdou úplně beze změny přes existující obecný pickup
mechanismus z `level_loader.gd` (`Items.get_by_map_char` → `_spawn_pickup`)
— žádný nový kód pro sběr není potřeba, jen se odstraní z `SKIP_CHARS`.

## `game/ui/hud.gd`: filtr needitelných položek

V `open_eat_menu()`'s sestavování sekce "Syrové" přidat podmínku:
položka se do jídelního menu zařadí, jen když `Items.get_by_id(id).get("edible", true)`
je `true` — kostička a plánek se tedy v táborákovém menu k jídlu
neobjeví (i kdyby náhodou měly `energy_raw` > 0). Počítadlo v horním
HUDu (`_build_resource_bar()`) se nemění — kostičky i plánek tam mají
počítadlo automaticky, jak roadmapa chce ("počítadlo v HUDu").

## `game/autoload/game.gd`: odemykání staveb

```gdscript
var _unlocked_buildings: Dictionary = {}

func unlock_building(building_id: String) -> void:
	_unlocked_buildings[building_id] = true

func is_building_unlocked(building_id: String) -> bool:
	return _unlocked_buildings.get(building_id, false)
```

`add_item()` se rozšíří: po přičtení a vyslání `inventory_changed` zjistí
`Items.get_by_id(item_id)`, a pokud má klíč `unlocks_building`, zavolá
`unlock_building()` s tou hodnotou.

## `game/building/building_loader.gd`: parsování `data/house.txt`

Statický/utility skript (žádný autoload, žádný stav — jen parsovací
funkce), zrcadlí formát z `data/CLAUDE.md`: `;` komentáře se přeskočí,
`[layer N]` začíná novou vrstvu, následující řádky jsou její mřížka až
do dalšího `[layer` nebo konce souboru.

- `const BLOCK_SIZE := 0.5` — kostičky stavby jsou menší než lesní
  dlaždice (`TILE_SIZE = 2.0` v `level_loader.gd`), aby domeček
  vypadal jako domeček, ne jako čtvrť.
- Mapování písmeno→barva (napevno v kódu, snadno rozšiřitelné):
  `g` = `Color(0.45, 0.65, 0.45)` (zeď), `y` = `Color(0.9, 0.8, 0.3)`
  (dveře), `r` = `Color(0.75, 0.35, 0.3)` (střecha), `.` = nic.
- `parse(path: String) -> Array[Dictionary]` — vrátí seznam
  `{"position": Vector3, "color": Color}` v pořadí skládání: vrstvy
  vzestupně (0, 1, 2, ...), v rámci vrstvy řádky shora dolů, sloupce
  zleva doprava, `.` se přeskočí. `position` je relativní k počátku
  stavby: `Vector3(col * BLOCK_SIZE, layer * BLOCK_SIZE, row * BLOCK_SIZE)`.
- Neplatný soubor/prázdná stavba → `push_warning`, vrátí prázdné pole
  (nikdy pád hry, stejná konvence jako `level_loader.gd`).

## `game/building/build_site.gd`: staveniště

`Area3D`, `@export var building_id: String = "house"`,
`@export var data_path: String = "res://data/house.txt"`. Kolize
(`SphereShape3D`, radius 2.0 — stavba je větší než táborák) pro detekci
hráče v dosahu, stejný vzor jako `campfire.gd`.

- Při `_ready()`: zavolá `BuildingLoader.parse(data_path)` a uloží
  výsledek do `_blocks: Array[Dictionary]`. `_next_index: int = 0`
  (kolik kostiček je už postaveno), `_placing: bool = false` (běží
  právě animace).
- Vizuál: dokud `not Game.is_building_unlocked(building_id)`, staveniště
  je plochý šedý podstavec (needotčený, needotčeno akcí). Jakmile se
  odemkne (kontrola v `_process`, jednou při přechodu), podstavec
  změní barvu na výraznější (např. teplá béžová) — signalizuje "tady se
  dá stavět".
- Na `p1_action` (jen když `_player_in_range` a stavba odemčená a
  `not _placing`): spustí `_place_next_block()`.
- `_place_next_block()`: pokud `_next_index >= _blocks.size()`, konec
  (stavba hotová, nic se neděje). Jinak `Game.try_consume("block")` —
  pokud se nepovede (hráč nemá kostičky), konec beze změny. Pokud ano:
  vytvoří `MeshInstance3D` (kostka `BLOCK_SIZE`, barva z `_blocks[_next_index]`),
  animuje let obloučkem (`Tween.tween_method`, lineární interpolace
  pozice + `sin(t * PI)` výškový offset) ze startovní pozice (nad
  staveništěm) do cílové (`global_position + _blocks[_next_index]["position"]`),
  po dopadu krátké "žbluňk" zmáčknutí/protažení (`scale` tween), pak
  po krátké pauze zavolá sama sebe znovu — animace tak pokračuje,
  dokud nedojdou kostičky nebo není stavba hotová, bez blokování
  pohybu hráče (žádné `Game.ui_blocking` — hráč může kdykoliv odejít,
  rozestavěné kostičky zůstanou stát). Konstanty: `ARC_HEIGHT := 1.0`
  (výška obloučku v metrech), `FLY_DURATION := 0.4` (délka letu
  jedné kostičky v sekundách), `BLOCK_DELAY := 0.15` (pauza mezi
  kostičkami v sekundách).

## Úprava `game/world/level_loader.gd`

`SKIP_CHARS` ztrácí `k` a `H` (projdou obecným pickup mechanismem beze
změny kódu, jen díky nové položce v `items.json`). `S` dostane vlastní
`match` větev a novou funkci `_spawn_build_site(pos: Vector3)`, která
vytvoří `Area3D` (skript `BuildSiteScript`) + `CollisionShape3D`
(`SphereShape3D`, radius 2.0) + plochý `MeshInstance3D` podstavec
(`BoxMesh`, např. `Vector3(2.0, 0.1, 2.0)`, šedá barva) — stejný vzor
jako `_spawn_campfire`/`_spawn_water_source`.

## Ověření

- `godot --headless --path . --quit` po každé významnější změně.
- Ruční kontrola: sebrání kostičky/plánku (mizí, HUD počítadlo naskočí,
  needitelné v táborákovém menu), staveniště je zpočátku šedé a
  neinteraktivní, po sebrání plánku zesvětlá/zbarví se, akce u něj
  spustí lítání kostiček s obloučkem a "žbluňk" dopadem, zastaví se
  po vyčerpání zásoby. Vzhledem k tomu, že mapa má jen 8 kostiček,
  domeček se nepostaví celý — to je očekávané.
