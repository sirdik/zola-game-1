# Krok 6: Zvířata

Roadmapa (CLAUDE.md), bod 6: "Zvířata: liška, vlk, srnka (wander +
hlazení); medvěd (chase) + klakson."

Tento dokument řeší implementační detaily. Herní koncept a formát mapy
(`levels/CLAUDE.md`) jsou popsané jinde — zde se neopakují.

## Rozsah

V tomto kroku:
- tři přátelská zvířata (liška `x`, vlk `w`, srnka `d`) — chodí po
  lese, zastaví se a podívají na hráče, dají se pohladit
- jedno agresivní zvíře (medvěd `B`) — honí hráče, na dotek ubere
  energii a odstrčí ho, po chvíli se vzdá
- klakson (`!`, na mapě už je připravený) — needitelná položka, nikdy
  se nespotřebuje, u medvěda ho vyplaší
- pohyb zvířat přes `NavigationAgent3D` a `NavigationRegion3D` napečenou
  za běhu nad vygenerovaným terénem (ověřeno funkčním spikem — viz
  poznámka níže o **asynchronním** pečení)
- nový datový soubor `data/animals.json` + autoload `Animals`, stejný
  vzor jako `Items`/`Recipes` — nové zvíře je nový záznam v datech, ne
  nový kód

