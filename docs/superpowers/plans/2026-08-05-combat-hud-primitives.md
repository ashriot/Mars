# Combat HUD Primitives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared UI foundation the combat HUD redesign rests on — a palette resource, Oxanium with tabular figures, four theme type variations, and the `SegmentBar` widget — without moving a single node in an existing battle scene.

**Architecture:** Primitives first, bottom-up. Nothing in this plan changes how battle looks; it creates the pieces the screen work then consumes. `UIPalette` is a plain `Resource` holding every permitted colour. Type variations live in the project `Theme` as sizes only, because fonts are hydrated at runtime by `ThemeBootstrap` and the theme file must stay free of font paths. `SegmentBar` is one `Control` that draws HP pips, the guard gauge, focus tally and ability cost through `_draw()` polygon calls.

**Tech Stack:** Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`, GDScript, GUT 9.6.1.

**Source design:** [Combat HUD Redesign](../specs/2026-08-05-combat-hud-redesign-design.md)

---

## Scope

This plan covers **only** the shared primitives — sections "UIPalette", "Typography" and "SegmentBar" of the design.

The screen composition — hero card, enemy plate, ability bar, turn order, bottom rail — is deliberately **not** in this plan. Those tasks move existing nodes and depend on the widgets built here existing and being trusted. They get their own plan once this one lands. The design's role-colour removal, resting-plate change and target-outline repalettising all belong to that second plan.

At the end of this plan the game looks exactly as it does now, except in Oxanium. That is the intended outcome.

## Prerequisites

Work happens on `feat/combat-hud-primitives`, branched from **`codex/enemy-hud-contrast-feedback`** — not from `main`.

**This matters.** `main` is currently red: 1112 tests, 1109 passing, 3 failing. Two of those failures are `test_w_projects_five_stable_readable_hud_columns_across_camera_yaw` and `test_m_projects_five_stable_readable_hud_columns_across_camera_yaw`, where enemy detail blocks overlap compact HUDs at yaw. Both are fixed by the enemy HUD branch under review in PR #8. Branching from `main` would mean starting from a broken baseline and being unable to tell your own breakage from someone else's.

Merge order is therefore PR #8 first, then this work. If #8 has already merged to `main` by the time you start, branch from `main` instead and expect the baseline below.

Every Godot command in this plan uses an isolated `HOME`. This is mandatory — see [testing guidance](../../testing/README.md). Never run these without it; tests must not touch real save data.

Run the full suite once before starting to establish your baseline:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected from `codex/enemy-hud-contrast-feedback`: 1125 tests, 1124 passing, 18950 asserts. The single failure is `test_directional_shift_keyboard_mode_uses_kenney_textures`, a known pre-existing flake that passes in isolation and fails intermittently in full runs. GUT is not configured for random ordering, so an intermittent failure under deterministic order points at a timing race in `InputManager` mode propagation. It is unrelated to this work.

If anything **else** fails, stop and investigate before starting. Write your actual baseline numbers down — every "expected" count later in this plan is relative to it.

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `src/ui/theme/ui_palette.gd` | `UIPalette` resource class. Colour definitions only, no behavior. |
| `data/theme/ui_palette.tres` | The single palette instance. |
| `src/ui/segment_bar.gd` | `SegmentBar` control. All three bar styles, drawing and fill state. |
| `data/theme/fonts/oxanium.tres` | Oxanium regular variation with tabular figures. |
| `data/theme/fonts/oxanium_italic.tres` | Oxanium italic variation. |
| `data/theme/fonts/oxanium_bold.tres` | Oxanium bold variation, the theme default font. |
| `src/dev/segment_bar_lab.tscn` | Manual verification scene for all four bar configurations. |
| `src/dev/segment_bar_lab.gd` | Slider wiring for the lab scene. |
| `test/unit/test_ui_palette.gd` | Palette completeness. |
| `test/unit/test_segment_bar.gd` | All `SegmentBar` behavior. |
| `test/unit/test_type_scale.gd` | Type variation sizes and the in-engine cap-height floor. |

**Modified:**

| Path | Change |
|---|---|
| `src/ui/theme_bootstrap.gd` | Point at Oxanium; hydrate fonts for the four type variations. |
| `data/theme/default_theme.tres` | Add four `Label` type variations, sizes only. |
| `test/unit/test_theme_bootstrap.gd` | Update font constants and bootstrap-safety assertions. |

**Deleted:** the Archivo and SUSE Mono `.tres` and `.ttf` files, via the merge in Task 1.

---

## Task 1: Bring Oxanium in and rename its resources

The font swap already exists on `feat/oxanium-typeface` but lands its files under misleading names — `archivo.tres` holding Oxanium. This task merges it and fixes the names in one step so no confusing intermediate is ever committed.

**Files:**
- Merge: `feat/oxanium-typeface`
- Rename: `data/theme/fonts/archivo.tres` → `data/theme/fonts/oxanium.tres`
- Rename: `data/theme/fonts/archivo_italic.tres` → `data/theme/fonts/oxanium_italic.tres`
- Rename: `data/theme/fonts/suse_mono_bold.tres` → `data/theme/fonts/oxanium_bold.tres`
- Rename: `data/theme/fonts/suse_mono.tres` → `data/theme/fonts/oxanium_regular.tres`
- Modify: `src/map/terminal.tscn`, `src/map/terminal_protocol_row.tscn`, `src/deadbeef/game_piece.tscn`
- Modify: `src/ui/theme_bootstrap.gd`
- Modify: `test/unit/test_theme_bootstrap.gd`

**`suse_mono.tres` is live — do not delete it.** It is referenced as a per-scene font override by `terminal.tscn`, `terminal_protocol_row.tscn` and `game_piece.tscn`. Deleting it dangles those references and breaks the terminal tests. It becomes `oxanium_regular.tres` instead.

**Watch out for a slip in the font branch.** `feat/oxanium-typeface` repoints `suse_mono.tres` at `union_gothic-variable.ttf`, not at Oxanium. That is not intentional — repoint it to Oxanium as part of Step 5. `archivo_narrow.tres` and `union_gothic.tres`, by contrast, are genuinely unreferenced and the merge deletes them correctly.

- [ ] **Step 1: Merge the font branch**

```bash
git merge --no-ff feat/oxanium-typeface -m "feat: bring in the Oxanium typeface"
```

Expected: a clean merge. `data/theme/fonts/base_fonts/Oxanium-VariableFont_wght.ttf` now exists and the Archivo and SUSE Mono files are gone.

- [ ] **Step 2: Update the bootstrap test first**

This is the failing test for this task. Replace the whole of `test/unit/test_theme_bootstrap.gd`:

```gdscript
extends GutTest

