# Local 3D Battle Slice Design

## Status

Approved on 2026-08-02. This design specializes the broader [first-person 3D battle presentation design](2026-08-01-first-person-3d-battle-presentation-design.md) for the first asset-backed vertical slice.

## Objective

Replace the current enemy-card battlefield with a compact first-person 3D industrial room containing actual enemy models, while preserving the existing combat rules, hero UI, controller behavior, and presentation boundary.

The first slice uses one EyeDrone model for every ordinary enemy. It exists to establish the production presentation pipeline, room composition, projected enemy HUD, animation routing, camera motion, and safe local asset workflow. Additional models and color variants come only after this slice looks and feels correct.

## Decisions

- The default battlefield is a neutral industrial ship or station room. It borrows the MegaKit's dark metal, structural ribs, strip lighting, vents, and floor lanes without copying a showcase room.
- The experimentation-lab look is reserved for a later encounter-specific environment.
- EyeDrone is the first and only ordinary enemy model in this slice.
- The room supports at most five ordinary enemies in alternating W/M formations: three back and two front, or two back and three front.
- A future large boss may reserve the center three slots while one ally occupies each outer side slot.
- Every Quaternius binary remains local and Git-ignored. Git LFS is not used because it would still upload the files to GitHub.
- Tracked scenes must load and test successfully when the local models are absent.

## Local Asset Boundary

### Directory policy

The ignored vendor root is:

```text
assets/graphics/models/quaternius_local/
```

The repository `.gitignore` excludes that entire directory. This covers models, textures, license copies, and Godot-generated import sidecars. The rule is deliberately limited to `quaternius_local`; future original or distributable models elsewhere under `assets/graphics/models/` remain eligible for version control.

A tracked manifest outside the ignored directory records:

- the two source kit names and original download locations;
- the CC0 1.0 license and Quaternius attribution;
- every whitelisted source file and its destination;
- expected local resource paths;
- setup and verification instructions.

A tracked setup utility accepts the Essentials and MegaKit roots as arguments, validates every source dependency, verifies the destination is ignored, and copies only the whitelist. It aborts before copying if the ignore rule is absent or a required dependency is missing. After copying, it confirms that Git reports no tracked or stageable files beneath the vendor root.

### Curated EyeDrone files

The EyeDrone bundle is flattened into its own local directory so the glTF's relative texture references remain valid:

```text
quaternius_local/enemies/eye_drone/
  Enemy_EyeDrone.gltf
  Enemy_EyeDrone.bin
  T_Enemies_BaseColor_png.png
  T_Enemies_Normal.png
  T_Enemies_ORM.png
```

The source model supplies `Idle`, `Attack`, `Hit`, `Charging`, `Look`, and `BackFlip`. The first slice routes only Idle, Attack, Hit, and Charging. Unsupported presentation requests fall back to Idle without blocking combat.

### Curated industrial-room files

The first room uses these eight MegaKit modules:

- `WallAstra_Straight_Flat`
- `TopAstra_Straight`
- `BottomMetal_Straight`
- `Platform_Metal`
- `Column_Astra`
- `Prop_Light_Wide`
- `Prop_Vent_Wide`
- `Prop_Cable_1`

Each module's `.gltf` and `.bin` are flattened into one local environment directory with the exact shared textures they reference:

```text
T_Trim_01_BaseColor_Red.png
T_Trim_01_Normal.png
T_Trim_01_ORM.png
T_Trim_02_BaseColor_Red.png
T_Trim_02_Normal.png
T_Trim_02_ORM.png
T_Trim_03_BaseColor.png
T_Trim_03_Cables.png
T_Trim_03_Normal.png
T_Trim_03_ORM.png
```

No FBX, OBJ, preview renders, unused models, or unrelated textures enter the project.

## Missing-Asset Safety

Tracked scenes never declare ignored models as `ext_resource` dependencies. A small optional-model node stores the local resource path as text and checks `ResourceLoader.exists()` before loading it.

When a local asset exists, the loader instantiates it under a stable transform pivot. When it is absent or fails to load, the node retains a lightweight tracked placeholder mesh. It reports one concise warning per missing logical asset rather than one warning per enemy instance.

This guarantees that:

- clean clones open without missing-resource parse errors;
- automated tests run without access to the Downloads folder or local kit files;
- gameplay never waits for presentation assets;
- local development automatically uses the real assets once the curated bundle is installed.

The optional loader may run in the editor so the locally installed room can be composed visually. Editor execution uses the same existence checks and must not rewrite imported resources.

## Scene Architecture

### Battle world

`BattleScene` gains a 3D world sibling behind its existing `UI` layer. The world owns:

- the compact industrial room;
- the battle camera and restrained lighting;
- five ordinary-enemy anchors;
- the future boss and side-ally anchors;
- presentation-only projectile and impact origins.

The current background treatment is hidden when the 3D world is active and remains available as a fallback. Hero cards, action controls, current-action display, and the CTB rail stay in 2D UI.

The manager's packed-scene exports use presentation-oriented names rather than card-oriented names. Hero presentation spawning continues under the hero UI area. Enemy presentation spawning targets the appropriate 3D formation anchor while the authoritative `EnemyCombatant` remains under the combatant-model root.

