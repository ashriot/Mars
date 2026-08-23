# Enemy HUD Active Shield and Facing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make enemy intent text reliable and spacious, make the exact guard value readable in a raised active shield, and turn ordinary enemies toward the party without changing formation positions.

**Architecture:** Keep the 220-pixel compact HP footprint, but expose wider visual bounds for the overhanging intent and active shield so the existing HUD resolver can protect them. Keep markup ownership in `EnemyIntentFormatter`, guard geometry in `EnemyGuardStack`, and deterministic yaw in `BattleFormationLayout`.

**Tech Stack:** Godot 4.7.1, GDScript, Godot scenes/resources, GUT 9.6.1.

## Global Constraints

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`.
- Preserve the 220-pixel HP width and the existing 24-pixel intent and 20-pixel guard-value readability floors.
- Preserve the ten-column guard count language, one-pixel ordinary-pip gaps, downward five-pixel layer step, layer colors, 30-guard cap, `VULNERABLE`, and `BREACHED` behavior.
- Preserve all W/M formation positions, the five-ordinary-enemy limit, targeting behavior, HP behavior, and combat rules.
- Do not introduce a condensed font or icon-only intent vocabulary in this pass.
- Do not modify the user-dirty `src/battle/presentation/enemy_drone_presentation.gd` or unrelated scene, font, data, and test edits.
- Use the isolated `HOME=/tmp/mars-godot-home` for every automated Godot run.

---

## File Map

- `src/battle/presentation/enemy_intent_formatter.gd` — emits balanced intent BBCode.
- `src/battle/presentation/enemy_world_hud.tscn` — authors a 220-pixel intent slot containing a wider centered intent label.
- `src/battle/presentation/enemy_world_hud.gd` — exposes full visual reservation bounds for intent and guard overhang.
- `src/battle/presentation/battle_world_3d.gd` — resolves reservations while preserving the compact HUD's offset within each reservation.
- `src/battle/presentation/enemy_guard_stack.tscn` — authors the active-shield shadow and the larger value-label bounds.
- `src/battle/presentation/enemy_guard_stack.gd` — promotes only the current pip and reports its visual bounds.
- `src/battle/presentation/battle_formation_layout.gd` — computes fixed party-facing yaw without changing origins.
- `test/unit/test_enemy_intent_formatter.gd` — protects balanced target-color markup.
- `test/unit/test_enemy_world_hud.gd` — protects intent geometry, parsing, reservations, and compact placement.
- `test/unit/test_enemy_guard_stack.gd` — protects active shield geometry, overlap, shadow, value containment, and unchanged ordinary layers.
- `test/unit/test_battle_formation_layout.gd` — protects unchanged origins and inward yaw.
- `test/integration/test_enemy_hud_formation_projection.gd` — protects five-enemy overhang containment and nonintersection across camera yaw.

---

### Task 1: Balanced intent markup and selective overhang

**Files:**
- Modify: `src/battle/presentation/enemy_intent_formatter.gd:70-95`
- Modify: `src/battle/presentation/enemy_world_hud.tscn:108-138`
- Modify: `src/battle/presentation/enemy_world_hud.gd:1-15, 196-205, 492-494`
- Modify: `src/battle/presentation/battle_world_3d.gd:31-72`
- Test: `test/unit/test_enemy_intent_formatter.gd`
- Test: `test/unit/test_enemy_world_hud.gd`
- Test: `test/integration/test_enemy_hud_formation_projection.gd`

**Interfaces:**
- Consumes: `EnemyIntentFormatter.format(enemy, manager) -> Dictionary`, `EnemyWorldHUD.get_reserved_layout_rect(compact_rect: Rect2) -> Rect2`.
- Produces: `EnemyWorldHUD.INTENT_WIDTH := 286.0`, `%IntentSlot`, and a reservation rectangle that includes the centered intent overhang while preserving the compact stack's 220-pixel width.

- [ ] **Step 1: Write the failing formatter regression**

Change the single-target expectation and assert that both color and alignment markup parse without leaking tags:

```gdscript
assert_eq(
	result.text,
	"25x2 %s [color=ffffffff]ASHE[/color]" % KINETIC_ICON_28,
)
var label := RichTextLabel.new()
add_child_autofree(label)
label.bbcode_enabled = true
label.text = "[center]%s[/center]" % result.text
var parsed := label.get_parsed_text()
assert_true(parsed.ends_with("ASHE"))
assert_false(parsed.contains("[/center]"))
assert_false(parsed.contains("[/color]"))
```

- [ ] **Step 2: Write failing HUD geometry and layout regressions**

Update `test_compact_stack_authors_layered_hp_and_overlapping_guard()` and add a representative long-intent test:

```gdscript
const INTENT_WIDTH := 286.0

