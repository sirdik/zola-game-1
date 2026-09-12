# Formát mapy (`levels/*.txt`)

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