const PROJECT_THEME_PATH := "res://data/theme/default_theme.tres"
const OXANIUM := preload("res://data/theme/fonts/oxanium.tres")
const OXANIUM_ITALIC := preload("res://data/theme/fonts/oxanium_italic.tres")
const OXANIUM_BOLD := preload("res://data/theme/fonts/oxanium_bold.tres")
const OXANIUM_REGULAR := preload("res://data/theme/fonts/oxanium_regular.tres")


func test_project_theme_is_bootstrap_safe_before_imported_fonts_exist() -> void:
	var source := FileAccess.get_file_as_string(PROJECT_THEME_PATH)

	assert_false(source.contains("res://data/theme/fonts/base_fonts/"))
	assert_false(source.contains("res://data/theme/fonts/oxanium.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_italic.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_bold.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_regular.tres"))


func test_runtime_project_theme_hydrates_the_authored_fonts() -> void:
	var project_theme := ThemeDB.get_project_theme()

	assert_not_null(project_theme)
	assert_same(project_theme.default_font, OXANIUM_BOLD)
	assert_same(project_theme.get_font(&"normal_font", &"RichTextLabel"), OXANIUM)
	assert_same(project_theme.get_font(&"italics_font", &"RichTextLabel"), OXANIUM_ITALIC)


# OpenType feature tags are stored (and exposed at runtime) as their 32-bit
# integer form, not as StringNames -- FontVariation.opentype_features always
# keys by tag int, even for resources authored entirely in the editor.
const TNUM_FEATURE_TAG := 1953396077


func test_authored_fonts_use_tabular_figures() -> void:
	for font: FontVariation in [OXANIUM, OXANIUM_ITALIC, OXANIUM_BOLD, OXANIUM_REGULAR]:
		assert_eq(font.opentype_features.get(TNUM_FEATURE_TAG, 0), 1)
```

**Do not key this dictionary by `&"tnum"`.** `FontVariation.opentype_features` is always keyed by the tag's 32-bit integer form at runtime, regardless of how the resource was authored, so a `StringName` lookup silently returns the default and the assertion passes for the wrong reason. Verified in engine.

**Why the bootstrap-safety test matters:** the project theme is loaded before the font resources are guaranteed to be imported, so `default_theme.tres` must never reference a font path. Fonts are attached at runtime by `ThemeBootstrap`. Keep this constraint in mind for Task 3 — type variations may set sizes in the theme file but never fonts.

- [ ] **Step 3: Run the test to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_theme_bootstrap -gexit
```

Expected: a parser error on the `preload` of `oxanium.tres`, because the file does not exist yet. That counts as the failing state for this step.

- [ ] **Step 4: Rename the font resources**

```bash
git mv data/theme/fonts/archivo.tres data/theme/fonts/oxanium.tres
git mv data/theme/fonts/archivo_italic.tres data/theme/fonts/oxanium_italic.tres
git mv data/theme/fonts/suse_mono_bold.tres data/theme/fonts/oxanium_bold.tres
git mv data/theme/fonts/suse_mono.tres data/theme/fonts/oxanium_regular.tres
```

Godot tracks these resources by the `uid` in their headers, not by filename, so renaming does not break references. Leave each `uid` exactly as it is.

- [ ] **Step 5: Set the font variations**

Replace the body of `data/theme/fonts/oxanium.tres`, keeping its existing `uid` and `ext_resource` lines untouched:

```
[resource]
base_font = ExtResource("1_h1fwm")
variation_opentype = {
2003265652: 500
}
opentype_features = {
1953396077: 1
}
```

`2003265652` is the `wght` axis; `1953396077` is the `tnum` feature. Godot stores OpenType tags as their 32-bit integer form in `.tres` files. In GDScript you may write `{"tnum": 1}` and the engine converts.

Apply the same `opentype_features` block to `oxanium_italic.tres`, `oxanium_bold.tres` and `oxanium_regular.tres`. Set `wght` to `500` for `oxanium.tres` and `oxanium_italic.tres`, `700` for `oxanium_bold.tres`, and `400` for `oxanium_regular.tres`. The `ExtResource` id differs per file — use whatever each file already has rather than copying `1_h1fwm`.

`oxanium_regular.tres` needs three extra things because it arrives from the font branch mispointed:

- Repoint its `ext_resource` to `res://data/theme/fonts/base_fonts/Oxanium-VariableFont_wght.ttf`. Confirm that file's `uid` from its own `.import` sidecar rather than assuming one.
- Keep the resource's **own** `uid="uid://c0je4m574ytir"` unchanged, so the three consuming scenes keep resolving it.
- Drop the inherited `liga` feature (`1818847073`). It was not a deliberate choice and Oxanium does not need it.

Then update the three consuming scenes — `src/map/terminal.tscn`, `src/map/terminal_protocol_row.tscn`, `src/deadbeef/game_piece.tscn` — repointing any literal `path="res://data/theme/fonts/suse_mono.tres"` to the new filename. Entries resolving purely by `uid://c0je4m574ytir` need no edit, but check each one; Godot usually writes both.

These scenes lose their monospaced look, which is accepted: tabular figures cover the digit-alignment need that actually mattered.

- [ ] **Step 6: Point the bootstrap at the new names**

In `src/ui/theme_bootstrap.gd`, replace the three path constants and the local variable names:

```gdscript
extends Node

const OXANIUM_PATH := "res://data/theme/fonts/oxanium.tres"
const OXANIUM_ITALIC_PATH := "res://data/theme/fonts/oxanium_italic.tres"
const OXANIUM_BOLD_PATH := "res://data/theme/fonts/oxanium_bold.tres"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not hydrate_project_theme():
		push_error("ThemeBootstrap could not hydrate the project theme fonts.")


func hydrate_project_theme() -> bool:
	var project_theme := ThemeDB.get_project_theme()
	var oxanium := load(OXANIUM_PATH) as Font
	var oxanium_italic := load(OXANIUM_ITALIC_PATH) as Font
	var oxanium_bold := load(OXANIUM_BOLD_PATH) as Font
	if project_theme == null \
		or oxanium == null \
		or oxanium_italic == null \
		or oxanium_bold == null:
		return false
	project_theme.default_font = oxanium_bold
	project_theme.set_font(&"normal_font", &"RichTextLabel", oxanium)
	project_theme.set_font(&"italics_font", &"RichTextLabel", oxanium_italic)
	return true
```

`oxanium_regular.tres` is deliberately **not** loaded here. It is a per-scene override, not a project-theme default, so it stays out of `hydrate_project_theme` and out of the `TYPE_VARIATIONS` list added in Task 3.

- [ ] **Step 7: Find and fix every remaining reference**

