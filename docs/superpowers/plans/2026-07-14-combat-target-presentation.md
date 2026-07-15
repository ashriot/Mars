# Combat Target Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give hero and enemy combat cards a shared bright-white availability outline, a distinct selected-target pulse, input-appropriate target ownership, and synchronized delayed CTB preview.

**Architecture:** `ActorCard` owns a semantic three-state presentation API and its overlay tween. `BattleScene` owns the current executable target, retained navigation origin, and remembered hero/enemy targets; `BattleManager` remains authoritative for candidate calculation, execution, and CTB simulation while relaying generic card hover events. Group actions and lifecycle cleanup use the same presentation API so no overlay state leaks between actions or turns.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` scenes and `StyleBoxFlat` resources, GUT 9.6.1.

## Global Constraints

- Work directly on the ordinary feature branch in `/Users/adam/github/mars`; repository rules prohibit a Git worktree unless the user explicitly requests one.
- Use Godot 4.6.3; do not change the engine version, vendored plugins, dependencies, or project-wide formats.
- Every automated Godot run must use `HOME=/tmp/mars-godot-home` so ordinary save data is never read or written.
- Preserve unrelated user work and commit only each task's listed files plus required Godot sidecars for those files.
- Valid targets use a steady, fully bright white outline. Gray or reduced-opacity validity outlines are forbidden.
- Selected targets retain the solid white outline and add a thicker breathing outer glow; the base outline never fades during the pulse.
- Cards outside the eligible/selected sets remain visually unaffected.
- Hero and enemy cards use the same target-presentation contract.
- The active hero uses only its existing slide-up/down turn presentation; do not replace its removed blink with another outline.
- Mouse/keyboard single-target entry starts empty; controller entry restores a remembered valid same-side target or deterministic fallback.
- A retained navigation origin is never executable unless it is visibly selected.
- Mouse motion cannot take controller ownership. The first controller-to-mouse click transaction remains consumed, keyboard input remains immediate, and no code may warp the hardware pointer.
- Software-cursor behavior remains security-scan-only.
- The hub redesign and controls hint-bar redesign are separate deferred efforts.
- Follow strict TDD for every behavior change: capture RED before production edits, then focused GREEN, then the complete suite before each task commit.

## Planned File Structure

- `src/battle/actor_card.gd` — semantic target-presentation state and overlay tween ownership.
- `src/battle/hero_card.tscn` — hero target outline and selected-glow overlays.
- `src/battle/enemy_card.tscn` — enemy target outline and selected-glow overlays.
- `src/battle/hero_card.gd` — hero hover signals and slide-only active-turn behavior.
- `src/battle/enemy_card.gd` — enemy hover migration to the common actor contract.
- `src/battle/battle_scene.gd` — current target, navigation origin, remembered targets, input-specific entry, direction, confirm, and pointer handoff.
- `src/battle/battle_manager.gd` — candidate presentation, generic hover relay, group-target state, CTB simulation calls, and cleanup.
- `test/unit/test_actor_card_target_presentation.gd` — card-state contract using the real hero and enemy scenes.
- `test/integration/test_battle_controller_navigation.gd` — controller/keyboard ownership, target memory, geometry, real hero/enemy pointer hover, CTB synchronization, lifecycle, group targets, and active hero behavior.
- `test/integration/test_controller_playable_loop.gd` — final full-loop target-selection acceptance without duplicate lower-level cases.
- `docs/testing/controller-manual-checklist.md` — physical and visual target-presentation acceptance.

---

### Task 1: Semantic actor-card target presentation

**Files:**
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/hero_card.tscn`
- Modify: `src/battle/enemy_card.tscn`
- Modify: `src/battle/battle_manager.gd`
- Create: `test/unit/test_actor_card_target_presentation.gd`

**Interfaces:**
- Consumes: existing `ActorCard.setup_base()`, `BattleManager.set_current_action()`, and `BattleManager._clear_all_targeting_ui()`.
- Produces: `ActorCard.TargetPresentation { NORMAL, AVAILABLE, SELECTED }`, `set_target_presentation(state: TargetPresentation) -> void`, `get_target_presentation() -> TargetPresentation`, `$Panel/TargetOutline`, and `$Panel/TargetPulse`.

- [ ] **Step 1: Add card-state tests before changing production code**

