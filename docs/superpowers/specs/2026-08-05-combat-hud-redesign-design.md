# Combat HUD Redesign

## Status and scope

This design reconciles an external visual specification — the "Redshift Combat HUD" deck produced in a Claude Cowork session, comprising `GODOT_BRIEF.md`, `SegmentBar.gd`, and `redshift_ui_deck.html` — against the constraints of this codebase. The deck is an input, not an authority: it was written without knowledge of the display policy, the 3D battle room, `EnemyGuardStack`, or the reach of role colour. Where it conflicts with a recorded decision, this document says which wins and why.

The scope is shared UI primitives plus the battle HUD:

- a palette resource, theme type variations, and a typeface change;
- `SegmentBar`, one widget for every discrete bar in combat;
- hero card, enemy plate, ability bar, turn order, and bottom rail composition;
- the colour and typography rules that govern them.

Out of scope, deliberately: the hub, dungeon, terminal, and menu screens. Role colour is removed from battle UI only. `src/map/hero_status.gd` reads the same `current_role.color` property and keeps it, so role presentation is knowingly inconsistent between battle and dungeon until a follow-on effort addresses it. Recording that here is preferable to discovering it during acceptance.

This design supersedes the enemy-plate resting-state contents defined in [Readable Enemy HUD and Formation](2026-08-03-readable-enemy-hud-and-formation-design.md). That document's formation staging, projection anchoring, collision acceptance rules, and idle-loop behavior remain authoritative.

## Goal

Make combat state readable at a glance by spending the screen's colour budget on urgency instead of on category, and by drawing every countable quantity with one widget that cannot misrepresent its own ceiling.

## The reference canvas, and why the deck's first instruction is rejected

The deck opens by directing a switch to a `1280x800` reference canvas with `keep` aspect. This is rejected.

[Steam Deck Responsive UI](2026-07-15-steam-deck-responsive-ui-design.md) already considered and rejected exactly that change, because it "would disturb nearly every established layout." The project authors at `1920x1080` with `canvas_items` and `expand`, so a 16:10 window gains logical height rather than letterboxing, and density is handled by a display-profile service that battle UI already implements through `apply_display_profile()`.

The deck's underlying complaint is legitimate: a `1920`-authored HUD rendered at `1280x800` scales to roughly two thirds, and "design big then shrink" is how HUDs become illegible on handhelds. The answer in this codebase is the compact profile, not the canvas.

The practical consequence is that every dimension in the deck is expressed in `1280`-space and must be carried into `1920`-space at `1.5x`. To keep Deck rendering crisp under the resulting `2/3` downscale:

**Cell width and height are authored as multiples of three.** A `12`-pixel cell becomes exactly `8` at `1280`. Gaps, skew, and row spacing are exempt — they are negative space and shear, and do not need to land on whole pixels the way a drawn edge does.

The deck's further instruction to set `Default Texture Filter` to `Nearest` is also rejected. It is a project-wide 2D setting affecting dungeon and hub art, not a HUD-local one, and the HUD's legibility problems are addressed by icon redesign rather than by filtering.

## UIPalette

One `@tool` `Resource` at `src/ui/theme/ui_palette.gd`, instanced once at `data/theme/ui_palette.tres`, holding every colour battle UI is permitted to use:

- **Surfaces** — `panel`, `panel_hi`.
- **Strokes** — `stroke`, `stroke_hi`, `stroke_warm`.
- **Ink** — `ink`, `ink_dim`, `ink_faint`, `ink_hi`.
- **Accent** — a single cyan, reserved for the active unit and focus.
- **HP alarm ramp** — `hp_ok`, `hp_warn`, `hp_crit`.
- **Other** — `guard`, achromatic by intent; `threat`, for lethal forecast only.

Battle UI introduces no colour outside this resource. The rule is what makes the alarm ramp work; without it the ramp is just three more colours among many.

### Colour rules

1. **Colour is an alarm.** A healthy unit is achromatic steel. The HP ramp moves to `hp_warn` below fifty percent and `hp_crit` below twenty-five. Nothing else in the HUD is warm, so a hurt unit is the only bright thing in frame.
2. **The accent means one thing.** Cyan marks the active unit and focus. Never decoration.
3. **Role is never a fill colour.** Role lives in its glyph and its label. Card and panel backgrounds are reserved for turn state.
4. **Iconic shapes are legends, never quantities.** One shield glyph heads the guard gauge; one bolt heads the focus tally. Neither is ever repeated N times — irregular silhouettes cannot be counted pre-attentively.
5. **Group anything countable above five.** Focus breaks into fives so seven reads as seven without counting.
6. **Guard is achromatic.** It is the one gauge that must never compete with the HP ramp.
7. **No backdrop blur.** A `BackBufferCopy` plus shader costs real GPU time on the Deck. A more opaque `StyleBoxFlat` preserves the look.
8. **No font size is hardcoded on a node.** Every size comes from a theme type variation.