```bash
grep -rn "archivo\|suse_mono\|union_gothic" src data test --include="*.gd" --include="*.tscn" --include="*.tres"
```

Expected: hits in battle and hub scene files that reference the old `.tres` paths by `uid`. Because Godot resolves by `uid`, scenes that use `uid://...` need no edit. Any hit showing a literal `res://data/theme/fonts/archivo*.tres` or `suse_mono*.tres` **path** must be repointed to the new filename. Fix each one.

- [ ] **Step 8: Reimport and run the test**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_theme_bootstrap -gexit
```

Expected: 3/3 passing, 13 asserts. Three test functions, four fonts — the tabular-figures test loops over all four.

Then run the tests covering the scenes repointed in Step 5, and report their results separately:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_terminal -gexit
```

Expected: all passing. These exercise the terminal scenes whose font resource just moved, so they are the blast radius of this task.

- [ ] **Step 9: Run the full suite**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: only the known `test_directional_shift_keyboard_mode_uses_kenney_textures` flake. A font rename touches the whole project, so the full suite is the right scope here.

- [ ] **Step 10: Commit**

```bash
git add -A data/theme src/ui/theme_bootstrap.gd test/unit/test_theme_bootstrap.gd
git commit -m "refactor: name the font resources for Oxanium and enable tabular figures"
```

---

## Task 2: UIPalette

**Files:**
- Create: `src/ui/theme/ui_palette.gd`
- Create: `data/theme/ui_palette.tres`
- Test: `test/unit/test_ui_palette.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_ui_palette.gd`:

```gdscript
extends GutTest

const PALETTE_PATH := "res://data/theme/ui_palette.tres"

const REQUIRED_COLORS: Array[StringName] = [
	&"panel", &"panel_hi",
	&"stroke", &"stroke_hi", &"stroke_warm",
	&"ink", &"ink_dim", &"ink_faint", &"ink_hi",
	&"accent",
	&"hp_ok", &"hp_warn", &"hp_crit",
	&"guard", &"threat",
]


func test_palette_resource_defines_every_required_color() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_not_null(palette)
	for property: StringName in REQUIRED_COLORS:
		assert_true(
			palette.get(property) is Color,
			"palette defines %s as a Color" % property,
		)


func test_guard_is_achromatic_so_it_never_competes_with_the_hp_ramp() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_lt(palette.guard.s, 0.10, "guard reads as a neutral steel white")


func test_hp_ramp_starts_achromatic_and_alarms_warm() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_lt(palette.hp_ok.s, 0.30, "a healthy unit is achromatic steel")
	assert_gt(palette.hp_warn.s, 0.50, "warn is unmistakably warm")
	assert_gt(palette.hp_crit.s, 0.50, "crit is unmistakably warm")


func test_hp_ramp_escalates_from_cool_through_amber_to_red() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_between(palette.hp_ok.h, 0.45, 0.75, "ok sits in the cool blues")
	assert_between(palette.hp_warn.h, 0.05, 0.15, "warn sits in the ambers")
	assert_true(
		palette.hp_crit.h <= 0.03 or palette.hp_crit.h >= 0.97,
		"crit sits at red",
	)
```

These assertions encode the design rules rather than literal hex values, so retuning a colour does not break the test but abandoning a rule does.

**The ramp escalates in hue, not saturation.** Measured: `hp_ok` is 210° at 20% saturation, `hp_warn` is 35° at 75%, `hp_crit` is 0° at 71%. Amber is *more* saturated than red — that is how those hues work, not a defect — so any assertion that saturation rises monotonically across the ramp is measuring the wrong thing and will fail against the real palette. `guard` sits at 6% saturation on `hp_ok`'s 210° hue: a deliberate cool white, achromatic to the eye, so the tolerance must accommodate it. Godot's `Color.h` is 0..1, not degrees, and the `hp_crit` check is an or-comparison because red straddles the 0/1 wrap.

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_ui_palette -gexit
```

Expected: a parser error — `UIPalette` is not a known class.

- [ ] **Step 3: Write the palette class**

Create `src/ui/theme/ui_palette.gd`:

```gdscript
@tool
class_name UIPalette
extends Resource

## Every colour battle UI is permitted to use. Nothing in the HUD may
## introduce a colour outside this resource — that rule is what makes the
## HP alarm ramp legible, because it guarantees a hurt unit is the only
## warm thing on screen.

@export_group("Surfaces")
@export var panel := Color("11151c", 0.90)
@export var panel_hi := Color("1d242f", 0.94)

@export_group("Strokes")
@export var stroke := Color("8ca3be", 0.22)
@export var stroke_hi := Color("a0b9d7", 0.44)
## Hostile hairline. Marks rank, never identity.
@export var stroke_warm := Color("c88c78", 0.32)

@export_group("Ink")
@export var ink := Color("cdd8e5")
@export var ink_dim := Color("8493a5")
@export var ink_faint := Color("5a6878")
@export var ink_hi := Color("f0f5fa")

@export_group("Accent")
## Active unit and focus ONLY. Never decoration, never a second meaning.
@export var accent := Color("3fe0ff")

@export_group("HP alarm ramp")
@export var hp_ok := Color("a2b6ca")
@export var hp_warn := Color("f0a63c")
@export var hp_crit := Color("ff4b4b")