Create `test/unit/test_actor_card_target_presentation.gd` with real scene fixtures and state assertions:

```gdscript
extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


func _cards() -> Array[ActorCard]:
	var cards: Array[ActorCard] = []
	for scene: PackedScene in [HeroCardScene, EnemyCardScene]:
		var card := scene.instantiate() as ActorCard
		add_child_autofree(card)
		cards.append(card)
	return cards


func test_hero_and_enemy_share_normal_available_and_selected_target_states() -> void:
	for card in _cards():
		var outline := card.get_node("Panel/TargetOutline") as Panel
		var pulse := card.get_node("Panel/TargetPulse") as Panel
		assert_eq(card.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
		assert_false(outline.visible)
		assert_false(pulse.visible)

		card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
		assert_true(outline.visible)
		assert_false(pulse.visible)
		var available_style := outline.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(available_style.border_color, Color.WHITE)

		card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		assert_true(outline.visible)
		assert_true(pulse.visible)
		assert_not_null(card._target_pulse_tween)

		card.set_target_presentation(ActorCard.TargetPresentation.NORMAL)
		assert_false(outline.visible)
		assert_false(pulse.visible)
		assert_null(card._target_pulse_tween)


func test_repeated_target_state_assignment_keeps_one_tween_and_exact_normal_cleanup() -> void:
	var card := _cards()[0]
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	var first_tween := card._target_pulse_tween
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	assert_same(card._target_pulse_tween, first_tween)
	card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
	assert_null(card._target_pulse_tween)
	assert_true(card.target_outline.visible)
	assert_false(card.target_pulse.visible)
```

- [ ] **Step 2: Run the new unit script and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
```

Expected: nonzero exit because `TargetOutline`, `TargetPulse`, `TargetPresentation`, and the semantic methods do not exist.

- [ ] **Step 3: Replace `TargetFlash` with independent outline and pulse overlays in both scenes**

In both card scenes, replace `$Panel/TargetFlash` with two mouse-ignoring panels:

```text
Panel/TargetOutline
  visible = false
  anchors = full rect with 2px inset
  StyleBoxFlat: transparent background, 4px border, border_color = Color(1, 1, 1, 1), 12px corners

Panel/TargetPulse
  visible = false
  anchors = full rect with 5px expansion
  StyleBoxFlat: transparent background, 8px border, border_color = Color(1, 1, 1, 1), white shadow, 17px corners
```

Keep both overlays below card content and above the base panel background. Set `mouse_filter = Control.MOUSE_FILTER_IGNORE`.

- [ ] **Step 4: Implement the semantic state machine in `ActorCard`**

Replace `target_flash`, `flash_tween`, `start_flashing()`, and `stop_flashing()` with:

```gdscript
enum TargetPresentation { NORMAL, AVAILABLE, SELECTED }

@onready var target_outline: Panel = $Panel/TargetOutline
@onready var target_pulse: Panel = $Panel/TargetPulse

var _target_presentation := TargetPresentation.NORMAL
var _target_pulse_tween: Tween


func get_target_presentation() -> TargetPresentation:
	return _target_presentation


