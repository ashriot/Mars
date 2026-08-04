# Enemy HUD Contrast and Damage Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 3D enemy HUD readable at Steam Deck scale and restore resolved damage popups over the struck enemy model.

**Architecture:** Keep `EnemyWorldHUD` as the owner of enemy world-label styling, authoritative HP text, projection-aware popup placement, and presentation-event handling. Reuse the existing `DamagePopup` scene without changing combat resolution or `EnemyDronePresentation`; preserve the 220-pixel compact width, W/M formation transforms, guard spacing/layers, and yellow-damage/green-healing feedback.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, GUT unit/integration tests.

## Global Constraints

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` and the isolated test `HOME` required by `docs/testing/README.md`.
- Preserve the 220-pixel enemy HUD width, W/M formation transforms, targeting behavior, combat rules, and existing Quaternius model assets.
- Author inspected name at 28 pixels; intent, defenses, exact HP, `VULNERABLE`, and `BREACHED` at 24 pixels; guard value at 20 pixels.
- Use opaque black outlines: 8 pixels for 28-pixel text, 6 pixels for 24-pixel text, and 4 pixels for 20-pixel icon-contained text.
- Keep HP exactly `220x32`, with permanent centered `current / max` text and the existing rounded pink/yellow/green progress layers.
- Keep guard pips in front of the HP bar with a 4-pixel overlap; preserve 21-pixel pips, 22-pixel horizontal centers, 10 columns, and 5-pixel vertical layer steps.
- A missing model projection may suppress the cosmetic popup, but must never block damage, health synchronization, animation, targeting, or battle sequencing.
- Preserve unrelated user changes in the dirty worktree and stage only files named by the active task.

---

### Task 1: Readable Enemy Vitals and Details

**Files:**
- Modify: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Modify: `src/battle/presentation/enemy_guard_stack.tscn`
- Modify: `test/unit/test_enemy_world_hud.gd`
- Modify: `test/unit/test_enemy_guard_stack.gd`
- Modify: `test/integration/test_enemy_hud_formation_projection.gd`

**Interfaces:**
- Consumes: `EnemyWorldHUD.bind_combatant(enemy: EnemyCombatant) -> bool`, `EnemyWorldHUD.refresh_intent() -> void`, `EnemyGuardStack.render(guard: int, is_in_danger: bool, is_breached: bool) -> void`, and the current dual progress-bar health feedback.
- Produces: `%HPValue: Label`, `EnemyWorldHUD.GUARD_TOP == 28.0`, `EnemyWorldHUD.DETAILS_SIZE == Vector2(220.0, 74.0)`, centered BBCode intent, and a compact HUD whose HP/guard/detail geometry remains safe for the existing projection resolver.

- [ ] **Step 1: Tighten the HUD scene-contract tests around the approved typography and geometry**

In `test/unit/test_enemy_world_hud.gd`, change the geometry constants and expand `test_compact_stack_authors_layered_hp_and_overlapping_guard` so it requires the permanent HP label, exact bar size, draw order, and exact type system:

```gdscript
const HP_SIZE := Vector2(220.0, 32.0)
const HP_GUARD_OVERLAP := 4.0
const DETAILS_SIZE := Vector2(220.0, 74.0)