@export_group("Other")
## Achromatic on purpose: guard must never compete with the HP ramp.
@export var guard := Color("e8f0f8")
## Lethal forecast only.
@export var threat := Color("e8734a")
```

- [ ] **Step 4: Create the palette instance**

Create `data/theme/ui_palette.tres`:

```
[gd_resource type="Resource" script_class="UIPalette" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/theme/ui_palette.gd" id="1_palette"]

[resource]
script = ExtResource("1_palette")
```

Every colour comes from the script's defaults, so the instance stays minimal and retuning happens in one place.

- [ ] **Step 5: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_ui_palette -gexit
```

Expected: 3/3 passing.

- [ ] **Step 6: Commit**

```bash
git add src/ui/theme/ui_palette.gd data/theme/ui_palette.tres test/unit/test_ui_palette.gd
git commit -m "feat: add the shared UI palette resource"
```

---

## Task 3: Theme type variations

Four `Label` variations so no node ever hardcodes a font size. Sizes are the design's comfort scale carried into 1920-space: `LabelMicro` 27, `LabelLabel` 30, `LabelValue` 33, `LabelSub` 27.

**Files:**
- Modify: `data/theme/default_theme.tres`
- Modify: `src/ui/theme_bootstrap.gd`
- Test: `test/unit/test_type_scale.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_type_scale.gd`:

```gdscript
extends GutTest

const REFERENCE_HEIGHT := 1080.0
const COMPACT_HEIGHT := 800.0
const DECK_CAP_FLOOR := 9.0

const EXPECTED_SIZES := {
	&"LabelMicro": 27,
	&"LabelLabel": 30,
	&"LabelValue": 33,
	&"LabelSub": 27,
}


func test_every_type_variation_declares_its_authored_size() -> void:
	var project_theme := ThemeDB.get_project_theme()

	for variation: StringName in EXPECTED_SIZES:
		assert_true(
			project_theme.has_font_size(&"font_size", variation),
			"%s declares a font size" % variation,
		)
		assert_eq(
			project_theme.get_font_size(&"font_size", variation),
			EXPECTED_SIZES[variation],
			"%s is authored at its comfort size" % variation,
		)


func test_every_type_variation_derives_from_label() -> void:
	var project_theme := ThemeDB.get_project_theme()

	for variation: StringName in EXPECTED_SIZES:
		assert_eq(project_theme.get_type_variation_base(variation), &"Label")


func test_every_type_variation_clears_the_deck_cap_height_floor() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var scale := COMPACT_HEIGHT / REFERENCE_HEIGHT

	for variation: StringName in EXPECTED_SIZES:
		var font := project_theme.get_font(&"font", variation)
		assert_not_null(font, "%s has a hydrated font" % variation)
		if font == null:
			continue
		var authored_size: int = EXPECTED_SIZES[variation]
		var cap_height := font.get_char_size("H".unicode_at(0), authored_size).y
		var rendered_cap := cap_height * scale
		assert_gte(
			rendered_cap,
			DECK_CAP_FLOOR,
			"%s renders %.2fpx caps at 1280x800, floor is %.1f" % [
				variation, rendered_cap, DECK_CAP_FLOOR,
			],
		)
```

**Why `get_char_size` and not `get_height`:** `get_height()` includes ascent and descent, so it overstates glyph height and would let a font slip under Valve's floor while the test passes. The cap height of a capital H is the measurement the requirement is actually about.

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_type_scale -gexit
```

Expected: FAIL — `LabelMicro declares a font size` is false, because no variations exist yet.

- [ ] **Step 3: Add the variations to the theme**

In `data/theme/default_theme.tres`, add these lines to the `[resource]` block. Keep the file alphabetically ordered as Godot writes it, and **add no font paths** — the bootstrap-safety test in Task 1 forbids them:

```
LabelLabel/base_type = &"Label"
LabelLabel/font_sizes/font_size = 30
LabelMicro/base_type = &"Label"
LabelMicro/font_sizes/font_size = 27
LabelSub/base_type = &"Label"
LabelSub/font_sizes/font_size = 27
LabelValue/base_type = &"Label"
LabelValue/font_sizes/font_size = 33
```

- [ ] **Step 4: Hydrate the variation fonts at runtime**

The theme carries sizes; `ThemeBootstrap` attaches the fonts. In `src/ui/theme_bootstrap.gd`, add the constant and extend `hydrate_project_theme`:

```gdscript
const TYPE_VARIATIONS: Array[StringName] = [
	&"LabelMicro", &"LabelLabel", &"LabelValue", &"LabelSub",
]
```

Then, immediately before `return true` in `hydrate_project_theme`:

```gdscript
	for variation: StringName in TYPE_VARIATIONS:
		project_theme.set_font(&"font", variation, oxanium_bold)
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_type_scale -gexit
```

Expected: 3/3 passing.

**If the cap-height test fails**, the type scale is too small for Oxanium's cap ratio and the sizes must go up — not the floor down. Raise each failing token to the next multiple of three and re-run. Record the change, because the design's table then needs updating.

- [ ] **Step 6: Verify the theme stayed bootstrap-safe**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_theme_bootstrap -gexit
```

Expected: 3/3 passing. If `test_project_theme_is_bootstrap_safe_before_imported_fonts_exist` fails, a font path was written into the theme file — remove it and hydrate it in `ThemeBootstrap` instead.

- [ ] **Step 7: Commit**

```bash
git add data/theme/default_theme.tres src/ui/theme_bootstrap.gd test/unit/test_type_scale.gd
git commit -m "feat: add combat HUD type variations at the comfort scale"
```

---

## Task 4: SegmentBar skeleton and PIPS style

The HP style: ten skewed cells, fill growing bottom-up, the leading cell showing the fraction.

**Files:**
- Create: `src/ui/segment_bar.gd`
- Test: `test/unit/test_segment_bar.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_segment_bar.gd`:

```gdscript
extends GutTest


func test_pips_minimum_size_covers_every_cell_its_gaps_and_the_skew() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.cell_size = Vector2(21, 36)
	bar.cell_gap = 4.5
	bar.skew_px = 6.45

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 21.0 + 9.0 * 4.5 + 6.45, 0.01)
	assert_almost_eq(minimum.y, 36.0, 0.01)


func test_pips_report_full_partial_and_empty_cell_counts() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 655.0

	assert_eq(bar.get_full_cell_count(), 6)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.55, 0.001)


func test_pips_at_full_value_have_no_partial_cell() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 1000.0

	assert_eq(bar.get_full_cell_count(), 10)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func test_pips_at_zero_are_entirely_empty() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 0.0

	assert_eq(bar.get_full_cell_count(), 0)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func test_value_above_max_clamps_rather_than_overfilling() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 4000.0

	assert_eq(bar.get_full_cell_count(), 10)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func _bar() -> SegmentBar:
	var bar := SegmentBar.new()
	add_child_autofree(bar)
	return bar
```

**Why these accessors exist:** `_draw()` output cannot be asserted against, so the fill arithmetic is exposed through `get_full_cell_count()` and `get_partial_cell_fill()` and tested directly. Drawing then consumes the same two functions, so a passing test means the picture is right too.

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: a parser error — `SegmentBar` is not a known class.

- [ ] **Step 3: Write the skeleton and PIPS drawing**

Create `src/ui/segment_bar.gd`:

```gdscript
@tool
class_name SegmentBar
extends Control

## Draws every discrete bar in the combat HUD: HP pips, the guard gauge,
## the focus tally and ability cost. Pure polygon drawing — no textures,
## no nine-patches, no shaders — so cell count, size, gap, skew and colour
## stay live-editable and nothing needs re-exporting from an art tool.

enum Style {
	PIPS,    ## N skewed cells, fill grows bottom-up, leading cell shows the fraction.
	WRAPPED, ## max_value cells at constant size, wrapped per_row per line.
	TALLY,   ## N cells grouped every group_every, read as tally marks.
}

enum FillState { OK, WARN, CRIT }

signal state_changed(state: FillState)

@export var style: Style = Style.PIPS:
	set(v):
		style = v
		queue_redraw()
		update_minimum_size()

@export var value: float = 100.0:
	set(v):
		value = v
		_refresh_state()
		queue_redraw()

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.001)
		_refresh_state()
		queue_redraw()

@export_group("Layout")
@export var cells: int = 10:
	set(v):
		cells = maxi(v, 1)
		queue_redraw()
		update_minimum_size()

@export var cell_size := Vector2(21, 36):
	set(v):
		cell_size = v
		queue_redraw()
		update_minimum_size()

@export var cell_gap: float = 4.5:
	set(v):
		cell_gap = v
		queue_redraw()
		update_minimum_size()

## Horizontal shear across the full cell height, in pixels. 0 for square cells.
@export var skew_px: float = 6.45:
	set(v):
		skew_px = v
		queue_redraw()
		update_minimum_size()

@export_group("Colour")
@export var use_alarm_states: bool = true:
	set(v):
		use_alarm_states = v
		_refresh_state()
		queue_redraw()

@export var color_ok := Color("a2b6ca")
@export var color_warn := Color("f0a63c")
@export var color_crit := Color("ff4b4b")
@export var flat_color := Color("e8f0f8")

@export_range(0.0, 1.0) var warn_below: float = 0.50
@export_range(0.0, 1.0) var crit_below: float = 0.25

@export var track_fill := Color(1, 1, 1, 0.055)
@export var track_line := Color(1, 1, 1, 0.11)
## Bright edge on the partially drained cell. Alpha 0 disables it.
@export var waterline := Color("f0f5fa", 0.9)
@export var waterline_px: float = 3.0

var _state: FillState = FillState.OK


func _ready() -> void:
	_refresh_state()


func get_ratio() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


func get_full_cell_count() -> int:
	return floori(get_ratio() * float(cells))


func get_partial_cell_fill() -> float:
	var exact := get_ratio() * float(cells)
	return exact - float(floori(exact))


func _refresh_state() -> void:
	var previous := _state
	if not use_alarm_states:
		_state = FillState.OK
	else:
		var ratio := get_ratio()
		if ratio <= crit_below:
			_state = FillState.CRIT
		elif ratio <= warn_below:
			_state = FillState.WARN
		else:
			_state = FillState.OK
	if _state != previous:
		state_changed.emit(_state)


func get_fill_state() -> FillState:
	return _state


func _fill_color() -> Color:
	if not use_alarm_states:
		return flat_color
	match _state:
		FillState.CRIT:
			return color_crit
		FillState.WARN:
			return color_warn
		_:
			return color_ok


func _get_minimum_size() -> Vector2:
	var width := cells * cell_size.x + maxf(cells - 1, 0) * cell_gap
	return Vector2(width + absf(skew_px), cell_size.y)


## Builds a sheared quad. y0 and y1 are measured from the top of the cell,
## so a partial fill is a quad from h * (1 - fill) down to h.
func _quad(x: float, y0: float, y1: float, w: float) -> PackedVector2Array:
	var h := cell_size.y
	var o0 := skew_px * (0.5 - y0 / h)
	var o1 := skew_px * (0.5 - y1 / h)
	return PackedVector2Array([
		Vector2(x + o0, y0),
		Vector2(x + o0 + w, y0),
		Vector2(x + o1 + w, y1),
		Vector2(x + o1, y1),
	])


func _stroke(quad: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	var loop := quad.duplicate()
	loop.append(quad[0])
	draw_polyline(loop, col, width, false)


func _draw() -> void:
	_draw_cells(maxf(skew_px, 0.0) * 0.5)


func _draw_cells(pad: float) -> void:
	var h := cell_size.y
	var w := cell_size.x
	var col := _fill_color()
	var full := get_full_cell_count()
	var frac := get_partial_cell_fill()
	var x := pad

	for i in cells:
		var fill := 0.0
		var partial := false
		if i < full:
			fill = 1.0
		elif i == full and frac > 0.001:
			fill = frac
			partial = true

		var track := _quad(x, 0.0, h, w)
		if track_fill.a > 0.0:
			draw_colored_polygon(track, track_fill)
		if track_line.a > 0.0:
			_stroke(track, track_line)

		if fill > 0.0:
			var top := h * (1.0 - fill)
			draw_colored_polygon(_quad(x, top, h, w), col)
			if partial and waterline.a > 0.0:
				var edge := _quad(x, top, minf(top + waterline_px, h), w)
				draw_colored_polygon(edge, waterline)

		x += w + cell_gap
```

`draw_polyline` is called with antialiasing off. At Deck density the skewed edges alias cleanly, and antialiasing makes single-pixel strokes fuzzy.

- [ ] **Step 4: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: 5/5 passing.

- [ ] **Step 5: Commit**

```bash
git add src/ui/segment_bar.gd test/unit/test_segment_bar.gd
git commit -m "feat: add SegmentBar with the HP pip style"
```

---

## Task 5: WRAPPED style for the guard gauge

Guard drops one per shredding hit, so one cell must equal one hit at a constant size on every unit. The gauge wraps rather than stretching, which makes row count the ceiling — one row is ten, three rows is thirty.

**Files:**
- Modify: `src/ui/segment_bar.gd`
- Test: `test/unit/test_segment_bar.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_segment_bar.gd`:

```gdscript
func test_wrapped_gauge_is_one_row_at_a_cap_of_ten() -> void:
	var bar := _guard_bar(10.0)

	assert_eq(bar.get_row_count(), 1)


func test_wrapped_gauge_is_three_rows_at_a_cap_of_thirty() -> void:
	var bar := _guard_bar(30.0)

	assert_eq(bar.get_row_count(), 3)


func test_wrapped_gauge_width_is_identical_at_every_cap() -> void:
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)

	assert_almost_eq(
		narrow.get_minimum_size().x,
		wide.get_minimum_size().x,
		0.01,
		"a ten-guard unit and a thirty-guard unit occupy the same width",
	)


func test_wrapped_gauge_grows_only_in_height_with_its_cap() -> void:
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)

	assert_lt(narrow.get_minimum_size().y, wide.get_minimum_size().y)


func test_wrapped_gauge_cell_size_never_rescales_to_fit_a_bigger_cap() -> void:
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)

	assert_eq(narrow.cell_size, wide.cell_size)


func test_wrapped_gauge_partial_cap_still_reserves_a_whole_row() -> void:
	var bar := _guard_bar(12.0)

	assert_eq(bar.get_row_count(), 2)


func _guard_bar(cap: float) -> SegmentBar:
	var bar := _bar()
	bar.style = SegmentBar.Style.WRAPPED
	bar.per_row = 10
	bar.cell_size = Vector2(12, 9)
	bar.cell_gap = 3.0
	bar.row_gap = 3.0
	bar.skew_px = 3.0
	bar.use_alarm_states = false
	bar.max_value = cap
	bar.value = cap
	return bar
```

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: FAIL — `per_row` and `get_row_count` do not exist.

- [ ] **Step 3: Add the wrapped layout properties**

In `src/ui/segment_bar.gd`, add to the Layout group after `skew_px`:

```gdscript
## WRAPPED only. One cell equals one hit at a CONSTANT size — never rescale
## cells to fit a bigger ceiling. The gauge wraps instead: max_value cells
## laid out per_row at a time. Row count then IS the cap, so nothing can
## overfill a bar whose ceiling you cannot see, and the widget's width is
## identical for every unit.
@export var per_row: int = 10:
	set(v):
		per_row = maxi(v, 1)
		queue_redraw()
		update_minimum_size()

@export var row_gap: float = 3.0:
	set(v):
		row_gap = v
		queue_redraw()
		update_minimum_size()
```

- [ ] **Step 4: Add row counting and wrapped sizing**

Add this accessor next to `get_full_cell_count`:

```gdscript
func get_row_count() -> int:
	if style != Style.WRAPPED:
		return 1
	var count := maxi(int(round(max_value)), 1)
	return ceili(float(count) / float(per_row))
```

Replace `_get_minimum_size` entirely:

```gdscript
func _get_minimum_size() -> Vector2:
	if style == Style.WRAPPED:
		var columns := mini(maxi(int(round(max_value)), 1), per_row)
		var rows := get_row_count()
		var wrapped_width := columns * cell_size.x + maxf(columns - 1, 0) * cell_gap
		var wrapped_height := rows * cell_size.y + maxf(rows - 1, 0) * row_gap
		return Vector2(wrapped_width + absf(skew_px), wrapped_height)
	var width := cells * cell_size.x + maxf(cells - 1, 0) * cell_gap
	return Vector2(width + absf(skew_px), cell_size.y)
```

**Note the width rule:** columns are capped at `per_row`, so a cap of 10 and a cap of 30 both produce ten columns and therefore identical width. That is the property `test_wrapped_gauge_width_is_identical_at_every_cap` protects, and it is what lets five enemy plates keep a uniform footprint.

- [ ] **Step 5: Add wrapped drawing**

Replace `_draw`:

```gdscript
func _draw() -> void:
	var pad := maxf(skew_px, 0.0) * 0.5
	if style == Style.WRAPPED:
		_draw_wrapped(pad)
	else:
		_draw_cells(pad)
```

Then add:

```gdscript
## One cell per point of MAX guard, constant size, wrapped per_row per line.
## Cells fill from the first row forward, so they empty from the last row
## backwards — like rounds coming off the top of a magazine.
func _draw_wrapped(pad: float) -> void:
	var count := maxi(int(round(max_value)), 0)
	if count == 0:
		return
	var filled := clampi(int(round(value)), 0, count)
	var w := cell_size.x
	var h := cell_size.y
	var col := _fill_color()

	for i in count:
		var row := i / per_row
		var column := i % per_row
		var x := pad + column * (w + cell_gap)
		var y := row * (h + row_gap)
		var quad := _quad(x, 0.0, h, w)
		for k in quad.size():
			quad[k] = quad[k] + Vector2(0.0, y)
		draw_colored_polygon(quad, col if i < filled else track_fill)
```

`_quad` works in cell-local space, so the row offset is applied afterwards.

- [ ] **Step 6: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: 11/11 passing.

- [ ] **Step 7: Commit**

```bash
git add src/ui/segment_bar.gd test/unit/test_segment_bar.gd
git commit -m "feat: add the wrapped guard gauge style to SegmentBar"
```

---

## Task 6: TALLY style for focus and ability cost

**Files:**
- Modify: `src/ui/segment_bar.gd`
- Test: `test/unit/test_segment_bar.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_segment_bar.gd`:

```gdscript
func test_tally_inserts_a_group_gap_every_group_every_cells() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 10
	bar.cell_size = Vector2(9, 24)
	bar.cell_gap = 3.0
	bar.group_every = 5
	bar.group_gap = 10.5
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 9.0 + 9.0 * 3.0 + 10.5, 0.01)


func test_tally_without_grouping_has_no_extra_width() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 10
	bar.cell_size = Vector2(9, 24)
	bar.cell_gap = 3.0
	bar.group_every = 0
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 9.0 + 9.0 * 3.0, 0.01)


func test_ability_cost_sizes_itself_to_the_cost() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 3
	bar.cell_size = Vector2(9, 21)
	bar.cell_gap = 3.0
	bar.group_every = 5
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 3.0 * 9.0 + 2.0 * 3.0, 0.01)
```

A ten-cell tally grouped every five gets exactly one gap, not two — the gap falls between cells 5 and 6, and no gap is added before the first cell or after the last.

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: FAIL — `group_every` does not exist.

- [ ] **Step 3: Add the grouping properties**

In the Layout group, after `skew_px`:

```gdscript
## TALLY only. Insert group_gap every N cells so the eye subitises in fives
## instead of counting. 0 disables grouping.
@export var group_every: int = 0:
	set(v):
		group_every = maxi(v, 0)
		queue_redraw()
		update_minimum_size()

@export var group_gap: float = 10.5:
	set(v):
		group_gap = v
		queue_redraw()
		update_minimum_size()
```

- [ ] **Step 4: Include grouping in sizing and drawing**

In `_get_minimum_size`, replace the final two lines of the non-wrapped path:

```gdscript
	var width := cells * cell_size.x + maxf(cells - 1, 0) * cell_gap
	if style == Style.TALLY and group_every > 0:
		width += group_gap * floorf(float(cells - 1) / float(group_every))
	return Vector2(width + absf(skew_px), cell_size.y)
```

In `_draw_cells`, add this as the first statement inside the `for i in cells:` loop:

```gdscript
		if style == Style.TALLY and group_every > 0 and i > 0 and i % group_every == 0:
			x += group_gap
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: 14/14 passing.

- [ ] **Step 6: Commit**

```bash
git add src/ui/segment_bar.gd test/unit/test_segment_bar.gd
git commit -m "feat: add the grouped tally style to SegmentBar"
```

---

## Task 7: Alarm states, the critical pulse, and safe animation

This task fixes the three defects in the supplied script: a tween that does not replace its predecessor, `set_process` that only reacts in `_ready`, and unguarded editor-time animation.

**Files:**
- Modify: `src/ui/segment_bar.gd`
- Test: `test/unit/test_segment_bar.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_segment_bar.gd`:

```gdscript
func test_alarm_state_escalates_as_the_ratio_falls() -> void:
	var bar := _bar()
	bar.max_value = 100.0

	bar.value = 80.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)
	bar.value = 40.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.WARN)
	bar.value = 10.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.CRIT)