func set_target_presentation(state: TargetPresentation) -> void:
	if state == _target_presentation:
		target_outline.visible = state != TargetPresentation.NORMAL
		target_pulse.visible = state == TargetPresentation.SELECTED
		return
	_stop_target_pulse()
	_target_presentation = state
	target_outline.visible = state != TargetPresentation.NORMAL
	target_pulse.visible = state == TargetPresentation.SELECTED
	if state == TargetPresentation.SELECTED:
		target_pulse.modulate.a = 0.35
		_target_pulse_tween = create_tween().set_loops()
		_target_pulse_tween.tween_property(target_pulse, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_pulse_tween.tween_property(target_pulse, "modulate:a", 0.35, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_target_pulse() -> void:
	if _target_pulse_tween and _target_pulse_tween.is_valid():
		_target_pulse_tween.kill()
	_target_pulse_tween = null
	target_pulse.modulate.a = 1.0
```

At the end of `setup_base()`, establish `NORMAL` explicitly without starting a tween. If the ready-time state already equals `NORMAL`, synchronize the two node visibilities directly before returning from the idempotence guard.

- [ ] **Step 5: Migrate manager eligibility and cleanup to the semantic API**

In `BattleManager.set_current_action()`:

```gdscript
for target: ActorCard in get_targets(action.target_type, true):
	target.is_valid_target = true
	target.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
```

In `_clear_all_targeting_ui()`:

```gdscript
for actor: ActorCard in actor_list:
	actor.is_valid_target = false
	actor.set_target_presentation(ActorCard.TargetPresentation.NORMAL)
```

Do not add selection policy in this task.

- [ ] **Step 6: Run focused tests and the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all commands exit 0; card tests prove bright-white availability, selected pulse ownership, idempotence, and exact cleanup.

- [ ] **Step 7: Commit Task 1**

```bash
git add src/battle/actor_card.gd src/battle/hero_card.tscn src/battle/enemy_card.tscn src/battle/battle_manager.gd test/unit/test_actor_card_target_presentation.gd
git commit -m "feat: add semantic combat target presentation"
```

---

### Task 2: Unified directional target ownership and memory

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: Task 1 `ActorCard.TargetPresentation` and `set_target_presentation()`.
- Produces: `BattleScene._current_target: ActorCard`, `_navigation_origin: ActorCard`, `_last_enemy_target: EnemyCard`, `_last_hero_target: HeroCard`, `_set_current_target(target: ActorCard)`, `_clear_current_target(retain_origin: bool)`, and `_restore_remembered_target()`.

- [ ] **Step 1: Replace cursor-era assertions with current-target behavior tests**

Extend `_navigation_fixture()` with a second real `enemy_card.tscn` instance named `second_enemy`, positioned to the right of `enemy`, assigned the same manager, initially alive and invalid, added to `enemy_area` before `scene` enters the tree, and returned in the fixture dictionary. Then add these presentation and memory scenarios:

```gdscript
func test_controller_target_entry_restores_last_valid_same_side_target() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._last_enemy_target = fixture.second_enemy
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.second_enemy)
	assert_eq(fixture.second_enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)


func test_invalid_remembered_target_falls_back_deterministically() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.second_enemy.is_defeated = true
	fixture.scene._last_enemy_target = fixture.second_enemy
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.enemy)


func test_keyboard_mouse_entry_starts_without_an_executable_target() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._refresh_targeting()
	assert_null(fixture.scene._current_target)
	assert_null(fixture.scene._navigation_origin)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)


func test_pointer_cleared_origin_restores_before_next_direction_moves() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	fixture.scene._clear_current_target(true)
	fixture.scene.select_direction(Vector2.RIGHT)
	assert_same(fixture.scene._current_target, fixture.enemy)
	fixture.scene.select_direction(Vector2.RIGHT)
	assert_same(fixture.scene._current_target, fixture.second_enemy)
```

Update existing private-field assertions from `_controller_target` to `_current_target` only where they protect the same semantic target.

- [ ] **Step 2: Run the target-navigation integration script and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: nonzero exit because the unified fields, entry policy, memory, and restore-before-move behavior do not exist.

- [ ] **Step 3: Introduce unified current-target state in `BattleScene`**

Replace `_controller_target` with:

```gdscript
var _current_target: ActorCard
var _navigation_origin: ActorCard
var _last_enemy_target: EnemyCard
var _last_hero_target: HeroCard
```

Add semantic state helpers:

```gdscript
func _set_current_target(target: ActorCard) -> void:
	if not _is_valid_candidate(target):
		return
	if is_instance_valid(_current_target) and _current_target != target:
		_current_target.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
	_current_target = target
	_navigation_origin = target
	target.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	if target is EnemyCard:
		_last_enemy_target = target
	elif target is HeroCard:
		_last_hero_target = target


func _clear_current_target(retain_origin: bool) -> void:
	if is_instance_valid(_current_target):
		_current_target.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
		if retain_origin:
			_navigation_origin = _current_target
	_current_target = null
	if not retain_origin:
		_navigation_origin = null
```

Implement `_is_valid_candidate()` against `is_valid_target`, `is_defeated`, tree validity, and `_valid_targets()` membership. Rename `_valid_controller_targets()` to `_valid_targets()`.

- [ ] **Step 4: Implement input-specific entry and remembered fallback**

Connect `InputManager.presentation_mode_changed` in `_ready()` and disconnect automatically through normal node teardown.

Implement:

```gdscript
func _refresh_targeting() -> void:
	if not _is_targeting():
		_clear_current_target(false)
		_publish_controller_hints()
		return
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_restore_remembered_target()
	elif not _is_valid_candidate(_current_target):
		_clear_current_target(false)
	_publish_controller_hints()


