# Procedurally generated forest maps — Design

## Context

The kids playtested the game and said the current map
(`levels/forest_01.txt`, a hand-authored 24×16 grid = 48m × 32m) feels
small. `levels/CLAUDE.md` already documents that maps can be arbitrarily
large ("Mapa může být velká, např. 40 × 40") and `level_loader.gd` already
handles any grid size with zero code changes — so a bigger *static* map
was never actually blocked. Discussing it with the user surfaced the real
want: **replayability** — a fresh forest layout each time a new game
starts, not just a bigger fixed one.

This was first raised (without detail) as a deferred sub-project back at
roadmap step 6/7. This spec is the first concrete design for it.

## Scope

**In scope:**
- A new map generator that produces a random ~60×60 tile forest.
- Integration with the existing save system so a generated map is created
  once per save (not re-rolled on every launch) and persists across
  sessions, matching how build progress already persists across visits.
- "Nová hra" (the existing reset button) triggers a fresh map on next load.
- Guaranteed playability: all three buildings (house/tower/castle) and
  their blueprints always exist, are always reachable, per the user's
  explicit choice.

**Out of scope:**
- Changing `level_loader.gd`'s parsing/spawning logic in any way beyond a
  small path-resolution addition at the very top of its `_ready()`. The
  code that turns map characters into trees/rocks/animals/buildings/etc.
  (9 roadmap steps' worth of validated, reviewed code) is not touched.
- The original hand-authored `levels/forest_01.txt` is not deleted — it
  remains the fallback if no generated map exists yet (and stays useful as
  a hand-tunable reference/dev map).
- Seed-based regeneration (storing just an RNG seed and re-running the
  generator to reproduce the same map) is deliberately rejected — see
  "Save integration" below for why.
- Per-map-size configurability, a UI to pick map size, or multiple map
  "biomes" — none of that was asked for; a single reasonable default size
  is enough for now.
- Move-speed/traversal-time tuning for the bigger map — flagged as a
  possible follow-up after playtest, not designed now (YAGNI).

## Generation algorithm

A new `game/world/map_generator.gd` (a `RefCounted`, not a node — pure
generation logic, callable statically) builds a `MAP_SIZE × MAP_SIZE`
(60×60) grid of characters plus a legend dictionary, then serializes both
into the exact text format `levels/CLAUDE.md` documents (one char per
tile, `;` comments, a `[legend]` section) — the same format
`level_loader.gd` already parses.

All distances in this section are Chebyshev tile distance
(`max(|dx|, |dy|)`) — simple and cheap, and grid-appropriate since
movement isn't restricted to 4 directions in this 3D game anyway.

Placement happens in this order, each step marking the tiles it uses as
occupied so later steps never overwrite them:

1. **Grid init:** every tile starts as grass (`.`).
2. **Player spawn (`P`):** a random tile within the middle third of the
   grid in both axes (avoids spawning right at an edge).
3. **Campfire (`F`):** a random tile between 8 and 20 tiles from spawn —
   close enough to be found early, far enough to require a little
   exploration.
4. **Buildings:** for each of house, tower, castle (in that order) —
   place a build-site tile (`S`, with a legend token like `S1`) at a
   random position at least 12 tiles from spawn, the campfire, and every
   previously-placed building; then place that building's blueprint tile
   (`H`, matching legend token like `H1`) between 5 and 15 tiles from its
   own build site. Each of these two placements tries up to 50 random
   candidates looking for one that satisfies its constraints; if none of
   the 50 work, this generation attempt is abandoned and step 10's
   whole-generation retry kicks in immediately (no partial map is ever
   handed to the connectivity check).
5. **Water:** one rectangular pond, random size between 4×4 and 8×10
   tiles, placed at a random position that doesn't overlap anything
   already placed. Tiles inside it become `~` (each `~` tile behaves
   exactly as today — both visual water and a drinkable water source, per
   `level_loader.gd`'s existing `_spawn_water`/`_spawn_water_source`
   pairing).
6. **Trees and rocks:** scattered across all still-empty, non-water tiles
   at a combined density of **15%** (roughly 60% trees / 40% rocks) —
   each candidate tile becomes `T` or `#` if still empty.
7. **Food resources:** scattered across remaining empty tiles at a
   density of **4%**, evenly distributed across the six existing food map
   chars (`m` `b` `r` `u` `a` `n`).
8. **Kostičky (`k`):** exactly **45** placed on remaining empty tiles
   (not a density — a fixed count, matching today's design intent of
   "enough to make good progress, not enough to finish everything in one
   map"; 45 comfortably covers the house (15) + tower (21) with margin,
   same spirit as today's 30-out-of-74 balance, just proportional to a
   bigger, more generous map).
9. **Animals:** 2 fox, 2 wolf, 2 deer, 1 bear (matching `data/animals.json`
   species, still pure data — the generator reads `Animals.all_ids()`
   rather than hardcoding species names, so a future new animal in the
   data file automatically gets a placement count once added here), each
   at a random empty tile at least 10 tiles from spawn.
10. **Connectivity check and whole-generation retry:** flood-fill (BFS)
    from the spawn tile over every non-blocking tile (`.`, food chars,
    `k`, `H`, `S`, `F`, animal chars — i.e. everything except `T`/`#`/`~`).
    If the campfire and all three buildings' site+blueprint tiles aren't
    all reachable from spawn — or if step 4 already gave up early per
    above — the entire generation restarts from step 1 with a fresh
    random layout. Up to 20 such full retries; if every one somehow fails
    (not expected at these densities on a 60×60 grid), retry again with
    tree/rock density halved each time until one succeeds — zero density
    trivially always connects everything, so this is guaranteed to
    terminate eventually.

These density/count/distance numbers are reasonable starting values, not
promises — expect a round of visual/gameplay tuning after the first
playtest, the same way the low-poly visual style's scale table was.

## Text format emission

The generator writes exactly what `levels/CLAUDE.md` documents: rows of
characters, then a blank line, then `[legend]`, then one `TOKEN = kind
building=id` line per building (matching `level_loader.gd`'s
`_read_legend`/`_lookup_building_id` parsing exactly — e.g. `H1 =
blueprint  building=house`, `S1 = build_site building=house`, `H2`/`S2`
for tower, `H3`/`S3` for castle). No other change to the format — a
generated map is indistinguishable, from the parser's point of view, from
a hand-authored one.

## Save integration

**Why persist the generated text, not just a seed:** if the generator's
algorithm ever changes in a future update (new density tuning, a new
decoration type, reordered RNG calls), the same seed would silently
produce a *different* map than the one the player already explored and
partly built on — effectively corrupting their world layout retroactively.
A full 60×60 map's text is only a few KB, so there's no real storage
cost to persisting the actual result instead. This mirrors how the rest of
the save system already works (persist the actual state, not a recipe for
reproducing it).

**Mechanics:**
- The generated map is written to `user://generated_forest.txt`.
- A new autoload check — folded into the existing `Game` autoload's
  `_ready()`, since it already owns save-lifecycle concerns — creates this
  file via `MapGenerator` if it doesn't exist yet. Autoloads initialize
  before the main scene (already established and relied on elsewhere in
  this project), so the file is guaranteed to exist before `Forest.tscn`'s
  `level_loader.gd` node runs its own `_ready()`.
- `level_loader.gd` gains exactly one small addition at the very top of
  its `_ready()`: if `user://generated_forest.txt` exists, use it as the
  effective `level_path` instead of the `@export`ed default; otherwise
  keep using `res://levels/forest_01.txt` exactly as today. Every line
  after that point in `_ready()` — the parsing, the spawning, all of
  it — is completely unchanged.
- `Game.reset_save()` (the existing "Nová hra" handler) gains one more
  line: delete `user://generated_forest.txt` alongside the existing save
  file deletion, so the next load generates a brand new map. This mirrors
  the existing `DirAccess.remove_absolute(SAVE_PATH)` pattern already in
  that function.

## Testing

- Headless boot (`--headless --path . --quit`) confirms the generator
  runs without error and produces a file `level_loader.gd` can parse
  cleanly (no `SCRIPT ERROR`/`Parse Error`), on a fresh project state with
  no existing `user://generated_forest.txt`.
- A second headless boot immediately after confirms the SAME map is
  reused (file already exists, not regenerated) — verifiable by checking
  the file's contents/timestamp are unchanged between the two runs.
- A throwaway probe (deleted after use, per this project's established
  practice) that calls the generator directly many times in a loop and
  asserts the connectivity check always eventually passes, to build
  confidence in the retry logic before trusting it during manual play.
- Manual playtest by the user: does the map actually feel bigger and
  varied, are the buildings reasonably spread out and findable, does
  traversal time feel OK at the current move speed, do animal encounters
  feel fairly placed — none of this is verifiable headlessly.

## Deferred / explicit non-goals

- Move-speed tuning for the larger map.
- Configurable map size or a "regenerate now" button (only "Nová hra"
  triggers regeneration, per the user's explicit choice).
- Biome variety, multiple water features, roads/paths, or any
  non-uniform terrain shaping.
- Loosening the "always all three buildings" guarantee.