## Typography

Oxanium replaces Archivo and SUSE Mono across battle UI.

The HUD does not need a monospaced alphabet; it needs **tabular figures**, so that HP and guard digits do not reflow as they tick. The font variation sets `opentype_features = {"tnum": 1}`. This is the only typographic property the layout depends on.

`data/theme/fonts/suse_mono_bold.tres` is renamed rather than left naming a proportional face, and its consumers updated.

Four `Label` type variations are added to `data/theme/default_theme.tres`, which currently carries a flat `Label/font_sizes/font_size = 32` and no variations at all:

| Token | Authored at 1920 | Renders at 1280 | Deck comfort floor |
|---|---:|---:|---:|
| `LabelMicro` | 27 | 18 | 17 |
| `LabelLabel` | 30 | 20 | 19 |
| `LabelValue` | 33 | 22 | 22 |
| `LabelSub` | 27 | 18 | 17 |

`LabelMicro` carries tracked capitals, hotkeys and role labels; `LabelLabel` carries unit and ability names; `LabelValue` carries HP and resource numerals; `LabelSub` carries the `/max` tail.

Cap ratio varies by family, so the deck's browser-measured audit does not transfer. Implementation must measure real glyph height in engine with `font.get_char_size("H".unicode_at(0), size).y` and confirm every token clears the nine-pixel floor at `1280x800`. `font.get_height()` includes ascent and descent and is not the right measurement.

## SegmentBar

One `Control` at `src/ui/segment_bar.gd` draws every discrete bar in combat through `_draw()` polygon calls. No textures, no nine-patches, no shaders, so cell count, size, gap, skew and colour stay live-editable.

Three styles:

- **PIPS** — N skewed cells, fill growing bottom-up, the leading cell showing the fraction. Used for HP.
- **WRAPPED** — `max_value` cells at constant size, wrapped `per_row` per line. Used for guard.
- **TALLY** — N cells grouped every `group_every`. Used for focus and ability cost.

It replaces `EnemyGuardStack`, both enemy HP `ProgressBar` nodes, and the hero card's `Pip1..N` focus row.

### Guard is a hit counter

`EffectDamage._apply_guard_behavior` reduces guard by exactly one per shredding hit, breaching instead when guard is already zero. `DamagePreview._apply_preview_guard` mirrors that rule for forecasting. Guard is therefore a count, not a proportion, and the player's real question is how many more hits the shell absorbs. Three consequences:

1. **One cell is one hit, at constant size, on every unit.** Heroes cap at `MAX_GUARD` of ten, enemies at `MAX_ENEMY_GUARD` of thirty, both enforced through `get_guard_cap()`. A cell means the same thing on both.
2. **The gauge wraps rather than stretching.** Row count therefore *is* the ceiling — one row is ten, three rows is thirty — so a heavily armoured enemy is legible before a digit is read, and nothing can overfill a bar whose cap is invisible.
3. **The numeral is never hidden**, at any plate size, resting or expanded.

Width is consequently identical for every unit and only height varies, so plates keep a uniform footprint regardless of encounter composition. Guard at zero remains on screen, dimmed: the shell being down is precisely the state the player most needs to see.

This refines rather than replaces the existing `EnemyGuardStack`, which already layers ten pips per row across three rows. The gains are constant pitch, constant width, achromatic treatment, and a widget shared with heroes.

### Cell geometry

Derived at `1.5x` from the deck, with cell dimensions held to multiples of three:

| Configuration | Authored at 1920 | Renders at 1280 | Note |
|---|---|---|---|
| HP pips, hero | 21x36 | 14x24 | exact |
| HP pips, enemy | 18x27 | 12x18 | one pixel wider than the deck |
| Guard, wrapped | 12x9 | 8x6 | one pixel taller; `7.5` does not divide |
| Focus tally | 9x24 | 6x16 | exact |
| Ability cost | 9x21 | 6x14 | one pixel taller |

HP uses ten cells so that one pip reads as ten percent. Guard derives its count from `max_value` at ten per row. Focus uses ten cells grouped every five. Ability cost uses the ability's cost as its cell count.

### Required corrections to the supplied script

The deck's `SegmentBar.gd` is explicitly untested against a live editor. Three defects must be fixed:

- `tween_to` creates a tween without killing its predecessor, so repeated damage ticks animate against each other. It must kill any live tween first.
- `set_process` is called only in `_ready`, so toggling `pulse_when_critical` at runtime does not start or stop processing. The setter must drive it.
- The script is `@tool` and runs `_process`, which animates in the editor. Editor-time animation must be guarded.

If `draw_polyline` antialiasing makes single-pixel strokes fuzzy, disable it and let the skewed edges alias; at Deck density that reads correctly.

## Hero card

Three cards at `400x160`. Composition:

1. role glyph, unit name, role label;
2. HP pips inline with the HP numeral;
3. guard — shield legend, wrapped gauge, numeral — sharing a row with focus — bolt legend, tally, numeral.

A value sits beside the bar it describes. Numerals do not move to a header row: a header stretches the whole card to hold a number.

Conditions occupy an always-visible `HBox` **below** the card, requiring roughly thirty-six pixels of clearance at `1920` before the ability bar begins.

The active unit is marked by a cyan edge and label. Turn state owns the card background.

### Role colour removal

Rule 3 has a defined blast radius inside battle. `action_bar.gd` applies `current_role.color` to the passive panel, both shift panels, and every action button through `setup()`. `actor_queue.gd` tints turn-order role icons the same way. All of it is removed; role survives as glyph plus label.

`src/map/hero_status.gd` applies role colour in the dungeon and is out of scope, as stated above.

## Enemy plate

The projected enemy HUD keeps its existing model anchoring, detail positioning, and viewport clamping. Only the contents of the two states change.

**Resting** shows intent, HP pips, the guard gauge, the guard numeral, and conditions. The exact HP numeral moves out of `CompactStack` into `Details`.

**Expanded** adds unit name, level, exact HP, and the kinetic and energy defence profile.

The governing principle is that **identity is a hover cost, not a permanent one**: with five enemies on screen, a resting plate shows only what the player acts on, and names and exact numbers are what expansion is for. The resting state answers "should I attack this at all"; the reveal answers "with which ability." Expansion triggers on pointer hover **and** on controller target cycling, because hover alone strands controller players. The expanded plate draws at a raised `z_index` and may overlap neighbours, since only one is ever expanded.

Two flags survive into the resting state without text:

| Flag | Encoding | Rationale |
|---|---|---|
| Lethal — this attack kills it | bright `threat` bracket around the cluster | the most actionable read on screen, at zero width cost |
| Elite or boss | `stroke_warm` hairline outline | rank, not identity; a different visual weight from lethal so the two never collide |

Defence values are achromatic. They are static statistics, not alarms. If an exploitable defence should later stand out, the lever is weight, not hue — `accent` already means active unit.

Two layout rules that containers make easy to break: the guard gauge takes its natural width rather than expanding, so its numeral stays a constant distance from it at every plate size; and a two-character box is reserved so a drop from thirty to nine does not shift the row.

### Accepted risk

Removing the resting HP numeral is an accepted trade, not a free win. Encounters run duplicate drones, and two identical resting plates showing the same intent are hard to attribute. The mitigation is that identity now lives in the 3D drone itself — position, animation, and target outline — which a flat mockup could not represent. This is unproven and carries an explicit acceptance gate below.

## Ability bar, turn order, bottom rail

Ability cost renders as a `SegmentBar` TALLY. An unaffordable ability reads its shortfall in `threat`.

Turn-order tokens are ink on panel, with the active token in `accent` and hostile entries carrying a `stroke_warm` hairline. Role no longer tints them.

The bottom rail consolidates shift role, passive, input prompts, shift action, and shift role into a single rail — `58` pixels in the deck, `87` at `1920`.

This supersedes the uncommitted spacer-based `BottomRow` restructure in `src/battle/action_bar.tscn`. That work is replaced rather than extended, and is recorded here so the discard is deliberate.

## Reconciling the palette with the 3D room

The deck's palette was designed against a near-black void. Every rule depends on the claim that nothing else on screen is warm. The actual battle world is a lit industrial bay, and recent work added glow, bloom, emissive strips, and warm practical lights.

Two conflicts follow.

**The target outline duplicates the accent.** Uncommitted work in `src/battle/presentation/enemy_drone_presentation.gd` introduces green outlines for available and selected targets, creating a second colour meaning "this one is selected." The outline is repalettised: neutral `stroke_hi` for available, `accent` cyan for selected. Green leaves the battle presentation. The four `TARGET_OUTLINE_*` constants are rewritten to read from `UIPalette`.

**The room competes with the alarm ramp.** This design takes a position rather than hedging: **HUD colour is the alarm channel.** If an amber unit does not win against the room's practicals and glow, the room is dimmed — not the HUD. Warm environment light is atmosphere; warm HUD colour is information, and information outranks atmosphere.

## Icon legibility

