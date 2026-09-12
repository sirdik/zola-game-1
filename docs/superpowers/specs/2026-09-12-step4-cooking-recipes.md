# Krok 4: Vaření a recepty

Roadmapa (CLAUDE.md), bod 4: "Vaření: `recipes.json`, jednoduchá kniha
receptů s ikonami, uvařené jídlo dá víc síly."

Tento dokument řeší implementační detaily. Herní koncept je v `CLAUDE.md`
— zde se neopakuje. Staví přímo na kroku 3 (`game/autoload/game.gd`,
`game/autoload/items.gd`, `game/ui/hud.gd`, `game/cooking/campfire.gd`),
včetně nedávné opravy, po které je otevírání/navigace/potvrzení
táborákového menu soustředěné v `hud.gd`'s `_process()` a sdílený
`Game.ui_blocking` blokuje pohyb hráče, dokud je menu otevřené.

## Rozsah

V tomto kroku:
- `data/recipes.json` se čtyřmi recepty z CLAUDE.md
- nový autoload `Recipes` (čistě data, jako `Items`)
- `Game.try_cook()` — atomická spotřeba surovin + obnovení energie
- táborákové menu se rozšíří o sekci "Recepty" pod stávající "Syrové"
- recepty na které hráč nemá dost surovin: šedé, potvrzení nic neudělá

Mimo rozsah (pozdější kroky): "kniha receptů" je zde totéž co táborákové
menu (žádná samostatná obrazovka) — viz rozhodnutí níže. Kostičky/plánky/
stavby (krok 5), zvířata (krok 6), coop (krok 7). Vizuální ikony receptů
zůstávají barevné čtverečky jako u surovin — obrázky až když je nakreslí
děti (krok 9).

## `data/recipes.json`

```json
{
  "recipes": [
    {
      "id": "mushroom_soup",
      "name": "Houbová polévka",
      "ingredients": { "mushroom": 3, "water": 1 },
      "energy_cooked": 40,
      "color": "#E8C874"
    },
    {
      "id": "forest_jam",
      "name": "Lesní marmeláda",
      "ingredients": { "raspberry": 3, "blackberry": 3 },
      "energy_cooked": 25,
      "color": "#8B2F5E"
    },
    {
      "id": "blueberry_pie",
      "name": "Borůvkový koláč",
      "ingredients": { "blueberry": 5, "hazelnut": 2 },
      "energy_cooked": 40,
      "color": "#5B4A8A"
    },
    {
      "id": "apple_juice",
      "name": "Jablečný džus",
      "ingredients": { "apple": 2, "water": 1 },
      "energy_cooked": 15,
      "color": "#F2A93B"
    }
  ]
}
```

Pořadí v poli = pořadí v menu (sekce "Recepty").

## `Recipes` autoload (`game/autoload/recipes.gd`)

`extends Node`, registruje se v `project.godot`'s `[autoload]` sekci
(po `Items` a `Game`, pořadí mezi sebou nezáleží — `Recipes` na nich
nezávisí). Stejný tvar jako `Items`:

- Při `_ready()` načte a naparsuje `data/recipes.json` (`JSON.parse_string`),
  stejná obranná logika jako `Items` (chybějící soubor/neplatné JSON →
  `push_warning`, prázdná databáze, nikdy pád hry; entry bez platného
  `id` se přeskočí s `push_warning`; entry bez `ingredients` (musí být
  `Dictionary`) se taky přeskočí s `push_warning`; chybějící `energy_cooked`
  → default `0` s `push_warning`; chybějící/neplatná `color` → default
  `"#ffffff"` s `push_warning` — stejný vzor jako oprava z kroku 3).
- `get_by_id(recipe_id: String) -> Dictionary`
- `all_ids() -> Array[String]` (pořadí ze souboru)

## `Game.try_cook()` (`game/autoload/game.gd`)

Nová metoda, vedle stávajících `get_count`/`add_item`/`try_consume`/
`drain`/`restore`:

```gdscript
func try_cook(ingredients: Dictionary, energy_cooked: float) -> bool:
	for item_id in ingredients:
		if get_count(item_id) < ingredients[item_id]:
			return false
	for item_id in ingredients:
		_inventory[item_id] -= ingredients[item_id]
		inventory_changed.emit(item_id)
	restore(energy_cooked)
	return true
```

Nejdřív ověří, že má hráč dost *všech* surovin (žádné částečné vaření),
pak je najednou odečte a zavolá stávající `restore()`.

## Táborákové menu (`game/ui/hud.gd`)

Rozšiřuje stávající `open_eat_menu()`/`_process()`/`_update_eat_menu_highlight()`
z kroku 3. Místo plochého seznamu `_eat_menu_ids: Array[String]` se zavede
`_eat_menu_entries: Array[Dictionary]` (`{kind: "raw"|"recipe", id: String,
craftable: bool}`) a paralelní `_eat_menu_rows: Array[Label]` (jen řádky,
které se dají vybrat — nadpisy sekcí do nich nepatří, takže procházení
šipkami nadpisy přeskakuje samo od sebe).

`open_eat_menu()`:
1. Smaže staré děti `EatMenu` (`remove_child` + `queue_free()`, jako teď).
2. Sekce "Syrové": pokud existuje aspoň jedna surovina s počtem > 0,
   přidá nadpis `Label` "Syrové", pak řádek na každou takovou surovinu
   (stejný text jako dřív: `"%s x%d" % [name, count]`), `kind="raw"`,
   `craftable=true` (surovina je v seznamu jen když jí hráč má dost —
   dost = aspoň 1).
3. Sekce "Recepty": pokud `Recipes.all_ids()` není prázdné, přidá nadpis
   "Recepty", pak řádek na *každý* recept (i nedostupný), `kind="recipe"`,
   `craftable` = má hráč dost všech `ingredients` (pomocná funkce
   `_can_cook(ingredients: Dictionary) -> bool` přes `Game.get_count`).
   Nedostupný recept: text normální, ale barva ztlumená (`Color(0.5,0.5,0.5)`
   místo `Color(1,1,1)`) — `_update_eat_menu_highlight()` z toho dělá
   základní barvu řádku (žluté zvýraznění vybraného řádku funguje beze
   změny přes obě barvy).
4. Když nejsou žádné vybratelné řádky (žádné suroviny a žádné recepty
   v databázi vůbec) — beze změny z kroku 3, hláška "Nemáš žádné jídlo!".
5. `eat_menu.visible = true`, `Game.ui_blocking = true` — beze změny.

`_process()`'s potvrzení (`p1_action` na vybraném řádku):
- `kind == "raw"`: beze změny z kroku 3 (`Game.try_consume` + `Game.restore(energy_raw)`,
  pak `close_eat_menu()`).
- `kind == "recipe"` a `craftable`: `Game.try_cook(ingredients, energy_cooked)`,
  pak `close_eat_menu()`.
- `kind == "recipe"` a ne `craftable`: nic se nestane, menu zůstane
  otevřené (žádná chybová hláška navíc — jednoduchost).

Navigace (`p1_move_forward`/`p1_move_back`) a wraparound beze změny
z kroku 3, jen počítá přes `_eat_menu_entries.size()` místo
`_eat_menu_ids.size()`.

## Ověření

- `godot --headless --path . --quit` po každé významnější změně —
  `Recipes` je teď třetí autoload, který při bootu skutečně běží
  `_ready()` proti reálnému souboru, takže headless test opět ověřuje
  i validitu dat, ne jen skripty.
- Ruční kontrola: nasbírej suroviny na uvaření aspoň jednoho receptu
  (např. 3 houby + voda), jdi k táboráku, v menu uvidíš sekci "Recepty"
  pod "Syrové" — recept na houbovou polévku bílý/vybratelný, ostatní
  recepty šedé. Potvrzení uvaří polévku (suroviny zmizí z HUDu, energie
  naskočí o 40), potvrzení šedého receptu nic neudělá.