func test_state_changed_fires_only_on_a_real_transition() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0
	watch_signals(bar)

	bar.value = 90.0
	assert_signal_not_emitted(bar, "state_changed")

	bar.value = 40.0
	assert_signal_emitted(bar, "state_changed")


func test_a_gauge_without_alarm_states_stays_ok_at_any_value() -> void:
	var bar := _bar()
	bar.use_alarm_states = false
	bar.max_value = 100.0

	bar.value = 1.0

	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)


func test_tween_to_replaces_its_predecessor_instead_of_racing_it() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0

	bar.tween_to(60.0, 0.2)
	var first := bar.get_active_tween()
	bar.tween_to(20.0, 0.2)
	var second := bar.get_active_tween()

	assert_not_null(second)
	assert_false(first.is_valid(), "the superseded tween is killed, not left running")
	assert_true(second.is_valid())


func test_tween_to_reaches_its_target_value() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0

	bar.tween_to(40.0, 0.05)
	await wait_seconds(0.15)

	assert_almost_eq(bar.value, 40.0, 0.001)


func test_pulse_processing_follows_the_pulse_setting() -> void:
	var bar := _bar()
	bar.pulse_when_critical = false

	assert_false(bar.is_processing())

	bar.pulse_when_critical = true

	assert_true(bar.is_processing())