func _restore_remembered_target() -> void:
	var candidates := _valid_targets()
	if candidates.is_empty():
		_clear_current_target(false)
		return
	var remembered: ActorCard = _last_hero_target if candidates[0] is HeroCard else _last_enemy_target
	_set_current_target(remembered if _is_valid_candidate(remembered) else candidates[0])


func _on_presentation_mode_changed(mode: InputManager.PresentationMode) -> void:
	if mode == InputManager.PresentationMode.POINTER \
		and InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and _is_targeting():
		_clear_current_target(true)
```

`_on_input_mode_changed(CONTROLLER)` restores a target only while targeting. Keyboard mode does not discard a visible selected target established by deliberate keyboard input.

- [ ] **Step 5: Update directional navigation and confirmation**

At the start of `select_direction()`:

```gdscript
if not is_instance_valid(_current_target) and _is_valid_candidate(_navigation_origin):
	_set_current_target(_navigation_origin)
	return
```

If both current target and origin are empty, preserve the existing geometry search from `_target_origin(candidates)` so the first direction selects the nearest actor in that half-plane. Use `_current_target` as the origin only when it is valid. `confirm_target()` must return unless `_current_target` is visible, valid, and `SELECTED`.

- [ ] **Step 6: Run focused and complete verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all commands exit 0; controller target memory/fallback and mouse/keyboard empty entry are protected without changing global handoff rules.

- [ ] **Step 7: Commit Task 2**

```bash
git add src/battle/battle_scene.gd test/integration/test_battle_controller_navigation.gd
git commit -m "feat: unify combat directional target ownership"
```

---

### Task 3: Hero/enemy pointer targeting and CTB synchronization

**Files:**
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/battle/hero_card.tscn`
- Modify: `src/battle/enemy_card.tscn`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: Task 2 `_set_current_target()`, `_clear_current_target()`, `_current_target`, and `_navigation_origin`; existing `BattleManager.preview_action_turn_order(actor, action, selected_target)`.
- Produces: `ActorCard.target_hovered(actor: ActorCard)`, `target_unhovered(actor: ActorCard)`, `BattleManager.target_hovered`, `target_unhovered`, `BattleScene._on_target_hovered(actor)`, and `_on_target_unhovered(actor)`.

- [ ] **Step 1: Add real-card pointer and CTB integration tests**

Extend the existing `TrackingBattleManager` in `test_battle_controller_navigation.gd`:

```gdscript
	var preview_targets: Array[ActorCard] = []

	func preview_action_turn_order(_actor: ActorCard, _action: Action, selected_target: ActorCard = null):
		preview_targets.append(selected_target)
```

Add these cases using the real `hero_card.tscn` and `enemy_card.tscn` nodes already created by `_navigation_fixture()`. Emitting the real panel's GUI signals exercises the scene connections, common `ActorCard` relay, manager relay, and `BattleScene` ownership without duplicating the global mouse-handoff tests in `test_navigation_ux_layer.gd`:

Because this fixture bypasses production battle setup, explicitly connect each fixture card's `target_hovered` and `target_unhovered` signals to the manager relay callbacks before adding `scene` to the tree. Production cards receive the same connections in the manager's existing hero/enemy setup paths.

```gdscript
func test_pointer_hover_selects_real_hero_and_enemy_cards_and_exit_clears_selection() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var hero: HeroCard = fixture.hero
	var enemy: EnemyCard = fixture.enemy
	manager.current_action = Action.new()
	manager.current_state = BattleManager.State.FORCED_TARGET
	hero.is_valid_target = true
	enemy.is_valid_target = true
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)

	enemy.panel.mouse_entered.emit()
	assert_same(scene._current_target, enemy)
	assert_eq(enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_same(manager.preview_targets.back(), enemy)

	enemy.panel.mouse_exited.emit()
	hero.panel.mouse_entered.emit()
	assert_same(scene._current_target, hero)
	assert_eq(enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)
	assert_same(manager.preview_targets.back(), hero)

	hero.panel.mouse_exited.emit()
	assert_null(scene._current_target)
	assert_same(scene._navigation_origin, hero)
	assert_null(manager.preview_targets.back())


func test_controller_owned_pointer_hover_cannot_replace_current_target() -> void:
	var fixture := await _navigation_fixture()
	fixture.hero.is_valid_target = true
	fixture.enemy.is_valid_target = true
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.scene._set_current_target(fixture.enemy)
	fixture.hero.panel.mouse_entered.emit()
	assert_same(fixture.scene._current_target, fixture.enemy)
```

