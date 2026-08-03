# Readable Enemy HUD and Formation

## Status and scope

This design supersedes the 160-pixel compact-width and 108-pixel HP-bar decisions in [Enemy World HUD Alignment](2026-08-03-enemy-world-hud-alignment-design.md). Its guard layering, status labels, model-sized targeting, inspection-only details, and idle-loop rules remain authoritative unless this document says otherwise.

The change covers ordinary encounters with one through five enemies, the projected enemy HUD, and directional health feedback shared with actor cards. Boss presentation remains separate because a large center-volume boss will need bespoke staging.

## Goal

Make enemy information readable at a glance without detaching it from the 3D enemy or allowing five HUDs to become a collision-driven staircase. The W/M formation and projected HUD must be designed together as a first-person diorama: visibly distinct front and back rows create room for larger model-anchored HUDs.

## Formation-aware staging

Ordinary W and M formations retain their existing membership rules:

- W uses three enemies in back and two in front at five enemies.
- M uses two enemies in back and three in front at five enemies.
- Counts below five use the corresponding authored subset.

The two rows become more pronounced in actual 3D staging. Back-row enemies are farther from the camera, project higher on screen, and appear smaller. Front-row enemies are closer, project lower, and appear larger. Formation depth, lateral spacing, and camera framing are tuned together until the rows read immediately in first person.

HUDs receive no independent collision or staircase offsets. Every compact HUD remains centered on its model's projected head anchor. The model and its HUD therefore move together when camera motion changes the projection.

The acceptance outcome is more important than any particular world-unit constant:

- five ordinary enemies remain inside the authored battle volume;
- compact HUD rectangles do not intersect in either W or M;
- an inspected detail block does not cover another enemy's compact HUD;
- all compact HUDs stay within the viewport safe rectangle;
- the front and back rows remain visually attributable to their models.

If a real five-enemy acceptance pass exposes overlap, increase or rebalance formation depth and lateral separation. Do not shrink the HUD or reintroduce a dynamic HUD collision solver.

## Compact enemy HUD

The projected enemy HUD returns to a 220-pixel compact width. The always-visible vertical order remains:

1. intent;
2. HP;
3. overlapping guard shields or `VULNERABLE`/`BREACHED`;
4. condition icons.

The rounded HP bar is 168 pixels wide. The compact HUD does not permanently print an exact HP number. Pointer hover supplies a `current / max` tooltip, keeping the five-enemy view quiet while preserving precision on demand.

The approved guard rules remain unchanged:

- enemies support at most 30 guard while heroes remain capped at 10;
- ten fixed X columns form each layer;
- additional layers move only downward by 5 pixels;
- the current layer is white, the preceding layer medium gray, and the oldest third layer dark gray;
- the exact guard integer appears in the newest shield;
- zero guard displays `VULNERABLE` or `BREACHED` in the guard slot;
- conditions remain 5 pixels below the actual guard or status depth.

The guard stack returns to its natural 202-pixel horizontal extent: ten 22-pixel shields at 20-pixel column spacing, centered inside the 220-pixel HUD. This must not change shield count, layer direction, 5-pixel layer offsets, colors, or status behavior.

## Details and targeting

The enemy name and kinetic/energy defenses appear at one fixed offset below the owning compact HUD. They never flip above or beside it and never move another HUD. Only pointer hover or controller inspection focus reveals this detail block.

Targeting remains model-first:

- the clickable region uses projected 3D model bounds rather than the visible HUD rectangle;
- valid enemy targets receive the established green model outline;
- group targeting may outline multiple models without opening multiple detail blocks;
- compact HUD highlighting remains separate from inspection detail visibility.

## Directional health feedback

Enemy world HUDs use the same two-layer health language as actor cards.

- The foreground actual-health bar remains pink.
- Damage feedback uses a yellow delayed bar beneath it.
- Healing feedback uses a green delayed bar beneath it.

On damage, pink reveals the authoritative lower HP immediately while yellow preserves the prior value and then drains down to meet it. On healing, green previews the authoritative higher HP while pink fills up to meet it. At rest, both layers agree with authoritative HP and the feedback layer is no longer visually distinct.

The same yellow-for-damage and green-for-healing rule applies to hero cards and any remaining actor-card presentation so combat feedback is consistent across the interface.

An interrupted health animation starts from the currently displayed values, replaces only the prior health animation, and settles at authoritative HP. It must not complete or cancel unrelated acting, action-display, hit, or defeat operations.

## Presentation ownership

- `BattleFormationLayout` owns ordinary enemy world transforms and the stronger front/back staging.
- The battle camera and room framing expose that depth without changing combat rules.
- `EnemyWorldHUD` owns its editable compact/detail geometry, dual HP layers, tooltip, guard/status display, conditions, and health animation state.
- `EnemyDronePresentation` supplies projected model/head bounds, targeting presentation, and the presentation-operation boundary used by battle sequencing.
- Combatants remain authoritative for current and maximum HP. Presentation animation never writes gameplay state.

The solution should reuse established actor-card health semantics rather than maintaining two subtly different timing models. A broad unrelated card refactor is outside scope.

## Verification

Automated coverage protects:

- W and M membership for one through five ordinary enemies;
- pronounced, ordered front/back depth without changing combatant count or local model ownership;
- 220-pixel compact HUD width and 168-pixel rounded HP geometry;
- five-HUD safe-area containment and nonintersection for both formations at supported logical canvases;
- fixed detail placement and single-inspection visibility;
- model-projected pointer and controller targeting;
- yellow damage feedback and green healing feedback on actor cards and enemy world HUDs;
- animation replacement and authoritative final HP;
- guard layering and zero-guard status behavior retained from the preceding design;
- continuous idle looping with transient clips remaining one-shot.

Manual acceptance uses five enemies in both W and M at `1920x1080` and native `1280x800`. It checks model/HUD attribution, row readability, overlap, long intent text, guard layers, conditions, pointer targeting, controller targeting, detail reveals, damage, healing, and uninterrupted idle motion. Steam Deck hardware acceptance remains separate from a desktop `1280x800` proxy.