```

**Why the tween test matters:** repeated damage in quick succession calls `tween_to` again before the first animation finishes. Without killing the predecessor both tweens write `value` every frame and the bar visibly stutters between two targets.

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: FAIL — `tween_to`, `get_active_tween` and `pulse_when_critical` do not exist.

- [ ] **Step 3: Add the pulse group and tween state**

After the Colour group in `src/ui/segment_bar.gd`:

```gdscript
@export_group("Critical pulse")
@export var pulse_when_critical: bool = true:
	set(v):
		pulse_when_critical = v
		_refresh_processing()
@export var pulse_hz: float = 0.66
@export_range(0.0, 1.0) var pulse_depth: float = 0.35
```

And beside `var _state`:

```gdscript
var _phase: float = 0.0
var _tween: Tween
```

- [ ] **Step 4: Drive processing from the setting, not from `_ready` alone**

Replace `_ready` and add the helper:

```gdscript
func _ready() -> void:
	_refresh_state()
	_refresh_processing()


func _refresh_processing() -> void:
	if not is_inside_tree():
		set_process(pulse_when_critical)
		return
	set_process(pulse_when_critical and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if _state != FillState.CRIT or not pulse_when_critical:
		return
	_phase = fmod(_phase + delta * pulse_hz * TAU, TAU)
	queue_redraw()
```

The `Engine.is_editor_hint()` guard stops a `@tool` script animating in the editor while still letting the property drive processing at runtime.

- [ ] **Step 5: Reset the phase when leaving critical**

In `_refresh_state`, replace the transition block at the end:

```gdscript
	if _state != previous:
		if _state != FillState.CRIT:
			_phase = 0.0
		state_changed.emit(_state)
```

- [ ] **Step 6: Breathe brightness on the critical fill**

Replace the `FillState.CRIT` arm of `_fill_color` so the whole function reads:

```gdscript
func _fill_color() -> Color:
	if not use_alarm_states:
		return flat_color
	var col: Color
	match _state:
		FillState.CRIT:
			col = color_crit
		FillState.WARN:
			col = color_warn
		_:
			col = color_ok
	if _state == FillState.CRIT and pulse_when_critical:
		# Breathe brightness rather than alpha, so the bar stays legible.
		col = col.lightened(pulse_depth * 0.5 * (0.5 + 0.5 * sin(_phase)))
	return col
```

- [ ] **Step 7: Add the public animation helpers**

At the end of the file:

```gdscript
## Drive this from the combat model. Returns the resulting state so callers
## can trigger audio or haptics on the OK -> WARN -> CRIT transitions.
func set_values(new_value: float, new_max: float = -1.0) -> FillState:
	if new_max > 0.0:
		max_value = new_max
	value = new_value
	return _state


## Animate a change instead of snapping. Replaces any tween already running,
## so rapid repeated damage does not animate two targets at once.
func tween_to(new_value: float, duration: float = 0.26) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "value", new_value, duration)


