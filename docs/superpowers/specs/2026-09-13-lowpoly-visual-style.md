# Low-poly visual style (environment + fox/wolf/deer) — Design

## Context

The user wants the game's 3D look to match a low-poly, flat-shaded/faceted
aesthetic shown in two references: a Pixabay illustration (a low-poly fox in
a pine forest) and a paid Fab.com "Low Poly Forest Environment" pack. Today
every visual in the game is built from Godot's smooth-shaded primitive
meshes (`SphereMesh`/`CapsuleMesh`/`BoxMesh`/`CylinderMesh`), which cannot
produce a true faceted look.

CLAUDE.md already names Kenney (Nature Kit, Food Kit) and Quaternius
(Animals, Ultimate Nature) as the project's intended CC0 asset sources. The
user approved using those free packs over procedural mesh generation or the
paid Fab.com pack (see brainstorming decision).

Both packs were downloaded and inspected during design:

- **Kenney Nature Kit** (CC0 1.0): self-contained `.glb` files, no external
  textures, flat solid-color materials per mesh. Confirmed via inspection of
  the zip's `Models/GLTF format/` folder.
- **Quaternius Ultimate Animated Animal Pack** (CC0 1.0): self-contained
  single-file `.gltf` per animal (base64-embedded mesh + skeleton, no
  external textures), flat solid-color materials, rigged with 12 baked
  animation clips each (`Idle`, `Walk`, `Gallop`, `Eating`, `Death`,
  `Attack`, `Idle_HitReact1/2`, etc.). The pack includes Fox, Wolf, Deer
  (`Stag`/`Deer`) among others, but **no bear**.

## Scope

**In scope:**
- Environment props (trees, rocks) in `game/world/level_loader.gd` get real
  Kenney `.glb` visuals instead of procedural primitive meshes.
- Fox, wolf, and deer get real Quaternius `.gltf` animated visuals instead
  of procedural capsule + feature-mesh bodies, via the `model_path` field
  already read (but currently unused) by `_spawn_animal()`.
- `animal.gd` gains simple state-driven animation playback for animals that
  have a loaded model.
- `assets/CREDITS.md` is created, listing both packs per CLAUDE.md's
  asset-crediting rule.

**Explicitly out of scope:**
- The bear stays procedural (capsule body + round ears, current
  `_add_animal_features` path) — no suitable free CC0 bear model was found.
  Revisit later if one turns up; nothing about this design blocks that.
- Player capsule and building blocks are untouched — they are deliberately
  plain/functional, not scenery.
- Water and campfire visuals are untouched.
- No gameplay-logic change: movement, collision, energy drain, the
  idle/wander/look/chase/flee state machine, and the pet/horn mechanics are
  unchanged. This is a visual swap plus animation *playback* hooked to
  existing states, not a behavior change.
- Kenney's `_dark` / `_fall` seasonal tree/rock color variants, and Kenney
  nature props not currently spawned by the level loader (mushrooms,
  flowers, logs, bushes) are not used in this slice.

## Asset acquisition and storage

Assets are placed directly in the repo (not fetched at runtime):

- `assets/models/nature/` — 4 tree variants + 4 rock variants, copied from
  the Kenney Nature Kit's `Models/GLTF format/` folder:
  - `tree_pineRoundA.glb`, `tree_pineRoundC.glb`
  - `tree_pineTallA.glb`, `tree_pineTallC.glb`
  - `rock_smallA.glb`, `rock_smallD.glb`
  - `rock_largeA.glb`, `rock_largeD.glb`
- `assets/models/animals/` — copied from the Quaternius pack's `glTF/`
  folder:
  - `Fox.gltf`, `Wolf.gltf`, `Deer.gltf`
- `assets/CREDITS.md` — new file. One entry per pack: name, author
  ("Kenney" / "Quaternius"), license ("CC0 1.0 — Public Domain"), and
  source URL (the `kenney.nl` and `quaternius.com` pages used during
  research).

All 10 model files are self-contained (no separate texture/`.bin`
sidecars), so no extra asset-pipeline work is needed beyond Godot's normal
`.glb`/`.gltf` import.

## Environment integration

`game/world/level_loader.gd`'s `_spawn_rock(pos)` and `_spawn_tree(pos)`
keep their existing `StaticBody3D` + primitive `CollisionShape3D` exactly
as they are today (`BoxShape3D` 2×2×2 for rocks, `CylinderShape3D` radius
0.4 height 2.0 for tree trunks) — collision and nav-mesh baking depend on
these simple shapes and are unaffected by the visual change.

