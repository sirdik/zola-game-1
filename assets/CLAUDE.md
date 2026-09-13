# Vlastní obsah od dětí (`assets/`)

Tři místa ve hře mají zatím jen automaticky generovaný obsah (ikony,
zvuky, zvířata) a čekají na to, až je nahradíte něčím, co vyrobí děti.
Stačí soubor s dohodnutým jménem uložit na správné místo — kód se
postará o zbytek, žádná úprava skriptů není potřeba (kromě ikon, tam se
přidá jeden řádek do datového souboru).

## Ikony (kresby dětí)

Ve hře se ikony surovin, receptů a předmětů zatím generují automaticky
(jednoduché tvary v `game/theme/icon_generator.gd`). Chcete-li místo
toho použít skutečnou dětskou kresbu:

1. Vyfoťte nebo naskenujte kresbu, ořízněte na čtverec, uložte jako PNG
   (klidně malé, cca 64×64 nebo 128×128 px stačí).
2. Uložte do `assets/icons/<jméno>.png` (např. `assets/icons/houba.png`).
3. V `data/items.json` (nebo `data/recipes.json`) přidejte k danému
   záznamu pole `"icon_image"` s cestou k souboru, např.:

   ```json
   { "id": "mushroom", ..., "icon_image": "res://assets/icons/houba.png" }
   ```

   Pole `"icon"` (tvar) klidně nechte — použije se jako záloha, kdyby
   `icon_image` chybělo nebo soubor nebyl nalezen.

## Zvuky (nahrávky dětí)

Klakson, "mňam" při jídle a medvědí brumlání se teď generují jako
jednoduchý syntetický zvuk (`game/audio/sound_generator.gd`). Chcete-li
místo toho použít skutečnou nahrávku:

1. Nahrajte zvuk (klidně mobilem), uložte jako `.ogg` nebo `.wav`.
2. Uložte pod přesným jménem podle toho, co nahráváte:
   - `assets/sounds/honk.ogg` — klakson
   - `assets/sounds/eat.ogg` — snězení jídla
   - `assets/sounds/growl.ogg` — medvěd
3. Hotovo — hra soubor najde sama a přehraje ho místo generovaného
   zvuku, žádná úprava kódu není potřeba. (Nový typ zvuku, který ještě
   neexistuje, potřebuje jeden řádek navíc v `sound_generator.gd`.)

## 3D modely zvířat (Blockbench)

Tohle už funguje beze změny kódu:

1. V Blockbench namodelujte zvíře, exportujte jako `.glb`.
2. Uložte do `assets/models/animals/<Jméno>.glb`.
3. V `data/animals.json` přidejte k danému zvířeti pole `"model_path"`
   (cesta k souboru) a volitelně `"model_scale"` (číslo — začněte na
   1.0 a upravte podle toho, jak velký/malý model ve hře vypadá).

## Po přidání souboru

Pokud má rodič otevřený Godot editor, po přidání nového souboru je
potřeba nechat ho naimportovat (Godot to udělá sám, jakmile si všimne
nového souboru ve složce projektu — stačí chvíli počkat nebo editor
přepnout do popředí).

## Poznámka k licenci cizích assetů

Pokud přidáváte hotový model/ikonu/zvuk odjinud (ne dětskou tvorbu),
zapište zdroj a licenci do `assets/CREDITS.md`, ať víme, odkud to je.
