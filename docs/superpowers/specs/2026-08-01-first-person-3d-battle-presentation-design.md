# First-Person 3D Battle Presentation Design

## Status

Approved in collaborative design on 2026-08-01. Pending review of this written specification before implementation planning.

## Summary

Replace the flat enemy-card battlefield with a shared first-person 3D battle room. Heroes remain represented entirely through the combat UI, while enemies become animated 3D units with projected screen-space HUDs. The existing combat rules, enemy AI, damage model, conditions, targeting rules, and CTB system remain authoritative.

This is a production-foundation change rather than a disposable visual prototype. Combat state is separated from its presentation so a 2D hero card and a 3D enemy unit can participate in the same battle without either visual node serving as the gameplay model.

The initial production milestone is one complete representative encounter using the final architecture. Subsequent enemies and rooms should be content migration, not another structural rewrite.

## Goals

- Give enemies physical presence and animation inside a first-person sci-fi encounter space.
- Preserve the existing command-driven, ranged CTB combat rather than imply shooter controls.
- Keep heroes as UI-only party members with no visible bodies, hands, or weapons.
- Make combat fully usable with a controller and give mouse input equivalent information and targeting behavior.
- Preserve the current strategic readability of enemy intent, Guard, HP, conditions, defenses, and duplicate identity.
- Establish a clean gameplay/presentation boundary suitable for a larger game.
- Support up to five ordinary enemies, alternate encounter compositions, and unusually large bosses.
- Use the Quaternius Modular Sci-Fi MegaKit and Sci-Fi Essentials Kit as the initial environment and enemy art foundation.

## Non-goals

- Visible hero models, first-person hands, or weapon models.
- First-person locomotion, free-look, manual aiming, or shooter mechanics.
- Mechanical range, front/back rows, cover, or formation-dependent rules.
- Touch-specific control design.
- Cinematic attack cameras or frequent camera cuts.
- Changes to combat arithmetic, hero kits, enemy decisions, target legality, or CTB rules.
- A project-wide UI redesign unrelated to the battle presentation.
- Changing the Godot version or importing an asset pack's entire sample project as the new project foundation.

## Experience Principles

The camera represents the party's location. The player commands heroes through the UI and experiences their attacks as effects originating near the camera. Enemies occupy the physical world and attack back toward the party's hero panels.

The scene should feel alive through enemy animation, environmental motion, restrained camera parallax, impact response, and first-person effects. It should not behave like an FPS. The camera remains composed, target selection remains discrete, and every strategically relevant fact remains readable without aiming at fine 3D geometry.

## Combatant and Presentation Architecture

### Authoritative combatant

Introduce `BattleCombatant` as a non-visual `Node` and the common participant used by the battle manager, actions, effects, AI, conditions, targeting, and CTB simulation. Combatants live under the combat-authority branch of the battle scene rather than under either presentation tree. Each one owns or exposes:

- stable combatant identity;
- current and derived stats;
- HP and Guard;
- conditions and traits;
- CT and turn state;
- defeat, breach, danger, and revival state;
- targetability and faction;
- the semantic signals required by presentation.

Combat systems target `BattleCombatant`, not `HeroCard`, `EnemyCard`, `Control`, or `Node3D`. The extraction should preserve existing public combat behavior and move only state and rules that currently depend on card inheritance. It must not rewrite working combat arithmetic or AI for stylistic purity.

### Hero presentation

`HeroCard` remains a 2D `Control` that presents one `BattleCombatant`. The current hero-panel experience may be cleaned up, but heroes do not gain world models.

The hero presentation remains responsible for the party member's visible HP, Guard, conditions, active-turn treatment, damage response, targeting feedback, and interaction surface. It never becomes the authoritative combat state.

### Enemy world presentation

Replace the visual concept of `EnemyCard` with an `EnemyUnit3D` presentation for one `BattleCombatant`. It owns:

- the animated 3D model;
- its formation-slot transform;
- selection, eligibility, and acting outlines;
- mouse hover and click collision;
- semantic animation playback;
- named world anchors;
- its projected `EnemyHUD` instance;
- presentation-only lifecycle and cleanup.

An enemy's model and HUD are logically one presentation even though they render in different systems. The model lives in the shared 3D world. The HUD lives in a shared screen-space UI layer and tracks the projected head anchor.

### Presentation boundary

Combat publishes semantic states and events such as:

- normal, available, selected, and acting;
- intent changed;
- HP, Guard, or conditions changed;
- attacked, hit, breached, recovered, defeated, or revived;
- action presentation requested.

Presentations decide how to show those facts. Models and animations cannot calculate damage, change target legality, choose an AI action, or alter CTB order.

Battle-facing effects request named presentation anchors such as `head`, `center`, `feet`, `muzzle`, and `impact` instead of reading a card rectangle or model-specific child path.

## Scene Composition

The battle scene contains three major areas:

1. `BattleWorld`, a shared 3D world containing the environment, camera, lighting, enemy units, projectiles, particles, and world effects.
2. `BattleUI`, a screen-space layer containing hero panels, the action interface, CTB rail, current-action presentation, enemy HUDs, and screen effects.
3. The combat authority, containing the battle manager and combatant models independently of either presentation tree.

The 3D world renders beneath the battle UI. It uses one camera and one environment; enemies must not use separate per-card SubViewports.

## Environment and Asset Foundation

