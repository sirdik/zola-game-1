# Lesní dobrodružství (pracovní název)

Dětská 3D hra, kterou vyvíjí rodič (programátor) s Claude Code. Děti jsou
spoludesignéři: kreslí, vymýšlejí recepty, stavby a zvířata, navrhují mapy.
Cílová skupina: děti 6–10 let. Kód, identifikátory a komentáře piš anglicky,
texty ve hře česky (připrav je na překlad, ale neřeš ho teď).

## Hráči (a spoludesignéři)

- Ládík, 8 let – čte: ano
- Žofka, 5 let – čte: ještě ne

## Herní koncept (co je hra zač)

Chodíš po lese, sbíráš jídlo a vaříš podle receptů, aby ti nedošla síla.
V lese jsou rozházené kostičky a schované plánky staveb (domeček, hrad, věž).
Když najdeš plánek a nasbíráš kostičky, stavba se sama postaví: kostičky
přiletí nebo přiskáčou na své místo jedna po druhé. V lese žijí zvířata –
většina je hodná nebo neutrální, medvěd je nebezpečný a musíš najít klakson,
kterým ho odstrašíš. Hra je 3D plošinovka pro jednoho nebo více hráčů (coop).

### Herní smyčka

1. Prozkoumávej les → sbírej suroviny (houby, ostružiny, maliny, borůvky,
   oříšky, jablka… cokoli v lese), kostičky a plánky.
2. Síla (energy) pomalu ubývá; skákání a běh ubírají víc.
3. U táboráku vaříš podle receptů. Syrové jídlo dá málo síly, uvařené hodně.
4. Plánky odemykají staveniště. Dones kostičky, stavba roste.
5. Hotové stavby jsou odměna a cíl: postavit celou vesnici / hrad.

### Síla a „prohra“

Žádná smrt, žádný game over. Když síla klesne na nulu, postavička si unaveně
sedne, obrazovka zpomalí a hráč se probudí u nejbližšího táboráku s trochou
síly. Kamarád v coopu ho může probudit dřív tím, že mu dá jídlo.

### Suroviny a recepty (data, ne kód)

Suroviny a recepty jsou v `data/items.json` a `data/recipes.json`, aby je děti
mohly přidávat. Začni s těmito, děti doplní další:

- Suroviny: mushroom, blackberry, raspberry, blueberry, hazelnut, apple, water (u potoka)
- Recepty:
  - Houbová polévka = 3 mushroom + 1 water → velká síla
  - Lesní marmeláda = 3 raspberry + 3 blackberry → střední síla
  - Borůvkový koláč = 5 blueberry + 2 hazelnut → velká síla
  - Jablečný džus = 2 apple + 1 water → malá síla

Každý recept má název, ingredience, kolik síly dá a ikonku (děti mohou nakreslit).

### Kostičky a stavby

- Kostičky (blocks) leží rozházené po lese, sbírají se dotykem/přiblížením,
  počítadlo v HUDu. Barvy kostiček: pastelové, případně typy (dřevo, kámen, střecha).
- Plánek (blueprint) je předmět. Po sebrání se v lese objeví / zvýrazní staveniště.
- Stavba je definována v `data/buildings/*.json`: seznam kostiček s pozicí,
  velikostí a barvou, v pořadí, v jakém se mají skládat.
- U staveniště hráč stiskne akci → z jeho zásoby kostičky jedna po druhé
  odlétnou/odskáčou na své místo (Tween, malý obloučkový let, „plop“ zvuk,
  drobný „squash & stretch“ při dopadu). Stavba se skládá postupně, klidně
  na několik návštěv.
- Začni se třemi stavbami: domeček (~15 kostiček), věž (~25), hrad (~50).
  Nástroj pro děti: stavbu lze také „nakreslit“ jako vrstvy v textu (viz níže).

### Zvířata

- Neutrální / hodná (aspoň 3 druhy): liška, vlk, srnka (případně zajíc, ježek).
  Chodí po lese, zastaví se a podívají na hráče, dají se pohladit
  (akce → srdíčko). Vlk je neutrální: nechodí za hráčem, ale neubližuje.
- Agresivní (1 druh): medvěd. Když hráč přijde blízko, medvěd za ním jde
  a při doteku sebere kus síly a odstrčí ho (žádné zranění, žádná krev).
  Medvěd nikdy nesmí hráče zahnat do bezvýchodné situace – po chvíli
  pronásledování se vzdá.
- Klakson (air horn) je předmět schovaný v lese. S ním akce → hlasité
  „PRÁÁÁ“, medvěd se lekne, komicky se otočí a uteče (na chvíli). Klakson
  má cooldown, ne omezený počet použití.
- Chování zvířat řeš jednoduchým stavovým automatem (idle / wander / look /
  chase / flee), NavigationAgent3D nebo prosté sledování; ať je to čitelné.

### Ovládání a coop

- 3D plošinovka z pohledu třetí osoby, kamera za hráčem s mírným nadhledem.
- Hráč 1: šipky = pohyb, mezerník = skok, Enter (nebo E) = akce (sebrat,
  pohladit, vařit, stavět, klakson). Hráč 2: WASD + levý Shift/F, nebo gamepad.
  Používej Godot InputMap s akcemi `p1_move_*`, `p1_jump`, `p1_action`,
  `p2_…`; nikdy hardcoded klávesy.
- Coop je lokální na jednom počítači (couch coop), 1–4 hráči, jedna
  sdílená obrazovka: kamera sleduje střed mezi hráči a oddaluje se podle
  vzdálenosti; když se hráč vzdálí příliš, teleportuje se k ostatním
  (žádné dělení obrazovky – pro malé děti je sdílená obrazovka srozumitelnější).