func get_active_tween() -> Tween:
	return _tween
```

- [ ] **Step 8: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: 20/20 passing.

- [ ] **Step 9: Commit**

```bash
git add src/ui/segment_bar.gd test/unit/test_segment_bar.gd
git commit -m "feat: add alarm states and safe animation to SegmentBar"
```

---

## Task 8: Wire SegmentBar to the palette

The bar currently carries its own colour defaults. This makes the palette authoritative so retuning happens in exactly one place.

**Files:**
- Modify: `src/ui/segment_bar.gd`
- Test: `test/unit/test_segment_bar.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_segment_bar.gd`:

```gdscript
const PALETTE := preload("res://data/theme/ui_palette.tres")


func test_assigning_a_palette_adopts_its_alarm_ramp() -> void:
	var bar := _bar()

	bar.palette = PALETTE

	assert_eq(bar.color_ok, PALETTE.hp_ok)
	assert_eq(bar.color_warn, PALETTE.hp_warn)
	assert_eq(bar.color_crit, PALETTE.hp_crit)


func test_assigning_a_palette_adopts_its_achromatic_guard_as_the_flat_colour() -> void:
	var bar := _bar()

	bar.palette = PALETTE

	assert_eq(bar.flat_color, PALETTE.guard)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: FAIL — `palette` does not exist.

- [ ] **Step 3: Add the palette property**

At the top of the Colour group, before `use_alarm_states`:

```gdscript
## Assigning a palette overwrites this bar's colours from it. Leave null to
## tune a bar by hand — useful in the lab scene, not in shipped UI.
@export var palette: UIPalette:
	set(v):
		palette = v
		if palette != null:
			color_ok = palette.hp_ok
			color_warn = palette.hp_warn
			color_crit = palette.hp_crit
			flat_color = palette.guard
		queue_redraw()
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test_segment_bar -gexit
```

Expected: 22/22 passing.

- [ ] **Step 5: Commit**

```bash
git add src/ui/segment_bar.gd test/unit/test_segment_bar.gd
git commit -m "feat: drive SegmentBar colours from the shared palette"
```

---

## Task 9: The lab scene for manual verification

Automated tests cover the arithmetic. They cannot tell you whether the bars *look* right, which is the whole point of the widget. This scene is how a human checks.

**Files:**
- Create: `src/dev/segment_bar_lab.gd`
- Create: `src/dev/segment_bar_lab.tscn`

- [ ] **Step 1: Write the lab script**