assert_eq(hud.compact_stack.size.x, COMPACT_WIDTH)
assert_eq(hud.intent_row.size.x, INTENT_WIDTH)
assert_eq(hud.intent_row.position.x, -(INTENT_WIDTH - COMPACT_WIDTH) * 0.5)
assert_eq(hud.intent_row.autowrap_mode, TextServer.AUTOWRAP_OFF)

func test_representative_long_intent_stays_on_one_line_and_is_reserved() -> void:
	var hud := _hud()
	hud.intent_row.text = "[center]Fortify Attack Drone[/center]"
	await get_tree().process_frame
	var compact_rect := Rect2(Vector2(400, 300), hud._get_compact_size())
	var reserved := hud.get_reserved_layout_rect(compact_rect)
	assert_eq(hud.intent_row.get_line_count(), 1)
	assert_eq(reserved.get_center().x, compact_rect.get_center().x)
	assert_gte(reserved.size.x, INTENT_WIDTH)
```

In the close-HUD resolver test, assert that resolved compact centers remain attached to their projected head columns even though the reservation begins 33 pixels earlier. Extend the formation projection test to collect `get_reserved_layout_rect(compact_rect)` and assert those reserved rectangles, rather than only the 220-pixel compact rectangles, stay within the safe rect and do not intersect.

Also add native Steam Deck size to the integration matrix:

```gdscript
const CANVAS_SIZES: Array[Vector2i] = [
	Vector2i(1280, 800),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
]
```

- [ ] **Step 3: Run the focused tests to verify failure**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_intent_formatter -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: formatter fails on missing `[/color]`; HUD tests fail because the intent is still 220 pixels and reservation offsets are not preserved.

- [ ] **Step 4: Balance target markup**

Close the target color span at its source:

```gdscript
final_text += " [color=%s]%s[/color]" % [color, target.actor_name]
```

- [ ] **Step 5: Author the centered overhang without widening CompactStack**

Replace `IntentRow` as a direct container child with a fixed-width slot and a free-layout child:

```text
CompactStack (220 wide)
└── IntentSlot (Control, 220 x 36)
    └── IntentRow (RichTextLabel, x = -33, width = 286, height = 36)
```

Keep the existing font, 24-pixel size, six-pixel black outline, tooltip child, and input connections. Set `autowrap_mode = TextServer.AUTOWRAP_OFF`; do not reduce type size.

- [ ] **Step 6: Reserve visual overhang and preserve compact offsets**

Add `const INTENT_WIDTH := 286.0` and merge the centered intent lane in `get_reserved_layout_rect()`:

```gdscript
func _get_intent_layout_rect(compact_rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(compact_rect.get_center().x - INTENT_WIDTH * 0.5, compact_rect.position.y),
		Vector2(INTENT_WIDTH, intent_row.size.y),
	)

func get_reserved_layout_rect(compact_rect: Rect2) -> Rect2:
	var reserved := compact_rect.merge(_get_intent_layout_rect(compact_rect))
	reserved = reserved.merge(Rect2(compact_rect.position + details.position, DETAILS_SIZE))
	return reserved
```

Generalize `_layout_enemy_huds()` so each compact rectangle retains both its X and Y offset inside the reservation:

```gdscript
var compact_offsets: Array[Vector2] = []
for child: Node in hud_layer.get_children():
	if child is not EnemyWorldHUD:
		continue
	var hud := child as EnemyWorldHUD
	hud.set_safe_rect(safe_rect)
	if not hud.visible or not hud.has_valid_projection():
		continue
	var rect := hud.get_desired_compact_rect()
	var reserved_rect := hud.get_reserved_layout_rect(rect)
	var reservation_head := rect.position - reserved_rect.position
	var reservation_tail := reserved_rect.end - rect.end
	rect.position.x = clampf(
		rect.position.x,
		safe_rect.position.x + reservation_head.x,
		safe_rect.end.x - rect.size.x - reservation_tail.x,
	)
	rect.position.y = clampf(
		rect.position.y,
		safe_rect.position.y + reservation_head.y,
		safe_rect.end.y - rect.size.y - reservation_tail.y,
	)
	reserved_rect = hud.get_reserved_layout_rect(rect)
	visible_huds.append(hud)
	reserved_rects.append(reserved_rect)
	compact_offsets.append(rect.position - reserved_rect.position)