Keep first-click consumption covered by the existing real-GUI `test_pointer_keyboard_controller_handoffs_preserve_one_logical_focus()` test in `test_navigation_ux_layer.gd`; do not duplicate that global ownership contract in the battle fixture.

- [ ] **Step 2: Run the pointer integration script and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: nonzero exit because hero cards have no hover signal, enemy hover is not routed through unified target ownership, and pointer exit does not clear current target.

- [ ] **Step 3: Add generic pointer signals to `ActorCard` and both scenes**

In `ActorCard`:

```gdscript
signal target_hovered(actor: ActorCard)
signal target_unhovered(actor: ActorCard)


func _on_target_mouse_entered() -> void:
	target_hovered.emit(self)


func _on_target_mouse_exited() -> void:
	target_unhovered.emit(self)
```

Connect both `$Panel.mouse_entered` and `$Panel.mouse_exited` to these methods in both card scenes. Remove the enemy-only hover signals and callbacks after all callers migrate. Keep hero/enemy click signals unchanged.

- [ ] **Step 4: Relay common hover events through `BattleManager`**

At manager scope:

```gdscript
signal target_hovered(actor: ActorCard)
signal target_unhovered(actor: ActorCard)
```

When each hero and enemy is added, connect:

```gdscript
actor.target_hovered.connect(_on_target_hovered)
actor.target_unhovered.connect(_on_target_unhovered)
```

Relay without changing presentation in the manager:

```gdscript
func _on_target_hovered(actor: ActorCard) -> void:
	target_hovered.emit(actor)


func _on_target_unhovered(actor: ActorCard) -> void:
	target_unhovered.emit(actor)
```

Remove the old enemy-only preview callbacks once `BattleScene` owns the unified path.

- [ ] **Step 5: Handle pointer selection and CTB preview in `BattleScene`**

Connect the two manager signals in `_ready()`. Implement:

```gdscript
func _on_target_hovered(actor: ActorCard) -> void:
	if InputManager.get_active_mode() != InputManager.InputMode.KEYBOARD_MOUSE \
		or InputManager.get_presentation_mode() != InputManager.PresentationMode.POINTER \
		or not _is_targeting() \
		or not _is_valid_candidate(actor):
		return
	_set_current_target(actor)
	_refresh_target_preview()


func _on_target_unhovered(actor: ActorCard) -> void:
	if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and InputManager.get_presentation_mode() == InputManager.PresentationMode.POINTER \
		and actor == _current_target:
		_clear_current_target(true)
		_refresh_target_preview()


func _refresh_target_preview() -> void:
	if manager and is_instance_valid(manager.current_actor) and manager.current_action:
		manager.preview_action_turn_order(manager.current_actor, manager.current_action, _current_target)
```

Call `_refresh_target_preview()` at the end of `_set_current_target()` and `_clear_current_target()` instead of duplicating it in individual input handlers. Passing `null` intentionally retains self/action-wide CT changes while omitting selected-parent target changes.

- [ ] **Step 6: Run focused pointer, navigation, and full verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all commands exit 0; hero/enemy hover, mouse exit, CTB target changes, controller mouse-motion immunity, and first-click consumption are protected.

- [ ] **Step 7: Commit Task 3**

```bash
git add src/battle/actor_card.gd src/battle/hero_card.gd src/battle/enemy_card.gd src/battle/hero_card.tscn src/battle/enemy_card.tscn src/battle/battle_manager.gd src/battle/battle_scene.gd test/integration/test_battle_controller_navigation.gd
git commit -m "feat: synchronize pointer targets and CTB preview"
```

---

### Task 4: Group targets, cleanup, invalidation, and slide-only active hero

**Files:**
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: Tasks 1–3 semantic presentation, current-target ownership, and CTB refresh.
- Produces: `BattleManager.is_group_target_action(action: Action) -> bool`, `_apply_target_presentation(action: Action, targets: Array) -> void`, and complete lifecycle cleanup behavior.