var hp_value := hud.get_node_or_null("%HPValue") as Label
assert_not_null(hp_value)
assert_eq(hp_region.size, HP_SIZE)
assert_eq(feedback.get_rect(), Rect2(Vector2.ZERO, HP_SIZE))
assert_eq(actual.get_rect(), Rect2(Vector2.ZERO, HP_SIZE))
assert_eq(guard_stack.position, Vector2(0.0, 28.0))
assert_eq(HP_SIZE.y - guard_stack.position.y, HP_GUARD_OVERLAP)
assert_gt(hp_value.z_index, actual.z_index)
assert_eq(hp_value.text, "80 / 100")
assert_eq(hp_value.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
assert_eq(hp_value.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
assert_eq(hp_value.get_theme_font_size(&"font_size"), 24)
assert_eq(hp_value.get_theme_constant(&"outline_size"), 6)
assert_eq(hp_value.get_theme_color(&"font_outline_color"), Color.BLACK)

assert_eq(hud.name_label.get_theme_font_size(&"font_size"), 28)
assert_eq(hud.name_label.get_theme_constant(&"outline_size"), 8)
assert_eq(hud.kinetic_value.get_theme_font_size(&"font_size"), 24)
assert_eq(hud.energy_value.get_theme_font_size(&"font_size"), 24)
assert_eq(hud.kinetic_value.get_theme_constant(&"outline_size"), 6)
assert_eq(hud.energy_value.get_theme_constant(&"outline_size"), 6)
assert_eq(hud.intent_row.get_theme_font_size(&"normal_font_size"), 24)
assert_eq(hud.intent_row.get_theme_constant(&"outline_size"), 6)
assert_eq(hud.intent_row.get_theme_color(&"default_outline_color"), Color.BLACK)
assert_gte(hud.intent_row.custom_minimum_size.y, 36.0)
```

Update the health signal assertion in `test_bound_model_signals_refresh_vitals_intent_and_conditions` and require centered intent markup:

```gdscript
assert_eq(hud.hp_value.text, "45 / 100")
assert_eq(hud.intent_row.text, "[center]Repair[/center]")
assert_eq(hud.intent_row.get_parsed_text(), "Repair")
```

In `test/unit/test_enemy_guard_stack.gd`, require the guard value and zero-guard status labels to meet the approved scale and outline ratios:

```gdscript
assert_eq(stack.guard_value.get_theme_font_size(&"font_size"), 20)
assert_eq(stack.guard_value.get_theme_constant(&"outline_size"), 4)
assert_eq(stack.guard_value.get_theme_color(&"font_outline_color"), Color.BLACK)
assert_eq(stack.status_label.get_theme_font_size(&"font_size"), 24)
assert_eq(stack.status_label.get_theme_constant(&"outline_size"), 6)
assert_eq(stack.status_label.get_theme_color(&"font_outline_color"), Color.BLACK)
```

Retain the existing assertions for pip width, 1-pixel gap, layer colors, 10 columns, and 5-pixel layer steps.

- [ ] **Step 2: Run the two unit suites and confirm they fail for the missing approved presentation**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd,res://test/unit/test_enemy_guard_stack.gd -gexit
```

Expected: FAIL because `%HPValue` does not exist, HP is still 18 pixels tall, intent/details/status text is below the approved floor, outlines are absent, guard begins at Y 14, and intent is not centered.

- [ ] **Step 3: Author the exact HUD hierarchy, dimensions, and text styles**

In `enemy_world_hud.tscn`:

- expand `Details` to `220x74` while keeping it outside the compact stack;
- set `%Name` to font size 28, black outline size 8;
- set `%Kinetic` and `%Energy` to font size 24, black outline size 6;
- make `%IntentRow` at least `220x36`, font size 24, black default outline size 6;
- expand `%HPRegion`, `%HPFeedback`, and `%HPActual` to `220x32`;
- add `%HPValue` as a full-size child of `%HPRegion`, above both progress bars;
- move `%GuardStack` to Y 28 and set its z-index above `%HPValue` so shields overlap the lower four pixels of the bar without being hidden.

The new label node must be authored as:

```ini
[node name="HPValue" type="Label" parent="CompactStack/VitalsAndConditions/VitalsGroup/HPRegion"]
unique_name_in_owner = true
layout_mode = 0
offset_right = 220.0
offset_bottom = 32.0
mouse_filter = 2
z_index = 2
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_fonts/font = ExtResource("3_bold")
theme_override_font_sizes/font_size = 24
text = "100 / 100"
horizontal_alignment = 1
vertical_alignment = 1
```

Give `%GuardStack` z-index 3. In `enemy_guard_stack.tscn`, set `%GuardValue` to 20/4 and `%StatusLabel` to 24/6 using opaque black `font_outline_color`; do not move or resize the pips or layer controls.

- [ ] **Step 4: Render authoritative HP text and centered intent from the model**

In `enemy_world_hud.gd`, add the HP label reference and update the geometry constants:

```gdscript
const DETAILS_SIZE := Vector2(220.0, 74.0)
const GUARD_TOP := 28.0

@onready var hp_value: Label = %HPValue
```

Set the exact HP text on every `_render_hp` call, before the optional visual reset:

```gdscript
hp_value.text = "%d / %d" % [
	combatant.current_hp, combatant.current_stats.max_hp,
]
```

Keep the existing tooltip. Center only the visible intent text while preserving the formatter tooltip:

```gdscript
var formatted := EnemyIntentFormatter.format(combatant, combatant.battle_manager)
intent_row.text = "[center]%s[/center]" % formatted.text
intent_tooltip.bbcode_text = formatted.tooltip
```

Do not change health tween values or `HealthFeedbackPalette` calls.

- [ ] **Step 5: Run the HUD and guard unit suites and confirm they pass**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd,res://test/unit/test_enemy_guard_stack.gd -gexit
```

Expected: PASS with no parser, resource-load, or unexpected error output.

- [ ] **Step 6: Protect W/M layout after the compact HUD grows taller**

In `test/integration/test_enemy_hud_formation_projection.gd`, preserve every existing matrix case and assertion at logical `1920x1080` and `1920x1200`, both W and M arrangements, and yaw `-3`, `0`, and `+3`. Add assertions inside the existing projected-HUD loop:

```gdscript
assert_eq(hud.hp_region.size, Vector2(220.0, 32.0))
assert_eq(hud.get_node("%HPValue").size, Vector2(220.0, 32.0))
assert_true(safe_rect.encloses(hud.get_reserved_layout_rect(compact_rect)))
```

Keep the pairwise compact-HUD and one-open-detail nonintersection checks. Do not alter camera, formation transforms, safe area, or resolver constants merely to satisfy the new scene size.

- [ ] **Step 7: Run the formation suite and review only task-owned changes**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_enemy_hud_formation_projection.gd -gexit
git diff --check -- src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd src/battle/presentation/enemy_guard_stack.tscn test/unit/test_enemy_world_hud.gd test/unit/test_enemy_guard_stack.gd test/integration/test_enemy_hud_formation_projection.gd
```

Expected: the formation suite passes every W/M, canvas, and yaw case; `git diff --check` prints nothing.

- [ ] **Step 8: Commit the readable HUD as an independent change**

```bash
git add src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd src/battle/presentation/enemy_guard_stack.tscn test/unit/test_enemy_world_hud.gd test/unit/test_enemy_guard_stack.gd test/integration/test_enemy_hud_formation_projection.gd
git commit -m "fix: improve enemy HUD contrast"
```

---

### Task 2: Projection-Aware Enemy Damage Popups and Acceptance Coverage

**Files:**
- Modify: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Modify: `test/unit/test_enemy_world_hud.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Consumes: `%HPValue`, `EnemyWorldHUD.set_projected_model_bounds(value: Rect2)`, `EnemyWorldHUD.set_projected_head_position(value: Vector2)`, `EnemyWorldHUD.set_projected_foot_position(value: Vector2)`, `DamagePopup.show_damage(amount: int, damage_type: Action.DamageType, speed: float, is_crit := false)`, and the real `damage_received` payload keys `result`, `damage_type`, and `actual_damage`.
- Produces: exported `damage_popup_scene: PackedScene`, `_get_damage_popup_center() -> Variant`, `_spawn_damage_popup(result: DamageResult, damage_type: Action.DamageType) -> void`, and deterministic rapid-hit separation in enemy-HUD canvas coordinates.

- [ ] **Step 1: Add failing tests for real damage-event popup behavior**

In `test/unit/test_enemy_world_hud.gd`, preload `DamagePopup`, add a `DamageResult` helper, and add a helper that returns current popup children from the HUD's parent:

```gdscript
func _damage_result(
	amount: int,
	damage_type: Action.DamageType,
	is_critical := false,
) -> DamageResult:
	var request := DamageRequest.new(amount, 0, 0, 1.0, 1, damage_type, 0)
	return DamageResult.new(
		request, amount, 0, 1.0, 1.0, 1.0, amount, amount, is_critical,
	)


func _damage_popups(parent: Node) -> Array[DamagePopup]:
	var popups: Array[DamagePopup] = []
	for child: Node in parent.get_children():
		if child is DamagePopup:
			popups.append(child as DamagePopup)
	return popups
```

Create a nonlethal real-event test with the HUD under a plain `Control` canvas parent. Bind a 100-HP enemy, set `Rect2(400, 300, 120, 160)` projected model bounds, then call and await:

```gdscript
await enemy.take_one_hit(
	_damage_result(17, Action.DamageType.ENERGY, true),
	Effect_Damage.new(),
	null,
	Action.DamageType.ENERGY,
)
```

Assert exactly one `DamagePopup` is a sibling of the HUD, its pivot lands on `Vector2(460, 380)`, its label reads `17!`, and its label color is `Color("00ffff")`. This protects resolved `final_damage`, critical state, damage type, and projected model-center placement.

Add three focused tests:

1. emit two complete damage payloads in the same frame and assert two popups have distinct global pivot positions;
2. provide only valid head and foot projections and assert the popup pivot equals their midpoint;
3. provide no valid projection, emit a complete damage event, assert zero popups, and assert HP/progress handling still completes without an error.

Keep the existing manually emitted `{}` and `{"actual_damage": amount}` damage events in regression tests; incomplete legacy/test payloads must continue updating health feedback without spawning or erroring.

- [ ] **Step 2: Run the HUD unit suite and confirm popup tests fail**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd -gexit
```

Expected: the new popup tests fail because `EnemyWorldHUD` does not instantiate `DamagePopup`; existing health and targeting tests remain green.

- [ ] **Step 3: Assign the established popup scene to the enemy HUD**

In `enemy_world_hud.tscn`, add an external resource for `res://src/battle/damage_popup.tscn` and assign it on the root:

```ini
[ext_resource type="PackedScene" uid="uid://ckw8rm3jl32bx" path="res://src/battle/damage_popup.tscn" id="6_damage_popup"]

[node name="EnemyWorldHUD" type="Control" unique_id=1610102526 groups=["enemy_world_hud"]]
damage_popup_scene = ExtResource("6_damage_popup")
```

Do not modify `damage_popup.tscn` or `damage_popup.gd`; their colors, critical marker, outline, motion, timing, and self-cleanup are shared behavior.

- [ ] **Step 4: Spawn popups at the projected model center without affecting combat**

In `enemy_world_hud.gd`, add:

```gdscript
@export var damage_popup_scene: PackedScene

const POPUP_SPACING_TIME_MSEC := 1000
const POPUP_HORIZONTAL_STEP := 60.0
const POPUP_VERTICAL_STEP := 30.0

var _last_popup_time_msec := -POPUP_SPACING_TIME_MSEC
var _popup_stack_offset := 0
```

Change `_on_presentation_event` to use `payload` and request a popup only for a complete real damage payload:

```gdscript
func _on_presentation_event(
	_enemy: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			HealthFeedbackPalette.apply(
				hp_bar_feedback, HealthFeedbackPalette.Direction.DAMAGE,
			)
			hp_bar_actual.value = combatant.current_hp
			var result := payload.get("result") as DamageResult
			if result != null and payload.has("damage_type"):
				var damage_type: Action.DamageType = payload["damage_type"]
				_spawn_damage_popup(result, damage_type)
```

Resolve placement and instantiate defensively:

```gdscript
func _get_damage_popup_center() -> Variant:
	if _has_projected_model_bounds:
		return _projected_model_bounds.get_center()
	if _has_projected_head and _has_projected_foot:
		return (_projected_head + _projected_foot) * 0.5
	return null


func _spawn_damage_popup(
	result: DamageResult,
	damage_type: Action.DamageType,
) -> void:
	if damage_popup_scene == null or not _has_live_combatant():
		return
	var popup_center: Variant = _get_damage_popup_center()
	if popup_center == null or get_parent() == null:
		return
	var popup := damage_popup_scene.instantiate() as DamagePopup
	if popup == null:
		return
	get_parent().add_child(popup)
	var target_center: Vector2 = popup_center
	var current_time_msec := Time.get_ticks_msec()
	if current_time_msec - _last_popup_time_msec < POPUP_SPACING_TIME_MSEC:
		_popup_stack_offset += 1
		var side := 1.0 if _popup_stack_offset % 2 == 0 else -1.0
		target_center.x += side * POPUP_HORIZONTAL_STEP
		target_center.y -= float(_popup_stack_offset) * POPUP_VERTICAL_STEP
	else:
		_popup_stack_offset = 0
	popup.global_position = target_center - popup.pivot_offset
	_last_popup_time_msec = current_time_msec
	popup.show_damage(
		result.final_damage, damage_type, _get_battle_speed(), result.is_critical,
	)
```

The popup uses `result.final_damage`, matching `ActorCard`; do not substitute `actual_damage`, because overkill presentation must remain consistent with the existing actor-card contract.

- [ ] **Step 5: Run focused popup and presentation regressions**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd,res://test/integration/test_enemy_drone_presentation.gd,res://test/integration/test_enemy_hud_formation_projection.gd -gexit
```

Expected: PASS. In particular, incomplete test-only presentation payloads remain harmless, real damage produces one correctly styled popup, rapid events separate, fallback placement works, and projection-free damage omits only the cosmetic popup.

- [ ] **Step 6: Update the hands-on battle checklist to match the implemented contract**

In `docs/testing/ctb-combat-checklist.md`, replace the outdated enemy-HUD acceptance item that says exact HP is tooltip-only with unchecked items requiring:

```markdown
- [ ] Verify every enemy HP bar is `220x32`, permanently displays centered `current / max` text, and keeps rounded pink actual health over yellow delayed damage or green delayed healing.
- [ ] Verify inspected name, centered intent, defenses, exact HP, Guard, `VULNERABLE`, and `BREACHED` remain readable over both bright walls and dark room regions at physical `1920x1080` and desktop-proxy `1280x800`.
- [ ] Damage each outer, inner, and center enemy with kinetic, energy, piercing, rapid, and critical hits; verify each value appears over the struck model center with the established color and critical `!`, while rapid values remain distinguishable.
```

Keep these items unchecked until the user performs the named visual checks. Do not rewrite historical acceptance evidence.

- [ ] **Step 7: Import, run focused verification, and run the complete suite**

Run the editor import first:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --editor --path /Users/adam/github/mars --quit
```

Then run focused tests:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_guard_stack.gd,res://test/unit/test_enemy_world_hud.gd,res://test/integration/test_enemy_hud_formation_projection.gd,res://test/integration/test_enemy_drone_presentation.gd -gexit
```

Finally run the complete suite:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: import and focused suites pass with no parser, script, resource, or unexpected runtime errors. Record exact full-suite totals; if the two known dirty-worktree failures remain—DynamicGlyph safe footprint and endgame battle-lab HP multiplier—report them as unrelated instead of changing user-owned files.

- [ ] **Step 8: Inspect the final diff and commit only popup/checklist files**

```bash
git diff --check -- src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_world_hud.gd docs/testing/ctb-combat-checklist.md
git status --short
git add src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_world_hud.gd docs/testing/ctb-combat-checklist.md
git commit -m "fix: restore enemy damage popups"
```

Expected: `git diff --check` prints nothing, the staged set contains only task files, and all unrelated dirty user files remain unstaged.

- [ ] **Step 9: Perform or clearly hand off manual visual acceptance**

At physical `1920x1080` and desktop-proxy `1280x800`, verify:

- every enemy label is readable against bright walls, ceiling practicals, black recesses, and the back door;
- intent is centered; details appear above the compact HUD and remain attributable;
- exact HP remains centered inside every 32-pixel bar during damage and healing;
- guard pips remain in front with their existing gaps and four-pixel HP overlap;
- kinetic, energy, piercing, critical, and rapid damage values appear over the correct model and remain distinguishable;
- W and M arrangements remain in bounds and visually connected to their models.

If these checks are not performed in this session, leave the checklist unchecked and report them as the only remaining acceptance work.