var resolved_reserved_rects := EnemyHUDLayout.resolve(reserved_rects, safe_rect)
if resolved_reserved_rects.size() != visible_huds.size():
	return
for index: int in visible_huds.size():
	var hud := visible_huds[index]
	var compact_rect := Rect2(
		resolved_reserved_rects[index].position + compact_offsets[index],
		hud.get_desired_compact_rect().size,
	)
	hud.apply_resolved_compact_rect(compact_rect)
```

This replaces the current Y-only `upper_reservations` reconstruction and keeps the compact HUD centered on its projected enemy after horizontal overhang is introduced.

- [ ] **Step 7: Run the focused tests to verify passing behavior**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_intent_formatter -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: all selected suites pass; parsed intent contains no BBCode; `Fortify Attack Drone` occupies one line; the compact stack remains 220 pixels; full reservations stay contained and nonintersecting.

- [ ] **Step 8: Commit the intent slice**

```bash
git add src/battle/presentation/enemy_intent_formatter.gd src/battle/presentation/enemy_world_hud.gd src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/battle_world_3d.gd test/unit/test_enemy_intent_formatter.gd test/unit/test_enemy_world_hud.gd test/integration/test_enemy_hud_formation_projection.gd
git commit -m "fix: widen and balance enemy intents"
```

---

### Task 2: Raised active guard shield

**Files:**
- Modify: `src/battle/presentation/enemy_guard_stack.tscn:1-15, 336-363`
- Modify: `src/battle/presentation/enemy_guard_stack.gd`
- Modify: `src/battle/presentation/enemy_world_hud.gd:196-205`
- Test: `test/unit/test_enemy_guard_stack.gd`
- Test: `test/unit/test_enemy_world_hud.gd`
- Test: `test/integration/test_enemy_hud_formation_projection.gd`

**Interfaces:**
- Consumes: the Task 1 visual-reservation contract.
- Produces: `EnemyGuardStack.get_visual_rect() -> Rect2`, a 36-by-34 current shield, and a shadow that follows the current shield across all three layers.

- [ ] **Step 1: Write failing active-shield geometry tests**

Keep ordinary-pip assertions, but exclude the current pip from the ordinary-size loop and add explicit active geometry:

```gdscript
const ACTIVE_PIP_SIZE := Vector2(36.0, 34.0)
const ACTIVE_LEFT_OVERLAP := 6.0

stack.render(7, false, false)
var previous := _pip(stack, 0, 5)
var current := _pip(stack, 0, 6)
assert_eq(current.size, ACTIVE_PIP_SIZE)
assert_eq(previous.get_rect().end.x - current.position.x, ACTIVE_LEFT_OVERLAP)
assert_gt(current.z_index, previous.z_index)
assert_true(stack.active_shadow.visible)
assert_lt(stack.active_shadow.z_index, current.z_index)
assert_gt(stack.active_shadow.z_index, previous.z_index)
var expected_value_rect := Rect2(
	_layer(stack, 0).position + current.position,
	current.size,
)
assert_eq(Rect2(stack.guard_value.position, stack.guard_value.size), expected_value_rect)
assert_true(expected_value_rect.encloses(_label_ink_rect(stack.guard_value)))
```

For guard 10, 20, and 30, assert that `get_visual_rect().end.x > GUARD_WIDTH`, the value remains inside the active badge, the right overhang is identical, and completed-layer colors remain unchanged. For guard 1, assert the active shield does not extend left of zero.

Update the world-HUD safe-edge test so it checks `guard_stack.get_visual_rect()` translated into global coordinates; the active badge must be reserved rather than clipped at the right safe edge.

- [ ] **Step 2: Run guard and HUD tests to verify failure**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_guard_stack -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
```

Expected: failures show a 21-by-22 current pip, no active shadow, and no guard visual-bounds interface.

- [ ] **Step 3: Author the active shadow and value bounds**

Add a direct `ActiveShieldShadow` `TextureRect` to `enemy_guard_stack.tscn` using the existing shield texture. Give it black modulation with visible alpha, `mouse_filter = IGNORE`, and a Z index above ordinary pips but below the active pip. Increase `GuardValue` to 36 by 34 while preserving its 20-pixel font, four-pixel black outline, centered alignment, and unit scale.

Expose the authored shadow alongside the existing labels:

```gdscript
@onready var active_shadow: TextureRect = %ActiveShieldShadow
@onready var guard_value: Label = %GuardValue
@onready var status_label: Label = %StatusLabel
```

- [ ] **Step 4: Reset ordinary geometry before promoting the current pip**

Add exact authored constants and reset every pip on each render so changing guard cannot leave yesterday's active pip enlarged:

```gdscript
const PIP_SIZE := Vector2(21.0, 22.0)
const PIP_STEP := 22.0
const ACTIVE_PIP_SIZE := Vector2(36.0, 34.0)
const ACTIVE_LEFT_SHIFT := 7.0
const ACTIVE_SHADOW_OFFSET := Vector2(2.0, 3.0)

func _reset_pip_geometry() -> void:
	for layer_index: int in layers.size():
		for pip_index: int in PIPS_PER_LAYER:
			var pip := layers[layer_index].get_child(pip_index) as TextureRect
			pip.position = Vector2(PIP_STEP * pip_index, 0.0)
			pip.size = PIP_SIZE
			pip.z_index = 0
```

Call `_reset_pip_geometry()` before assigning visibility. Hide the active shadow for zero guard.

- [ ] **Step 5: Promote only the current shield**

After locating `current_pip`, calculate and apply the raised geometry:

```gdscript
var base_position := Vector2(PIP_STEP * current_column, 0.0)
var active_position := Vector2(maxf(0.0, base_position.x - ACTIVE_LEFT_SHIFT), -5.0)
current_pip.position = active_position
current_pip.size = ACTIVE_PIP_SIZE
current_pip.z_index = 10
active_shadow.position = layers[current_layer].position + active_position + ACTIVE_SHADOW_OFFSET
active_shadow.size = ACTIVE_PIP_SIZE
active_shadow.z_index = 9
active_shadow.visible = true
guard_value.position = layers[current_layer].position + active_position
guard_value.size = ACTIVE_PIP_SIZE
guard_value.z_index = 11
```

The seven-pixel shift produces six pixels of overlap with the preceding ordinary shield. At columns 10, 20, and 30 it also creates the approved controlled right overhang.

- [ ] **Step 6: Report and reserve complete guard bounds**

Add `get_visual_rect()` that merges visible elements in stack-local coordinates:

```gdscript
func get_visual_rect() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for layer: Control in layers:
		for child: Node in layer.get_children():
			var pip := child as TextureRect
			if pip == null or not pip.visible:
				continue
			var pip_rect := Rect2(layer.position + pip.position, pip.size)
			bounds = bounds.merge(pip_rect) if has_bounds else pip_rect
			has_bounds = true
	if active_shadow.visible:
		var shadow_rect := Rect2(active_shadow.position, active_shadow.size)
		bounds = bounds.merge(shadow_rect) if has_bounds else shadow_rect
		has_bounds = true
	if guard_value.visible:
		var value_rect := Rect2(guard_value.position, guard_value.size)
		bounds = bounds.merge(value_rect) if has_bounds else value_rect
		has_bounds = true
	if status_label.visible:
		var status_rect := Rect2(status_label.position, status_label.size)
		bounds = bounds.merge(status_rect) if has_bounds else status_rect
		has_bounds = true
	return bounds
```

Merge it into `EnemyWorldHUD.get_reserved_layout_rect()` using the current stack offset relative to `CompactStack`:

```gdscript
var guard_visual := guard_stack.get_visual_rect()
if guard_visual.has_area():
	var guard_offset := guard_stack.global_position - compact_stack.global_position
	reserved = reserved.merge(Rect2(
		compact_rect.position + guard_offset + guard_visual.position,
		guard_visual.size,
	))
```

Task 1's generalized head/tail reservation logic then keeps the active badge inside the safe screen rect without widening HP.

- [ ] **Step 7: Run focused guard, HUD, and formation tests**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_guard_stack -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: ordinary pips retain their authored count/layer geometry; only the active pip grows; the value fits; shadow and overlap are present; visual reservations remain safe.

- [ ] **Step 8: Commit the guard slice**

```bash
git add src/battle/presentation/enemy_guard_stack.gd src/battle/presentation/enemy_guard_stack.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_guard_stack.gd test/unit/test_enemy_world_hud.gd test/integration/test_enemy_hud_formation_projection.gd
git commit -m "feat: raise the active enemy shield"
```

---

### Task 3: Fixed party-facing enemy yaw

**Files:**
- Modify: `src/battle/presentation/battle_formation_layout.gd`
- Test: `test/unit/test_battle_formation_layout.gd`
- Test: `test/integration/test_enemy_hud_formation_projection.gd`

**Interfaces:**
- Consumes: existing `ordinary_transforms(count: int, layout: Layout) -> Array[Transform3D]` callers without changing the signature.
- Produces: `PARTY_FOCAL_POINT := Vector3(0.0, 0.0, 9.5)` and `_party_facing_basis(position: Vector3) -> Basis`, with model-positive-Z aimed at the focal point.