Initial environments use the [Modular Sci-Fi MegaKit](https://quaternius.itch.io/modular-sci-fi-megakit). Initial enemies and props use the compatible [Sci-Fi Essentials Kit](https://quaternius.itch.io/sci-fi-essentials-kit). Both packs are offered under CC0 and provide glTF assets and Godot source versions.

Import only the assets needed for the first production encounter, preserving license records and required Godot sidecars. Evaluate the pack's Godot 4.3 materials and shaders under this project's required Godot 4.6.3 version instead of replacing project settings or copying an entire source project wholesale.

Each `EnemyData` references an `EnemyVisualProfile`. The profile selects the model scene, authored display scale, footprint category, outline configuration, semantic animation mappings, and any presentation defaults that vary by enemy type. Required anchor nodes remain part of the model-scene contract so their transforms can be inspected and animated with the model.

An authored `BattleEnvironment` scene contains:

- room geometry and props;
- lighting and environment settings;
- the fixed camera origin and motion limits;
- standard formation anchors;
- large-enemy and boss footprints;
- optional environmental animation and ambience;
- a quiet contrast region behind expected enemy HUD positions.

Detailed walls, ceiling structures, and lights may frame the encounter, but the region behind enemy heads should avoid bright lines and high-frequency clutter that compete with overhead information.

## Formation

Ordinary encounters support up to five enemies. Five anchors form one of two alternating-depth silhouettes:

- `W`: three rear anchors and two front anchors;
- `M`: two rear anchors and three front anchors.

Encounters choose the composition that best fits their models and visual rhythm. Row membership and exact position have no gameplay meaning because all combat is ranged.

Target navigation uses projected screen geometry rather than logical row rules. Models may overlap naturally in perspective, but authored anchors and HUD layout must preserve recognizable silhouettes and readable information ownership.

Standard enemies occupy one anchor. Large-enemy visual profiles may reserve wider footprints. A huge boss may replace the center three standard anchors, leaving one optional flanking ally on each outer side. Formation validation rejects overlapping declared footprints or encounters that exceed capacity.

## Enemy HUD

Each living enemy has a projected screen-space HUD anchored above its model's head. The persistent vertical hierarchy is:

1. intent;
2. Guard shield and HP bar on one row;
3. condition icons.

Guard appears as one shield icon containing the current numeric Guard value. Conditions remain compact icons in the ordinary state.

Mouse hover or controller focus enters the same inspection state and fades in secondary information:

- enemy name and rank/elite/boss identity;
- exact current and maximum HP;
- kinetic defense;
- energy defense;
- expanded condition information.

Duplicate enemies retain a compact `A`, `B`, or `C` identifier while unfocused so the world model, intent, and CTB entries remain mappable.

The HUD remains constant-sized, crisp, viewport-clamped, and independent of model distance. A deterministic screen-space layout pass gently separates overlapping HUD stacks. If a meaningful displacement makes ownership unclear, a faint leader line points back to the model's head anchor. A large boss uses one centered HUD rather than stretching UI across its full visual width.

## Target and Acting Presentation

The existing semantic target hierarchy carries into the world presentation:

- `NORMAL`: authored model appearance and compact persistent HUD.
- `AVAILABLE`: a steady, unmistakable outline around every legal model.
- `SELECTED`: a stronger animated outline plus the expanded inspection HUD.
- `ACTING`: the established CTB gold treatment, composed so eligibility and selection remain independently legible.

Mouse hit testing covers the visible model through 3D collision rather than requiring the player to click the HUD. Hover and click resolve to the same `BattleCombatant` identity used by controller targeting.

## Controller and Mouse Contract

Controller input remains state-based:

- During action selection, the four face buttons directly choose the four skill slots.
- Left and right triggers activate the corresponding role shifts.
- After an action requires a target, the D-pad or left stick navigates valid targets using their projected screen geometry.
- Confirm and cancel retain their current context-sensitive semantics.
- The right stick controls only restrained camera parallax.

Controller target selection always begins with a clear selected target using the current remembered-target and deterministic fallback behavior. Focus expands the same information that mouse hover reveals. No combat detail is available only to mouse users.

Mouse movement can hover models and drive ambient camera parallax at the same time. Click ownership and first-click consumption continue to follow the project's existing input-family rules. Mouse movement never changes a controller-owned target until mouse/keyboard ownership has legitimately changed.

Touch-specific interaction is outside this design.

## Camera and Motion

The camera remains at a fixed party viewpoint. Mouse position and the controller's right stick apply a small, eased yaw and pitch within authored limits. No input translates the party through the room.

Right-stick release recenters smoothly. Mouse movement back toward the viewport center does the same. Important presentation beats, modal UI, and enemy impacts may temporarily suppress or override ambient parallax so the composition remains readable.

Incoming attacks apply directional camera and UI response. A `Combat Shake Intensity` setting defaults to `50%` and scales impact motion from `0–100%`. Informational UI receives a deliberately weaker displacement than the 3D world. Panel shake moves only an inner visual container; the panel's layout rectangle, focus target, and mouse hit area stay fixed.

## Hero and Enemy Action Presentation

Heroes remain invisible, but their actions may use simple first-person effects. Lasers and projectiles originate just behind or below the camera's near plane and travel toward the selected enemy's impact anchor. Other actions may use camera-originating waves, screen-edge energy, environment lighting, or target-local effects.

The acting hero remains identified by its hero panel, action presentation, color language, and CTB state. The design does not add hands, weapons, reloads, or hero animation.

Enemy attacks originate at their model's authored muzzle or cast anchor and travel toward the camera. For hero-targeted actions, the projectile approaches a near-camera impact plane aligned with the targeted hero panel. The corresponding panel may glow, flash, shake internally, animate HP or Guard, and display damage, breach, healing, or condition feedback.

Multi-target actions may strike panels simultaneously or in a deterministic sequence. The visual path does not determine targets or results; it presents the targets and resolved outcome supplied by combat.

## Animation Contract

Enemy visual profiles map semantic beats to the clips and effects supported by a model:

- idle;
- intent telegraph;
- acting or attack;
- hit;
- breach;
- recovery;
- defeat;
- revival when legal.

Clip names are presentation data, not combat API. Optional missing clips use a defined no-op, pose, or timed fallback. Combat must never wait indefinitely for a missing animation, signal, or marker. Required model scenes and anchors fail authoring validation before a battle is accepted as valid content.

Combat remains authoritative about damage, conditions, and targets. Presentation may synchronize a resolved result to an impact beat, but an animation event cannot independently decide whether an attack hit or how much damage occurred.

## Lifecycle and Cleanup

Encounter setup creates combatants first, then binds the appropriate presentation:

- heroes receive hero-card presentations;
- enemies receive world-unit and projected-HUD presentations;
- the environment assigns formation transforms and camera configuration.

A defeated enemy immediately leaves target legality and loses its HUD, then plays its visual defeat. Its profile may collapse, dissolve, or clear the model. The presentation remains capable of returning if enemy revival is legal.

Battle teardown cancels presentation awaits, stops animations and tweens, frees models and projected HUDs, clears hover and selection ownership, removes transient effects, and leaves no world reference attached to combatants.

## Error Handling and Validation

Authoring validation covers:

- missing enemy visual profiles or model scenes;
- missing required anchors;
- invalid animation mappings;
- formation capacity and footprint conflicts;
- missing battle environments or camera definitions;
- a projected HUD that cannot resolve its combatant or anchor.

Required structural failures are explicit content errors, not silent substitution. Optional cosmetic animation gaps use safe fallbacks. Runtime presentation failures must release any awaited presentation step and report enough enemy, action, environment, and anchor identity to diagnose the authoring problem.

## Implementation Sequence

Do not broadly polish the current battle UI before introducing the 3D composition. Some current enemy-card visuals will be removed, and final spacing and contrast cannot be judged without real models and rooms.

Use this sequence:

1. Protect current public combat behavior with focused tests where seams are about to change.
2. Extract `BattleCombatant` and make the existing hero and enemy presentations consume it while preserving the current playable battle.
3. Establish the shared `BattleWorld`, screen-space battle UI layer, environment contract, camera, formation resources, and enemy visual-profile validation.
4. Build one production enemy unit, projected HUD, and representative encounter using the selected Quaternius assets.
5. Move target selection, intent, damage popups, conditions, breach, defeat, and CTB presentation through combatant identity and named presentation anchors.
6. Add first-person hero effects, enemy-to-panel attacks, parallax, shake settings, and semantic animation synchronization.
7. Clean and polish the surviving hero panels, action bar, current-action UI, CTB rail, and enemy HUD against the actual 3D scene at target resolutions.
8. Migrate remaining enemies and environments, then remove obsolete enemy-card presentation code and compatibility paths.

This sequence cleans the foundation before adding art, introduces real graphics early enough to guide composition, and postpones final visual polish until the true battlefield constraints exist.

## Verification

Automated verification covers:

- combat rules running with no 2D or 3D presentation loaded;
- existing damage, Guard, conditions, targeting, AI intent, CTB, revival, defeat, and battle-end behavior;
- hero and enemy views receiving the same combatant state transitions;
- controller and mouse selecting the same combatant identity;
- face-button skill and trigger shift mappings remaining unchanged;
- deterministic four-direction target navigation across W, M, reduced-count, and boss arrangements;
- formation capacity and footprint validation;
- HUD projection, viewport clamping, deterministic separation, duplicate identifiers, and anchor tracking;
- model hover/click behavior and input-family ownership;
- semantic animation fallbacks completing without a stalled turn;
- cleanup after defeat, revival, action cancellation, battle end, and scene teardown;
- shake behavior at `0%`, the default value, and `100%`.

Manual acceptance covers complete controller-only battles at `1920x1080` and `1280x800`, plus representative mouse play. Reviewers verify:

- environment and enemy visual cohesion;
- silhouette and HUD readability with five enemies;
- large-boss composition and flank readability;
- target, acting, intent, and CTB correspondence;
- first-person projectile paths and hero-panel impacts;
- camera parallax and recentering feel;
- maximum shake comfort and zero-shake accessibility;
- lighting contrast, condition legibility, animation timing, and performance with five animated enemies and concurrent effects.

The full automated suite is required before completion because the combatant extraction reaches runtime, targeting, input, AI, conditions, CTB, and scene lifecycle.