Create `src/dev/segment_bar_lab.gd`:

```gdscript
extends Control

## Manual verification for SegmentBar. Not shipped, not covered by tests —
## its whole job is to let a human look at the four real configurations
## while dragging their values.

@onready var hp: SegmentBar = %HeroHP
@onready var guard_small: SegmentBar = %GuardTen
@onready var guard_large: SegmentBar = %GuardThirty
@onready var focus: SegmentBar = %Focus
@onready var readout: Label = %Readout


func _ready() -> void:
	%HPSlider.value_changed.connect(_on_hp_changed)
	%GuardSlider.value_changed.connect(_on_guard_changed)
	%FocusSlider.value_changed.connect(_on_focus_changed)
	_on_hp_changed(%HPSlider.value)


func _on_hp_changed(v: float) -> void:
	hp.tween_to(v)
	_refresh_readout()


func _on_guard_changed(v: float) -> void:
	guard_small.value = minf(v, guard_small.max_value)
	guard_large.value = v
	_refresh_readout()


func _on_focus_changed(v: float) -> void:
	focus.value = v
	_refresh_readout()


func _refresh_readout() -> void:
	readout.text = "HP %d/%d  ·  state %s  ·  guard rows %d / %d" % [
		int(hp.value),
		int(hp.max_value),
		SegmentBar.FillState.keys()[hp.get_fill_state()],
		guard_small.get_row_count(),
		guard_large.get_row_count(),
	]
```

- [ ] **Step 2: Build the scene**

Create `src/dev/segment_bar_lab.tscn` in the Godot editor with this tree. Every `SegmentBar` gets `palette` set to `res://data/theme/ui_palette.tres`, and every `Label` uses a type variation rather than a hardcoded size.

```
SegmentBarLab (Control, anchors full rect, script segment_bar_lab.gd)
└── VBoxContainer (anchors full rect, 24px separation, 48px margins)
    ├── Readout (Label, unique name, theme_type_variation = LabelValue)
    ├── HeroHP (SegmentBar, unique name)
    │     style = PIPS, cells = 10, cell_size = (21, 36)
    │     cell_gap = 4.5, skew_px = 6.45
    │     max_value = 2700, value = 2700, use_alarm_states = true
    ├── HPSlider (HSlider, unique name, min 0, max 2700, value 2700)
    ├── GuardTen (SegmentBar, unique name)
    │     style = WRAPPED, per_row = 10, cell_size = (12, 9)
    │     cell_gap = 3, row_gap = 3, skew_px = 3
    │     max_value = 10, value = 10, use_alarm_states = false
    ├── GuardThirty (SegmentBar, unique name)
    │     same as GuardTen but max_value = 30, value = 30
    ├── GuardSlider (HSlider, unique name, min 0, max 30, value 30)
    ├── Focus (SegmentBar, unique name)
    │     style = TALLY, cells = 10, group_every = 5, group_gap = 10.5
    │     cell_size = (9, 24), cell_gap = 3, skew_px = 0
    │     max_value = 10, value = 7, use_alarm_states = false
    └── FocusSlider (HSlider, unique name, min 0, max 10, value 7)
```

- [ ] **Step 3: Run the lab and check it by eye**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --path /Users/adam/github/mars res://src/dev/segment_bar_lab.tscn
```

Confirm each of these, which are the properties the design turns on:

- Dragging HP down fills the leading pip **bottom-up**, not left-to-right within the cell.
- The HP ramp goes steel → amber below half → red below a quarter, and the red pulses.
- `GuardTen` and `GuardThirty` have **identical widths** and **identical cell sizes**; only height differs.
- `GuardThirty` shows three rows, `GuardTen` shows one.
- Focus reads as seven at a glance because of the gap after five, without counting.
- Guard at zero is still visible, dimmed, rather than disappearing.

- [ ] **Step 4: Commit**

```bash
git add src/dev/segment_bar_lab.gd src/dev/segment_bar_lab.tscn
git commit -m "feat: add a SegmentBar lab scene for manual verification"
```

---

## Task 10: Full verification and handoff

**Files:** none modified.

- [ ] **Step 1: Reimport and run the complete suite**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: every test passing except the known `test_directional_shift_keyboard_mode_uses_kenney_textures` flake. Record the exact test and assertion totals with the commit SHA — this is required by the testing guidance, not optional.

A font change reaches every screen in the game, so the complete suite is the right scope regardless of how contained the widget work feels.

- [ ] **Step 2: Check the game still runs in Oxanium**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --path /Users/adam/github/mars
```

Walk into a battle. Nothing should have moved. Text should be Oxanium everywhere, and numbers should not shift horizontally as HP ticks — that is the tabular-figures change doing its job. If digits still jitter, `tnum` did not apply; check the `opentype_features` block in the font resources.

- [ ] **Step 3: Confirm no node hardcodes a font size in the scenes this touched**

```bash
grep -rn "theme_override_font_sizes" src/battle/*.tscn | head -40
```

Expected: many hits. These are **not** failures in this plan — they belong to the screen work in the next plan, which replaces them with type variations. Record the count so the next plan can verify it reaches zero.

- [ ] **Step 4: Open the pull request**

Base the PR on whatever this branch was cut from. If PR #8 has not merged yet, target it so the diff stays clean:

```bash
git push -u origin feat/combat-hud-primitives
gh pr create --base codex/enemy-hud-contrast-feedback --title "Combat HUD primitives: palette, type scale, SegmentBar" --body "Implements the primitives half of the combat HUD redesign design. No existing scene changes appearance beyond the typeface.

Stacked on #8 — review that first. Retarget to main once it merges."
```

---

## Definition of done

- Oxanium ships with tabular figures, and no resource filename names a font it does not contain.
- `UIPalette` exists and `SegmentBar` reads its colours from it.
- Four type variations exist, and every one clears the nine-pixel cap-height floor **measured in engine**, not assumed from a table.
- `SegmentBar` draws all three styles, and the guard gauge provably keeps constant cell size and constant width across every cap.
- The full suite passes but for the pre-existing flake.
- The lab scene has been looked at by a human and the six checks in Task 9 hold.
- Battle looks exactly as it did before, in a new typeface.

## What this plan deliberately does not do

No existing battle scene node moves. No role colour is removed. No enemy plate changes state. No target outline is repalettised. No icon is redrawn — including `winged-sword.png`, which the design identifies as a live legibility defect in the unlabelled turn-order slot, and which needs art rather than code.

All of that belongs to the screen composition plan, which should be written only after this lands and the widgets have been seen working. Two items in it need art lead time and are worth starting early in parallel: the purpose-drawn condition icon set, and simplified redraws for unlabelled slots. The design calls the condition set the largest art cost in the whole redesign.