- [ ] **Step 1: Add group, invalidation, cleanup, and hero-turn tests**

Add focused cases:

```gdscript
func test_all_enemy_action_selects_every_affected_card_and_requests_group_preview() -> void:
	var fixture := await _navigation_fixture()
	var action := Action.new()
	action.target_type = Action.TargetType.ALL_ENEMIES
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.manager._apply_target_presentation(action, [fixture.enemy, fixture.second_enemy])
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.second_enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.hero.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
	fixture.manager.current_actor = fixture.hero
	fixture.manager.current_action = action
	fixture.scene._refresh_target_preview()
	assert_eq(fixture.manager.preview_targets.size(), 1)
	assert_null(fixture.manager.preview_targets.back(), "group preview does not invent a single parent target")


func test_invalid_current_target_falls_back_for_controller_and_clears_for_pointer() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	fixture.enemy.is_defeated = true
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.second_enemy)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	fixture.second_enemy.is_defeated = true
	fixture.scene._refresh_targeting()
	assert_null(fixture.scene._current_target)


func test_cancel_and_teardown_return_all_cards_to_normal_and_stop_pulses() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	fixture.scene.cancel_targeting()
	for actor: ActorCard in [fixture.hero, fixture.enemy, fixture.second_enemy]:
		assert_eq(actor.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
		assert_null(actor._target_pulse_tween)


func test_active_hero_turn_uses_slide_without_turn_highlight() -> void:
	var hero := preload("res://src/battle/hero_card.tscn").instantiate() as HeroCard
	add_child_autofree(hero)
	await get_tree().process_frame
	await hero._slide_up()
	assert_eq(hero.panel.position, hero.panel_home_position + Vector2(0, hero.slide_offset_y))
	hero.highlight(true)
	assert_false(hero.highlight_panel.visible)
```

The recording manager assertion proves group entry requests CTB simulation immediately with no invented single target; the production `preview_action_turn_order()` continues to resolve the action-wide targets through `get_targets()`.

- [ ] **Step 2: Run affected integration scripts and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: nonzero exit because group targets still use availability presentation, invalidation does not implement both policies, and the hero still starts a blink tween.

- [ ] **Step 3: Add explicit group-action classification**

In `BattleManager`:

```gdscript
func is_group_target_action(action: Action) -> bool:
	return action != null and action.target_type in [
		Action.TargetType.ALL_ENEMIES,
		Action.TargetType.ALL_ALLIES,
		Action.TargetType.ALLIES_ONLY,
	]
```

In `set_current_action()`, assign `SELECTED` to the resolved targets of group actions and `AVAILABLE` to single-choice candidates. Do not classify `RANDOM_ENEMY` as every card being affected unless the current execution path resolves every enemy; preserve authored random semantics.

Extract that assignment into `_apply_target_presentation(action, targets)` so `set_current_action()` calls it after `get_targets()`, and the test can exercise the exact production classification without constructing the current-action detail panel.

`BattleScene` may retain one valid representative target for controller confirmation, but `_set_current_target()` must not demote any other group-selected card. Mouse exit must not clear group presentation or its CTB preview.

- [ ] **Step 4: Complete invalidation and lifecycle cleanup**

On targeting refresh:

```gdscript
if is_instance_valid(_current_target) and not _is_valid_candidate(_current_target):
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_restore_remembered_target()
	else:
		_clear_current_target(false)
```

Ensure cancel, execute, action replacement, turn end, actor death, `_exit_tree()`, and `_clear_all_targeting_ui()` call the semantic normal-state cleanup exactly once. Clear remembered references only when freed or invalid; retain valid battle-local memory between actions.

- [ ] **Step 5: Remove active-hero blinking while preserving slide and role update**

In `HeroCard`:

- remove `blink_tween`, `start_blinking()`, and `stop_blinking()`;
- remove the `start_blinking()` call from `shift_role()`;
- override `highlight(_value)` to keep `highlight_panel.visible = false`;
- leave `_slide_up()`, `_slide_down()`, role recoloring, and action-bar loading unchanged.

The target outline/pulse is independent and may still select the active hero for self/ally actions.

- [ ] **Step 6: Run focused, import, and complete verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all commands exit 0; there are no parser errors, unexpected failures, or target-presentation leaks.

- [ ] **Step 7: Commit Task 4**