### Formation policy

An encounter with one through five ordinary enemies receives anchors deterministically from one of two authored layouts:

- `W`: three enemies in back and two in front;
- `M`: two enemies in back and three in front.

The encounter selects W or M presentation without changing targeting, range, or combat math. Empty slots do not collapse the remaining anchors into an even row; authored depth and overlap remain visible.

The boss layout is a separate presentation policy. A boss may occupy the visual volume of the center three slots while optional allies use the outer left and right anchors. The boss is still one combatant and one target.

## Enemy Presentation

The first enemy view is a `Node3D` scene containing exactly one `CombatantPresentation`. It owns:

- a stable transform pivot and optional EyeDrone loader;
- head and foot projection anchors;
- an animation adapter;
- selection, hit, action, and defeat presentation hooks;
- a screen-space target region derived from the projected model bounds.

Every ordinary enemy uses this same scene. Gameplay differences remain visible through name, Intent, Guard, HP, conditions, actions, and effects. No model or tint distinction is required in the first slice.

Future model or color variation belongs behind a presentation profile. Materials must be duplicated per instance before tinting so one enemy's palette cannot mutate every instance. No future-profile system is required merely to ship this single-profile slice.

### Animation mapping

The adapter normalizes gameplay presentation events to model-specific animation names:

- acting/idle state → `Idle`;
- ordinary ranged attack → `Attack`;
- taking damage → `Hit`;
- telegraphed charge presentation → `Charging`;
- defeat without a dedicated clip → a short presentation-owned shutdown/fade.

Missing clips complete their presentation operation immediately and return to Idle. Animation completion and view teardown use the existing cancellation-safe presentation-operation contract, so replacing or freeing a model cannot suspend battle orchestration.

## Projected Enemy HUD

Enemy information remains ordinary 2D `Control` UI for crisp text, deterministic focus, and resolution independence. Each enemy presentation projects its head and foot anchors through the battle camera.

The compact always-visible stack above the model is:

1. Intent;
2. Guard icon and value, then HP bar;
3. condition icons only.

Hover or controller focus fades in the enemy name and defenses without moving the compact stack. Controller focus and mouse hover share the existing target-presentation state; neither changes model authority.

The overlay clamps to the safe viewport area and resolves overlap deterministically while preserving its association with the correct enemy. A hidden, defeated, freed, or behind-camera model cannot leave a stale overlay or selectable target.

## Camera, Input, and Feedback

The battle camera is mostly fixed at player eye height. Mouse movement near the viewport edges creates a small clamped yaw/pitch offset and eases back toward center. The motion must preserve target projection and must not become free-look.

Controller input remains dedicated to combat. The camera does not consume the right stick because the CTB rail already owns it. A subtle presentation-owned idle drift may keep the scene alive without user input.

Enemy attacks may send simple first-person laser/projectile effects toward hero UI panels. The relevant hero panel can glow, flash, and shake on impact. A shared combat-shake intensity setting scales both camera and UI shake and supports zero/off. Feedback effects never own damage timing or state transitions.

## Failure Handling

- Missing local model: show the tracked placeholder and warn once.
- Missing animation: complete immediately, retain or restore Idle, and continue combat.
- Invalid formation request above five ordinary enemies: reject it at the encounter-presentation boundary with a clear error; do not silently overlap a sixth unit.
- Failed enemy view construction: preserve the manager's existing complete encounter rollback.
- Freed or replaced view: clear its overlay and complete pending presentation operations after registry state is stable.

## Verification

### Automated

- The curated setup utility copies exactly the whitelist and rejects missing dependencies.
- The Quaternius local directory is ignored and contains no tracked files.
- A clean clone without kit assets parses and runs with placeholders.
- The optional loader chooses real assets when available and placeholders when absent.
- One through five enemies receive deterministic W/M anchors.
- The future boss layout reserves center and side slots correctly.
- Every ordinary enemy may share the same EyeDrone presentation without shared mutable animation or material state.
- Projected HUD binding, target state, overlap resolution, teardown, and behind-camera behavior remain model-correct.
- Missing clips and view teardown cannot strand presentation operations.
- Existing controller targeting, CTB, AI, damage, defeat, and revival tests remain green.

### Manual

- Verify room scale, camera height, lighting, and background coverage at `1280x800` and `1920x1080`.
- Verify all W/M formations remain readable despite intentional overlap.
- Verify a large center placeholder and two side allies remain targetable.
- Verify mouse hover, controller focus, projected HUD stability, and overlay overlap.
- Verify EyeDrone Idle, Attack, Hit, Charging, defeat, and return-to-idle feel.
- Verify edge-look does not cause motion sickness or target drift.
- Verify camera/UI attack shake from zero through the supported intensity range.
- Verify the current hero UI, face-button skills, action affordability, and CTB rail remain readable and controllable.

## Out of Scope

- Additional enemy models or color variants.
- The experimentation-lab environment variant.
- Visible first-person weapons.
- Touch-specific battle controls.
- Final boss art or boss animation mapping.
- Packaging or redistributing the ignored Quaternius files through GitHub.