What changes: instead of building a `MeshInstance3D` from a primitive mesh,
each function picks one entry at random from its own small list of
`(scene_path, scale)` pairs, instantiates it, applies the scale and a
random Y rotation (`randf_range(0.0, TAU)`) for natural variety, and adds
it as a child at the same position the old mesh used.

Scale values were derived from the real bind-pose bounding boxes of the
static (non-skinned) Kenney meshes, verified via a throwaway Godot probe
scene during design, then chosen to approximate the game's existing tree
and rock proportions:

| Model | Measured unscaled size | Scale | Resulting size |
|---|---|---|---|
| `tree_pineRoundA`/`C` | ~1.37 m tall | 1.9 | ~2.6 m tall |
| `tree_pineTallA`/`C` | ~1.53 m tall | 1.75 | ~2.7 m tall |
| `rock_smallA`/`D` | ~0.36 m footprint | 2.2 | ~0.8 m footprint |
| `rock_largeA`/`D` | ~0.8–1.0 m footprint | 1.6 | ~1.3–1.6 m footprint |

These are starting values, not exact requirements — a small visual
adjustment (±20%) during implementation to make trees/rocks look right
next to the player and the 2 m tile grid is expected and fine; verify by
manual playtest, not by matching the table exactly.

## Animal integration

`data/animals.json`: add `"model_path"` (pointing at the matching `.gltf`
file under `assets/models/animals/`) and `"model_scale"` (float) to the
`fox`, `wolf`, and `deer` entries. The `bear` entry is untouched — no
`model_path` means `_spawn_animal()` keeps using today's procedural
capsule + `_add_animal_features("bear", ...)` path unchanged.

Starting `model_scale` values, derived the same way (bone-position probe
in the `Idle` pose, since these skinned meshes' raw bind-pose bounding box
is not representative of standing size — it's skewed by a mid-stride
reference pose baked into the mesh data):

| Animal | Measured standing height (Idle pose, head bone) | Scale | Resulting height |
|---|---|---|---|
| Fox | ~2.12 m unscaled | 0.45 | ~0.95 m |
| Wolf | ~2.12 m unscaled | 0.5 | ~1.06 m |
| Deer | ~3.81 m unscaled | 0.35 | ~1.33 m |

Again, starting values to be confirmed visually against the existing 1.2 m
capsule collider — not exact requirements.

`game/world/level_loader.gd`'s `_spawn_animal()` already instantiates
`model_path` as a child named `"Mesh"` positioned at `Vector3(0, 0.6, 0)`
when present; it additionally needs to apply `model_scale` to that
instantiated node.

`game/animals/animal.gd` gains animation playback for animals with a real
model loaded:

- On ready, look for an `AnimationPlayer` inside `mesh_node` (present only
  for fox/wolf/deer's real models; absent for the bear's procedural mesh).
  When absent, all animation calls are no-ops — the bear's behavior and
  appearance are completely unaffected.
- Looping locomotion animation follows the animal's current state:
  `IDLE` and `LOOK` play `"Idle"`; `WANDER` plays `"Walk"`. (Fox/wolf/deer
  are all non-aggressive in today's data, so they never enter `CHASE` or
  `FLEE` — this design does not need to map those states for them. If a
  future aggressive non-bear animal is added, `CHASE`→`"Gallop"` is the
  natural extension, but that is not built now.)
- Being petted (the existing heart/hop reaction in `_play_pet_effect()`)
  additionally plays a one-shot `"Eating"` animation, after which normal
  state-driven playback resumes automatically.

## Testing

- Headless boot (`--headless --path . --quit`) must show no import errors
  and no `SCRIPT ERROR`/`Parse Error` — confirms the new `.glb`/`.gltf`
  files import cleanly and the modified scripts compile.
- Manual playtest by the user: model scale/proportions, animation
  playback and transitions, and general "does it look right" cannot be
  verified by a headless boot and must be checked in a running game, same
  as every prior roadmap step.

## Deferred / explicit non-goals

- A real bear model (no free CC0 one was found during this design).
- Using Kenney's `_dark`/`_fall` tree-rock color variants for a seasonal
  look.
- Spawning additional Kenney nature decoration (mushrooms, flowers, logs,
  bushes) that the level loader doesn't currently place.
- Any change to the player or building-block visuals.