- Zásoby jídla a kostiček jsou společné pro tým (méně hádek, více spolupráce).
- Síťový coop není v plánu pro první verzi. Piš ale herní logiku tak, aby
  hráč byl samostatná scéna `Player.tscn` s číslem hráče, ne singleton.

### Vizuální styl

- Kreslený low-poly, pastelové barvy, jasný a přátelský svět. Měkké stíny,
  mírně přesvětlený vzhled, zaoblené tvary. Žádné realistické textury.
- Použij CC0 balíčky: Kenney (Nature Kit, Food Kit), Quaternius (Animals,
  Ultimate Nature). Každý cizí asset zapiš do `assets/CREDITS.md`.
- Barevná paleta v `game/theme/palette.gd` (pastel green, sky blue, peach,
  lavender, cream) – kostičky, UI i materiály z ní berou barvy.
- UI: velké ikony, minimum textu, počítadla s obrázky (houba × 3),
  písmo velké a čitelné.

## Technologie

- Godot 4.x, standardní build (GDScript), statické typování.
- 3D modely glTF (`.glb`), vlastní modely z Blockbench (dětské výtvory).
- Volitelně později Dialogic 2 (Godot ≥ 4.3) pro mluvící zvířata.

## Architektura: obsah jsou data, ne kód

```
forest-game/
├── CLAUDE.md
├── project.godot
├── game/
│   ├── autoload/game.gd        # team inventory, energy rules, signals
│   ├── player/                 # Player.tscn (CharacterBody3D), player number, controls
│   ├── camera/coop_camera.gd   # shared camera following all players
│   ├── world/level_loader.gd   # builds forest from levels/*.txt
│   ├── pickups/                # food, block, blueprint, horn (one reusable scene + data)
│   ├── animals/                # animal.gd base + fox/wolf/deer/bear data
│   ├── building/               # build_site.gd, block flight animation
│   ├── cooking/                # campfire.gd, recipe UI
│   ├── theme/palette.gd
│   └── ui/                     # HUD (energy, counters), recipe book, pause
├── data/
│   ├── items.json
│   ├── recipes.json
│   ├── animals.json
│   └── buildings/house.json, tower.json, castle.json
├── levels/forest_01.txt
└── assets/models, textures, sounds/voices, CREDITS.md
```

Nová surovina, recept, zvíře nebo stavba = nový záznam v datech, ne nový kód.
Když nápad dětí potřebuje nový *druh* věci (např. loďka), přidej znovupoužitelnou
funkci do enginu a dál ji používej z dat.

## Formát mapy (`levels/*.txt`)

Jeden znak = jedna dlaždice (2 × 2 m). Řádky začínající `;` jsou komentář.

```
; # kámen/zeď  . tráva  T strom  ~ voda  P start hráčů  F táborák
; m houba  b ostružina  r malina  u borůvka  a jablko  n oříšek
; k kostička  H plánek (viz legend)  ! klakson
; x liška  w vlk  d srnka  B medvěd  S staveniště (viz legend)

[legend]
H1 = blueprint  building=house
S1 = build_site building=house
```

Neznámé znaky: přátelské varování v logu a otazníkový blok, nikdy pád hry.
Děti si budou vymýšlet písmena. Mapa může být velká (např. 40 × 40).

## Formát stavby (`data/buildings/*.json` nebo textové vrstvy)

Kromě JSON podporuj zápis po vrstvách, který děti nakreslí na čtverečkovaný
papír (jedna vrstva = jedno patro, písmeno = barva kostičky, `.` = nic):

```
[layer 0]
gggg
g..g
gggg
[layer 1]
rrrr
```

## Pravidla pro Claude Code

- Malé kroky, po každém kroku hratelná verze. Po každé funkční změně navrhni
  git commit.
- Ptej se před velkými refaktory nebo přidáním pluginů.
- Neupravuj `uid://`, `.import` soubory ani `.godot/`.
- Rodič může mít otevřený editor Godotu: po úpravě `.tscn` připomeň reload
  scény v editoru.
- Ověřuj chyby headless spuštěním (`godot --headless --path . --quit`),
  než prohlásíš, že něco funguje.
- Respektuj dětský obsah: v datech a mapách oprav jen to, co rozbíjí hru.
  Nech jejich názvy a nápady, i když jsou legrační.
- Po dokončení funkce napiš jednou větou, co s ní děti teď mohou dělat
  (např. „do mapy teď můžete napsat `u` a vyrostou tam borůvky“).

## Roadmapa

1. Prázdný pastelový les: terén, obloha, světlo; hráč 1 chodí a skáče (šipky + mezerník), kamera za ním.
2. Level loader: `levels/forest_01.txt` → stromy, kameny, voda, táborák, start.
3. Sběr surovin + HUD s počítadly; síla, která ubývá; u táboráku sníst syrové jídlo.
4. Vaření: `recipes.json`, jednoduchá kniha receptů s ikonami, uvařené jídlo dá víc síly.
5. Kostičky a plánky: sběr, staveniště, animace přilétání, domeček.
6. Zvířata: liška, vlk, srnka (wander + hlazení); medvěd (chase) + klakson.
7. Lokální coop: druhý hráč (WASD / gamepad), sdílená kamera, společná zásoba.
8. Věž a hrad, „usnutí“ při nulové síle a probuzení u táboráku, jednoduché uložení.
9. Dětský obsah: vlastní modely z Blockbench, ikony receptů z kreseb, nahrané zvuky
   (klakson, „mňam“, medvědí brumlání). Volitelně Dialogic pro mluvící zvířata.