Mimo rozsah (pozdější kroky): coop (druhý hráč, krok 7 — `animal.gd`
zatím hledá `"players"` skupinu a bere první nalezený uzel, což pro
sólo hraní stačí, ale bude potřeba přepracovat stejně jako `hud.gd`/
`campfire.gd`'s hardcoded `p1_*` už je zapsáno v paměti projektu),
zvuky (klakson "PRÁÁÁ", medvědí brumlání — krok 9, žádný audio systém
zatím neexistuje), větší/generované mapy (samostatný budoucí krok,
domluveno s uživatelem, nezávislý na tomto kroku).

**Poznámka k navigaci (ověřeno spikem před psaním tohoto specu):**
`NavigationRegion3D.bake_navigation_mesh(false)` (synchronní pečení)
se v tomto Godotu tváří úspěšně (vrátí správný počet polygonů), ale
výsledek se reálně nezaregistruje do `NavigationServer3D` — hledání
cesty pak vždy vrací prázdno. Funguje pouze **asynchronní** pečení
(`bake_navigation_mesh(true)`, výchozí) se signálem `bake_finished`.
Implementace musí použít asynchronní variantu — nikdy `false`.

**Poznámka k "nikdy nezažene do kouta":** bez plnohodnotné kontroly
úniku (mimo rozsah kvůli složitosti) toto řešíme kombinací časového
limitu honičky (`give_up_time`) a odstrčení směrem od medvěda při
zásahu (= pryč z případného kouta). Přijímáme jako zjednodušení pro
první verzi.

## `data/animals.json` + `game/autoload/animals.gd`

Formát a obranné parsování zrcadlí `items.gd` (chybný záznam se
přeskočí s `push_warning`, nikdy pád hry):

```json
{
  "animals": [
    { "id": "fox", "name": "Liška", "map_char": "x", "color": "#E07A3E", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "wolf", "name": "Vlk", "map_char": "w", "color": "#6E6E6E", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "deer", "name": "Srnka", "map_char": "d", "color": "#A9754F", "aggressive": false, "move_speed": 1.8, "wander_radius": 5.0, "notice_radius": 5.0, "pet_radius": 1.5 },
    { "id": "bear", "name": "Medvěd", "map_char": "B", "color": "#5C4028", "aggressive": true, "move_speed": 1.2, "wander_radius": 4.0, "chase_radius": 6.0, "chase_speed": 3.0, "catch_radius": 1.2, "give_up_time": 8.0, "energy_drain_on_hit": 15.0, "knockback_force": 6.0, "flee_speed": 4.0, "flee_duration": 4.0, "horn_radius": 6.0, "horn_cooldown": 3.0 }
  ]
}
```

`game/autoload/animals.gd` (nový autoload, registrovat v
`project.godot`): stejná struktura jako `items.gd` — `_by_id`,
`_by_map_char`, `get_by_id(id) -> Dictionary`,
`get_by_map_char(ch) -> Dictionary`. Validace při načtení: záznam bez
platného `id` (String) se přeskočí; chybějící `color` defaultuje na
bílou; chybějící `aggressive` defaultuje na `false`; číselná pole
(`move_speed`, `wander_radius`, `notice_radius`, `pet_radius`,
`chase_radius`, `chase_speed`, `catch_radius`, `give_up_time`,
`energy_drain_on_hit`, `knockback_force`, `flee_speed`,
`flee_duration`, `horn_radius`, `horn_cooldown`) čtena přes
`.get(key, default)` s rozumnými výchozími hodnotami (viz konstanty v
`animal.gd` níže) — chybějící pole tedy nikdy nezpůsobí chybu, jen
použije výchozí chování.

Časování efektů, které nejsou "obsahem zvířete" (délka poskoku srdíčka,
`hit_cooldown` mezi zásahy medvěda) zůstává jako konstanty přímo v
`animal.gd`, stejně jako `ARC_HEIGHT`/`FLY_DURATION` v `build_site.gd`
nejsou v datech — jen věci, které by dítě smysluplně chtělo měnit
per-zvíře (rychlost, dosahy, barva, jestli je nebezpečné), jsou v JSON.

## `data/items.json`: klakson

Jedna nová needitelná položka, nikdy se nespotřebovává (žádné pole
`unlocks_building` ani jiný "consume" mechanismus — zůstává v zásobě
napořád, jakmile ji hráč jednou sebere):

```json
{ "id": "horn", "name": "Klakson", "map_char": "!", "color": "#E8C93A", "energy_raw": 0, "edible": false }
```

`!` je na mapě (`levels/forest_01.txt`) i v legendě komentáře už
připravené od kroku 2 — projde beze změny přes existující obecný
pickup mechanismus, jen se odstraní z `SKIP_CHARS`.

## `game/animals/animal.gd`: sdílený stavový automat

Jeden skript (`CharacterBody3D`) pro všechny druhy — chování určuje
`aggressive` a data z `Animals`, ne kód specifický pro druh.

```gdscript
enum State { IDLE, WANDER, LOOK, CHASE, FLEE }
```

Veřejné proměnné nastavené přímo z `level_loader.gd` po `set_script()`
(stejný vzor jako `pickup.gd`'s `item_id`): `animal_id: String`,
`aggressive: bool`, `move_speed`, `wander_radius`, `notice_radius`,
`pet_radius`, `chase_radius`, `chase_speed`, `catch_radius`,
`give_up_time`, `energy_drain_on_hit`, `knockback_force`,
`flee_speed`, `flee_duration`, `horn_radius`, `horn_cooldown`.

`@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D` —
child musí existovat před `add_child(animal)` na `Level` (stejná
zákonitost jako `build_site.gd`'s `$Marker`, viz `level_loader.gd`
sekce níže).

- **`_ready()`**: zapamatuje si `_spawn_position := global_position`
  (střed pro wander), najde hráče přes
  `get_tree().get_first_node_in_group("players")` (sólo hra — coop
  poznámka v Rozsahu výše), přejde do `IDLE`.
- **`IDLE`**: časovač 1–3 s (náhodně), pak → `WANDER` (vybere náhodný
  bod v `wander_radius` od `_spawn_position`, nastaví
  `nav_agent.target_position`).
- **`WANDER`**: každý `_physics_process` čte
  `nav_agent.get_next_path_position()`, počítá směr a rychlost jako
  `player.gd` (`velocity` + `move_and_slide()`, natáčení k cíli).
  Když `nav_agent.is_navigation_finished()` → `IDLE`. **Přátelské
  zvíře** navíc každý snímek kontroluje vzdálenost k hráči — pod
  `notice_radius` okamžitě přeruší (i uprostřed cesty) → `LOOK`.
  **Agresivní zvíře** (medvěd) místo toho kontroluje `chase_radius` →
  `CHASE`. `IDLE` stejně kontroluje totéž (přerušení klidu, ne jen
  chůze).
- **`LOOK`** (jen přátelská zvířata): natočí se k hráči, stojí.
  Když hráč vyjde z `notice_radius` → `IDLE`. Když je hráč navíc v
  `pet_radius` a stiskne `p1_action` (Enter): spustí efekt pohlazení
  (viz níže), zůstává v `LOOK`.
- **Efekt pohlazení**: krátký Tween poskoku zvířete (`scale` nahoru/
  dolů, jako `build_site.gd`'s "žbluňk") + malá růžová kulička
  (`SphereMesh`, `Color(0.95, 0.4, 0.55)`) o kousek nad zvířetem, která
  vyplave nahoru a zmizí (`Tween` pozice + `modulate.a` na 0), pak
  `queue_free()`. Žádný herní efekt (energie apod.) — čistě pro radost.
- **`CHASE`** (jen medvěd): `nav_agent.target_position = player.global_position`
  každý snímek, pohyb rychlostí `chase_speed`. Časovač `_chase_timer`
  roste; při `_chase_timer >= give_up_time` NEBO vzdálenost od hráče
  > `chase_radius * 1.5` → `IDLE` (vzdal se). Když vzdálenost k hráči
  < `catch_radius` a `_hit_cooldown <= 0`: `Game.drain(energy_drain_on_hit)`,
  `player.apply_knockback(player.global_position - global_position, knockback_force)`
  (viz úprava `player.gd` níže), nastaví `_hit_cooldown = HIT_COOLDOWN`
  (konstanta v kódu, např. `1.5`).
- **`FLEE`** (jen medvěd, spouští klakson zvenčí přes veřejnou funkci
  `scare(from_position: Vector3) -> bool`, kterou zavolá cokoliv, co
  klakson použije — viz níže): pokud `_horn_cooldown > 0`, vrátí
  `false` (nic se nestane). Jinak nastaví `_horn_cooldown = horn_cooldown`,
  `_flee_timer = flee_duration`, cíl navigace daleko po směru pryč od
  `from_position`, rychlost `flee_speed`. Po vypršení `_flee_timer` →
  `IDLE`. Dokud `FLEE` běží, `CHASE`/zásahy se nekontrolují.

**Použití klaksonu** (kdokoliv v dosahu, nový handler přímo v
`animal.gd`, kontrolovaný jen když `aggressive`): v `_physics_process`,
když `aggressive` a stav není `FLEE` a hráč je v `horn_radius` a
`Game.get_count("horn") > 0` a `Input.is_action_just_pressed("p1_action")`:
zavolá `scare(player.global_position)`. Klakson se nikdy nespotřebuje
(žádné `Game.try_consume` volání) — jen se kontroluje, že ho hráč má.

## Úprava `game/player/player.gd`: odstrčení

Nová veřejná funkce a stav pro krátké, enginem řízené odstrčení, které
přebije normální pohyb z inputu (jinak by ho `_physics_process`
okamžitě přepsal každý snímek):

```gdscript
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0

func apply_knockback(direction: Vector3, force: float, duration: float = 0.3) -> void:
	_knockback_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * force
	_knockback_timer = duration
```

V `_physics_process`: pokud `_knockback_timer > 0.0`, odečíst `delta`,
použít `_knockback_velocity.x`/`.z` místo pohybu z inputu (žádné
ubírání energie, žádné natáčení po dobu odstrčení); jinak beze změny
oproti současnému kódu. Gravitace a skákání (`velocity.y`) se
odstrčením neřeší, běží dál normálně.

## Úprava `game/world/level_loader.gd`: navigace + spawn zvířat

`SKIP_CHARS` ztrácí `x`, `w`, `d`, `B`, `!`.

**Navigace** — `_build_ground`, `_spawn_rock`, `_spawn_tree` každé
svoje `StaticBody3D` přidají do skupiny `"nav_source"`
(`body.add_to_group("nav_source")`). **Zvířata do této skupiny nesmí
patřit** — pohybují se, navmesh je statický. Na konci `_ready()` (po
hlavní `for row/col` smyčce, spolu s umístěním hráče):

```gdscript
var nav_region := NavigationRegion3D.new()
add_child(nav_region)
var nav_mesh := NavigationMesh.new()
nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
nav_mesh.geometry_source_group_name = "nav_source"
nav_mesh.agent_radius = 0.4
nav_mesh.agent_height = 1.2
nav_mesh.cell_size = 0.25
nav_mesh.cell_height = 0.25
nav_region.navigation_mesh = nav_mesh
nav_region.bake_navigation_mesh(true)  # ASYNC — viz poznámka nahoře, false nefunguje
```

Zvířata spawnutá ve stejné `_ready()` běžně začnou v `IDLE` a čekají
na první `WANDER` rozhodnutí o pár sekund později (viz časovač výše) —
do té doby síť doběhne napečená (typicky pár desítek milisekund
navíc), takže není potřeba žádná explicitní synchronizace mezi
`animal.gd` a dokončením pečení.

Nová konstanta vedle ostatních preloadů:
`const AnimalScript := preload("res://game/animals/animal.gd")`.

**Spawn zvířat** — nová funkce `_spawn_animal(pos, animal_data)`
(vzor jako `_spawn_pickup`): `CharacterBody3D` + skript `AnimalScript`
+ `CapsuleShape3D`/`CapsuleMesh` (barva z `animal_data["color"]`,
stejně jako `_spawn_pickup` bere barvu z `item_data["color"]`) +
`NavigationAgent3D` dítě (musí existovat před `add_child` na `Level`,
stejná zákonitost jako `build_site.gd`'s `$Marker`). Po vytvoření se
nastaví veřejné proměnné ze `animal_data`: `animal.animal_id = animal_data["id"]`,
`animal.aggressive = animal_data.get("aggressive", false)`, a stejně
`.get(key, default)` pro každé zbývající číselné pole (výchozí hodnoty
podle konstant uvedených výše u `animal.gd` — žádné pole tedy není
povinné kromě `id`).

Zapojení do `match` větve v `_ready()`'s fallback (`_:` větev, vedle
existující kontroly `Items.get_by_map_char`):

```gdscript
_:
	var item_data := Items.get_by_map_char(ch)
	if not item_data.is_empty():
		_spawn_pickup(world_pos, item_data)
	else:
		var animal_data := Animals.get_by_map_char(ch)
		if not animal_data.is_empty():
			_spawn_animal(world_pos, animal_data)
		elif not SKIP_CHARS.contains(ch):
			_spawn_unknown(world_pos, ch, row, col)
```

## Ověření

- `godot --headless --path . --quit` po každé významnější změně —
  včetně prvního skutečného spuštění `bake_navigation_mesh(true)` v
  reálném běhu hry (ne jen ve spiku).
- Ruční hraní: liška/vlk/srnka chodí po lese, po přiblížení se
  zastaví a otočí k hráči, akce (Enter) nablízko vyvolá srdíčko.
  Medvěd mimo dosah chodí stejně, po přiblížení běží za hráčem,
  dotyk ubere energii a odstrčí hráče (a nedělá to víc než jednou za
  ~1,5 s). Po chvíli honičky se medvěd vzdá. Sebrání klaksonu (nikdy
  nezmizí z HUDu) a jeho použití (Enter) blízko medvěda ho vyplaší na
  pár sekund; nejde spustit hned znovu na stejného medvěda (cooldown).