```bash
git add src/battle/battle_manager.gd src/battle/battle_scene.gd src/battle/hero_card.gd test/integration/test_battle_controller_navigation.gd
git commit -m "feat: finish combat target lifecycle presentation"
```

---

### Task 5: Cross-system acceptance and manual documentation

**Files:**
- Modify: `test/integration/test_controller_playable_loop.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `docs/testing/controller-manual-checklist.md`

**Interfaces:**
- Consumes: complete Tasks 1–4 behavior.
- Produces: durable end-to-end acceptance and current manual visual/device checks; no new production API.

- [ ] **Step 1: Audit existing coverage before adding scenarios**

Map each final requirement to an existing test. Add only missing public-boundary coverage. Preserve focused tests for state transitions and use the playable loop for one composed controller flow rather than duplicating every lower-level case.

- [ ] **Step 2: Add one composed controller targeting sequence**

Extend `test_controller_playable_loop.gd` so the existing battle phase proves:

```gdscript
# After a single-target action is selected in controller mode:
assert_eq(first_valid.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
assert_eq(other_valid.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)

# Direction changes the selected target and confirm executes that actor once.
viewport.push_input(_joy_direction(JOY_BUTTON_DPAD_RIGHT, true))
await get_tree().process_frame
assert_eq(first_valid.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)
assert_eq(other_valid.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
viewport.push_input(_joy_confirm(true))
await get_tree().process_frame
assert_eq(execution_count, 1)
```

Use the existing fixture's real action-selection and execution seams. Pair every synthetic press with its release.

- [ ] **Step 3: Verify composed handoff coverage at the existing public boundaries**

Run `test_pointer_keyboard_controller_handoffs_preserve_one_logical_focus()` in `test_navigation_ux_layer.gd` for inert mouse motion, immediate keyboard handoff, and first-click consumption. Run the Task 2–3 battle cases for retained target origin, controller-owned hover rejection, and card presentation. Keep these cases split because the UX layer owns device handoff while the battle scene owns target semantics.

- [ ] **Step 4: Update the controller manual checklist**

Replace the generic battle target bullets with explicit unchecked acceptance:

```markdown
- [ ] During single-target selection, every valid hero/enemy card has a steady bright-white outline; invalid cards remain authored and unaffected.
- [ ] The current mouse, keyboard, or controller target keeps the white outline and adds a thicker breathing glow whose base outline never dims.
- [ ] Controller entry restores the last valid hero/enemy target or deterministic fallback; mouse/keyboard entry begins with no selected target.
- [ ] Moving the mouse off every card clears visible selection and target-dependent CTB preview; the next directional press restores the retained origin before a later press moves.
- [ ] Target changes with delay effects update the CTB preview immediately; all-target delay effects mark and preview every affected card.
- [ ] The active hero slides up without a blinking outline, and target cancellation/execution/defeat leaves no stale outline or glow.
```

Keep the hub redesign and hint-bar redesign deferred; do not add completed checkmarks.

- [ ] **Step 5: Run final focused verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: all commands exit 0 with no parser errors or unexpected diagnostics.

- [ ] **Step 6: Run final import, complete suite, and cleanup checks**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
rg -n 'start_flashing|stop_flashing|TargetFlash|blink_tween|start_blinking|stop_blinking' src/battle test --glob '*.gd' --glob '*.tscn'
```

Expected: import and suite exit 0; diff check is empty; removed actor-card target-flash and hero-blink symbols return no matches. Action-bar shift-panel flashing symbols may remain only if their names are distinct and unrelated to actor cards.

- [ ] **Step 7: Commit Task 5**

```bash
git add test/integration/test_controller_playable_loop.gd test/integration/test_battle_controller_navigation.gd docs/testing/controller-manual-checklist.md
git commit -m "test: cover combat target presentation loop"
```

## Final review and handoff

- Request a whole-range review against `docs/superpowers/specs/2026-07-14-combat-target-presentation-design.md`.
- Fix every Critical and Important finding, rerun the affected focused scripts, import, and complete suite, then request re-review.
- Perform physical mouse/keyboard and controller acceptance for outline brightness, pulse readability, CTB preview, last-target restoration, all-target presentation, active-hero slide, and rapid handoffs.
- Keep the branch alive for PR feedback or local integration according to the user's selected finishing option.
