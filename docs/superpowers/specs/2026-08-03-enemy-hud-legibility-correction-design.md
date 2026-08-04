# Enemy HUD Legibility Correction

## Status

Approved on 2026-08-03.

## Scope

This focused correction supersedes the HP width, horizontal shield spacing, detail placement, and compact typography decisions in [Readable Enemy HUD and Formation](2026-08-03-readable-enemy-hud-and-formation-design.md). Formation transforms, guard-layer depth, health feedback colors, targeting behavior, combat rules, and condition behavior remain unchanged.

## Compact hierarchy

The persistent model-anchored hierarchy remains intent, HP, guard or status, and conditions. The HP track expands to the full 220-pixel compact HUD width so the guard strip no longer looks wider than the bar it protects.

Guard renders in front of the HP bar and overlaps its lower edge. Horizontal guard pips no longer merge: each pip is 21 pixels wide on 22-pixel centers, creating a 1-pixel gap while keeping ten columns inside the 220-pixel HP track. Additional guard layers retain the approved 5-pixel downward step.

## Inspection hierarchy

Pointer hover or controller inspection reveals a fixed detail block above the persistent intent and vitals. The block never flips below or beside the HUD and does not move the persistent compact stack. Its hierarchy is:

1. enemy name;
2. kinetic and energy defenses;
3. persistent intent;
4. HP, guard or status, and conditions.

The name uses approximately 22-pixel type and defenses use 17–18-pixel type. Persistent intent, guard value, and `VULNERABLE`/`BREACHED` increase to approximately 16-pixel type. Exact values remain editable scene tuning, but automated coverage protects these minimum readability levels.

## Layout and ownership

`EnemyWorldHUD` owns the geometry, typography, draw order, and fixed upper detail placement. Inspection may expand the visible layout upward, but it does not reflow the compact HUD or detach it from the projected model anchor. The existing 220-pixel compact width avoids another ordinary-formation retune.

## Verification

Automated checks protect the full-width rounded HP track, centered and separated guard pips, guard-over-HP draw order, minimum font sizes, fixed upper detail placement, unchanged compact position during inspection, safe-area containment, and five-enemy W/M nonintersection at supported logical canvases and camera yaw limits.

Manual acceptance at `1920x1080` and native `1280x800` confirms that intent and inspection text are comfortably readable, shields remain visually distinct, the HP bar visually contains the guard strip, details read above their owning enemy, and hover or controller inspection does not obscure another enemy HUD.