The deck's measured audit of `assets/graphics/icons/` is adopted as findings. The pattern it identifies is that thin radial and linear elements fail first while compact filled masses survive.

- Icons in slots that carry a text label are left alone; context rescues them.
- Icons in **unlabelled** slots below roughly twenty-six pixels need simplified redraws. `winged-sword.png` is the confirmed instance: it is the Vanguard role icon in `data/heroes/sands/roles/van.tres`, rendered unlabelled in the turn-order track through `actor_queue.gd`, and it measured worst in the audit. This is a live defect in the current build, independent of this redesign.
- Detail is never recovered by sharpening or by a different downscale. It has to be designed out.

Legend glyphs — the shield beside the guard numeral, the bolt beside focus — are purpose-drawn primitives of three or four straight lines, never game art. Existing shield art measured as an unreadable blob at legend size.

Condition icons are the hardest slot in the HUD: small and unlabelled. A purpose-drawn condition set with simplified silhouettes is required, together with a hover and focus tooltip naming the effect. This is the largest art cost in this design and must not be underestimated. Icon sizing derives from feature size — the smallest meaningful stroke or gap inside the glyph — not from font size; they are different perceptual channels, and text has linguistic redundancy that icons lack.

## Disposition of uncommitted work

The working tree carries in-progress work that this design partly supersedes. Before implementation begins:

- The two failing tests are resolved. `test_action_button_reports_its_complete_container_safe_footprint` fails because `action_button.tscn` moved `DynamicGlyph` outside the component footprint; `test_enemy_hp_multiplier_is_editable_from_one_through_twenty_in_inspector` fails because `endgame_battle_lab.tscn` carries a temporary multiplier of `1.0`.
- Stray editor leftovers in `action_button.tscn` are reverted: the `Highlight` panel lost `visible = false` and gained an asymmetric offset, and placeholder text changed from `"Action Name"` to `"Energy Blast"`.
- The Exo 2 font resources are superseded by Oxanium. The deck evaluated Exo 2 and moved away from it.
- The `action_bar.tscn` restructure is superseded by the bottom rail.
- The `TARGET_OUTLINE_*` constants are repalettised.

The 3D lighting, glow, area-light, and material-tuning work is unaffected and stands. `test_directional_shift_keyboard_mode_uses_kenney_textures` fails intermittently in full-suite runs and passes in isolation, indicating input-mode leakage between scripts. It is unrelated to this design and is not addressed here.

## Verification

### Automated

- `SegmentBar` minimum size across all three styles; wrapped gauge producing one row at a cap of ten and three rows at a cap of thirty **with identical widths**; partial-fill fraction on the leading pip; alarm transitions across OK, WARN and CRIT boundaries; tween replacement not compounding.
- Cap height for all four type tokens measured in engine against the nine-pixel floor at `1280x800`.
- Extension of existing enemy-plate bounds coverage to the numeral-free resting state, and to the presence of the guard numeral in both states.
- Battle UI colour assertions at key nodes against `UIPalette`.

### Manual

The documented responsive acceptance sequence at `1280x800` and `1920x1080`, plus the CTB combat checklist, per [testing guidance](../../testing/README.md).

Three gates specific to this design:

1. **Five drones, at least two identical, all resting — confirm they remain distinguishable.** This is the risk accepted when the resting HP numeral was removed. If it fails, the numeral returns to the resting state and identity-as-a-hover-cost is rejected on this point.
2. **Composite a hero card and enemy plate over the live `battle_world_3d`** and confirm an amber or red unit is the brightest warm element in frame. If it fails, the room dims.
3. **Condition icons at final size, unlabelled**, confirming the redrawn set is identifiable before it ships.

Automated bounds coverage does not establish visual acceptance, and none of the three gates above can be automated.

## Rejected alternatives

- **A `1280x800` reference canvas.** Reverses a recorded decision, letterboxes 16:10 rather than using the additional height, invalidates authored offsets across every screen, and orphans the display-profile service.
- **Battle authored at `1280` while other screens stay at `1920`.** Two coordinate policies in one project, which [coordinate spaces](../../coordinate-spaces.md) exists to prevent.
- **A parallel `CombatHUD.tscn` built beside the existing scene and cut over at the end.** Duplicates binding logic against live combat signals and concentrates all risk in a single commit. Primitives-first replacement keeps each step landable.
- **Applying only the colour and typography rules.** Cheapest and delivers much of the perceived improvement, but cannot deliver the guard gauge or the resting-plate change. Retained as the natural first phase rather than as an end state.
- **Project-wide `Nearest` texture filtering.** Affects dungeon and hub art to solve a HUD icon problem that icon redesign solves properly.