- [ ] **Step 1: Write failing yaw tests while preserving every origin assertion**

Add:

```gdscript
func test_ordinary_enemies_face_fixed_party_focal_point_with_yaw_only() -> void:
	var transforms := BattleFormationLayout.ordinary_transforms(5, BattleFormationLayout.Layout.W)
	for transform: Transform3D in transforms:
		var expected := BattleFormationLayout.PARTY_FOCAL_POINT - transform.origin
		expected.y = 0.0
		expected = expected.normalized()
		var model_front := (transform.basis * Vector3.BACK).normalized()
		assert_gt(model_front.dot(expected), 0.999)
		assert_almost_eq(model_front.y, 0.0, 0.0001)
	assert_gt(transforms[0].basis.get_euler().y, 0.0)
	assert_lt(transforms[2].basis.get_euler().y, 0.0)
```

Keep the existing exact W/M origin tests unchanged. Add an integration assertion that changing `world.camera_rig.rotation.y` between -3 and +3 degrees never changes any placed enemy root transform.

- [ ] **Step 2: Run formation tests to verify failure**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_formation_layout -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: origins still pass, while identity bases fail the party-facing dot-product assertions.

- [ ] **Step 3: Generate yaw-only positive-Z-facing bases**

Implement:

```gdscript
const PARTY_FOCAL_POINT := Vector3(0.0, 0.0, 9.5)

static func _party_facing_basis(position: Vector3) -> Basis:
	var direction := PARTY_FOCAL_POINT - position
	direction.y = 0.0
	if direction.is_zero_approx():
		return Basis.IDENTITY
	return Basis.looking_at(direction.normalized(), Vector3.UP, true)
```

Use `Transform3D(_party_facing_basis(position), position)` in `ordinary_transforms()`. Leave boss transforms unchanged in this focused pass. The `use_model_front = true` argument points the drone model's positive Z front toward the party.

- [ ] **Step 4: Run formation tests to verify passing behavior**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_formation_layout -gexit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: exact origins remain unchanged; outer enemies yaw inward; bases remain stable across camera edge motion; five-enemy HUD projection still passes.

- [ ] **Step 5: Commit the facing slice**

```bash
git add src/battle/presentation/battle_formation_layout.gd test/unit/test_battle_formation_layout.gd test/integration/test_enemy_hud_formation_projection.gd
git commit -m "fix: face ordinary enemies toward the party"
```

---

### Task 4: Parse, regression, and manual visual acceptance

**Files:**
- Verify only; do not modify unrelated dirty files.

**Interfaces:**
- Consumes: completed intent, guard, reservation, and facing slices.
- Produces: fresh automated results and a clearly separated manual-acceptance handoff.

- [ ] **Step 1: Import and parse the project**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
```

Expected: exit 0 with no parser errors or crashes. The documented macOS CA certificate diagnostic is acceptable.

- [ ] **Step 2: Run the focused presentation suites together**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_intent_formatter -gselect enemy_guard_stack -gselect enemy_world_hud -gselect battle_formation_layout -gselect enemy_hud_formation_projection -gexit
```

Expected: every selected test and assertion passes.

- [ ] **Step 3: Run the complete suite**

Run:

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: record exact test and assertion totals. Distinguish any pre-existing failures caused by user-dirty files from regressions introduced by this plan; parser errors, crashes, and new failures are unacceptable.

- [ ] **Step 4: Inspect the final task diff**

Run:

```bash
git diff --check HEAD~3..HEAD
git status --short
```

Expected: no whitespace errors; task commits contain only the files named above; all unrelated user work remains unstaged and unmodified by the implementation.

- [ ] **Step 5: Perform manual visual acceptance**

At both `1920x1080` and `1280x800`, verify:

1. `Fortify Attack Drone` stays on one centered line and no BBCode tag is visible.
2. Five-enemy W and M layouts keep intent, details, HP, active shields, and status text attributable and inside the safe screen area.
3. Ordinary shield gaps remain readable; only the current shield grows, overlaps left, hangs right when appropriate, and appears raised by its shadow.
4. Guard values 7, 10, 13, 23, and 30 remain centered and contained; zero guard still shows `VULNERABLE` or `BREACHED` correctly.
5. Left and right drones face slightly inward toward the party; no drone swivels when the ambient camera moves at screen edges.
6. Target hover, click, controller selection, outline presentation, HP feedback, and damage popups remain unchanged.

Record manual acceptance separately from automated results; automation does not establish final visual quality.
