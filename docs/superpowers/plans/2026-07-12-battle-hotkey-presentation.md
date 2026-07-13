# Battle Hotkey Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show `1–4` and `SHIFT` on battle controls in keyboard/mouse mode while preserving controller-family glyph textures and all existing battle input behavior.

**Architecture:** `InputIconMap` becomes the authoritative source for semantic keyboard labels. `DynamicGlyph` keeps its existing texture-button footprint, creates one centered child label, and switches exclusively between keyboard text and controller texture when input mode changes.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, existing controller SVG assets.

## Global Constraints

- Keyboard/mouse ability slots show exactly `1`, `2`, `3`, and `4`.
- Both shift controls show exactly `SHIFT` in keyboard/mouse mode.
- Controller mode continues using existing family-specific face-button and trigger textures.
- Exactly one presentation is visible: keyboard label or controller texture, never both.
- Disabled/unaffordable controls keep the hotkey visible at the existing 0.33 opacity.
- Mode and controller-family changes refresh immediately without moving or reflowing the action bar.
- Unknown actions clear both presentations and hide safely.
- Do not add image assets or parse `InputMap` display strings at runtime.
- Do not change battle bindings, execution, targeting, focus navigation, clicking, or cursor behavior.
- Keep the staged 1,000-XP hero changes staged and untouched; keep the generated GUT theme normalization unstaged.

---

### Task 1: Add Keyboard Labels to DynamicGlyph

**Files:**
- Modify: `src/singletons/input_map.gd`
- Modify: `src/battle/dynamic_glyph.gd`
- Test: `test/unit/test_input_icon_map.gd`
- Test: `test/unit/test_dynamic_glyph.gd`

**Interfaces:**
- Produces: `InputIconMap.get_keyboard_label(action: StringName) -> String`.
- Produces: `DynamicGlyph.keyboard_label: Label` after `_ready()` or `refresh()`.
- Preserves: `DynamicGlyph.refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType)`.

- [ ] **Step 1: Add failing keyboard-label map tests**

Add to `test/unit/test_input_icon_map.gd`:

```gdscript
func test_battle_keyboard_labels_match_live_bindings() -> void:
	assert_eq(InputIconMap.get_keyboard_label(&"action_1"), "1")
	assert_eq(InputIconMap.get_keyboard_label(&"action_2"), "2")
	assert_eq(InputIconMap.get_keyboard_label(&"action_3"), "3")
	assert_eq(InputIconMap.get_keyboard_label(&"action_4"), "4")
	assert_eq(InputIconMap.get_keyboard_label(&"shift_action"), "SHIFT")
	assert_eq(InputIconMap.get_keyboard_label(&"not_real"), "")
```

Rename `test_each_family_resolves_confirm_cancel_and_actions` to `test_each_controller_family_resolves_confirm_cancel_and_actions` and skip `ControllerType.KEYBOARD_MOUSE` inside its family loop. Add a separate assertion that keyboard confirm/cancel texture paths still resolve. This makes the existing test reflect the new split: controller combat actions use textures, keyboard combat actions use labels.

- [ ] **Step 2: Replace the obsolete non-controller DynamicGlyph test with presentation tests**

In `test/unit/test_dynamic_glyph.gd`, replace `test_non_controller_mode_hides_glyph` with:

```gdscript
func test_keyboard_mouse_mode_shows_label_without_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_true(glyph.visible)
	assert_true(glyph.keyboard_label.visible)
	assert_eq(glyph.keyboard_label.text, "2")
	assert_null(glyph.texture_normal)


func test_controller_mode_shows_texture_without_keyboard_label() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(true, InputIconMap.ControllerType.XBOX)
	assert_true(glyph.visible)
	assert_false(glyph.keyboard_label.visible)
	assert_not_null(glyph.texture_normal)


func test_shift_keyboard_label_fits_shared_presentation() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"shift_action")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_eq(glyph.keyboard_label.text, "SHIFT")
	assert_true(glyph.keyboard_label.visible)
```

Update the missing-action test to assert both representations are cleared:

```gdscript
assert_false(glyph.visible)
assert_false(glyph.keyboard_label.visible)
assert_null(glyph.texture_normal)
```

Update `test_input_manager_mode_signal_refreshes_glyph` so it uses `action_1`, begins in controller mode, then sends a keyboard event and asserts controller texture cleared plus keyboard text `1` visible. Add the inverse transition by sending a joypad event and asserting text hidden plus texture restored.

- [ ] **Step 3: Run focused unit tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dynamic_glyph -gexit
```

Expected: `get_keyboard_label` and `keyboard_label` do not exist, and keyboard mode still hides the control.

- [ ] **Step 4: Add the authoritative keyboard label map**

In `src/singletons/input_map.gd`, remove `action_1` through `action_4` from the `ControllerType.KEYBOARD_MOUSE` entry in `GLYPH_FILES`; retain its existing confirm and cancel textures. Add:

```gdscript
const KEYBOARD_LABELS := {
	&"action_1": "1",
	&"action_2": "2",
	&"action_3": "3",
	&"action_4": "4",
	&"shift_action": "SHIFT",
}


func get_keyboard_label(action: StringName) -> String:
	return KEYBOARD_LABELS.get(action, "")
```

Do not alter any controller-family mapping.

- [ ] **Step 5: Give DynamicGlyph one centered keyboard label**

Add:

```gdscript
var keyboard_label: Label


func _ensure_keyboard_label() -> void:
	if is_instance_valid(keyboard_label):
		return
	keyboard_label = Label.new()
	keyboard_label.name = "KeyboardLabel"
	keyboard_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keyboard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keyboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyboard_label.add_theme_font_size_override("font_size", 18)
	add_child(keyboard_label)
```

Call `_ensure_keyboard_label()` at the start of `_ready()` and `refresh()` so tests and runtime-created instances share one path.

Replace the presentation logic with:

```gdscript
func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	_ensure_keyboard_label()
	if show_controller_glyph:
		keyboard_label.hide()
		var glyph := InputIconMap.get_glyph(family, action)
		if glyph == null:
			_clear_presentation()
			return
		_set_texture(glyph)
		show()
		return

	_clear_texture()
	var label_text := InputIconMap.get_keyboard_label(action)
	if label_text.is_empty():
		_clear_presentation()
		return
	keyboard_label.text = label_text
	keyboard_label.show()
	show()


func _set_texture(glyph: Texture2D) -> void:
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph


func _clear_texture() -> void:
	texture_normal = null
	texture_pressed = null
	texture_disabled = null


func _clear_presentation() -> void:
	_clear_texture()
	keyboard_label.text = ""
	keyboard_label.hide()
	hide()
```

Remove the old `_clear_texture()` implementation that also hid the whole control. Keep signal connections and `_refresh_from_input_manager()` unchanged.

- [ ] **Step 6: Run focused units and confirm GREEN**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dynamic_glyph -gexit
```

Expected: exact labels pass; keyboard and controller presentations are mutually exclusive; mode and family refresh tests pass.

- [ ] **Step 7: Commit only Task 1 files**

```bash
git diff --check
git add src/singletons/input_map.gd src/battle/dynamic_glyph.gd test/unit/test_input_icon_map.gd test/unit/test_dynamic_glyph.gd
git commit --only src/singletons/input_map.gd src/battle/dynamic_glyph.gd test/unit/test_input_icon_map.gd test/unit/test_dynamic_glyph.gd -m "feat: show keyboard battle hotkeys"
```

Using `--only` is mandatory because the three 1,000-XP hero resources are already staged and must not enter this commit.

---

### Task 2: Verify Real Ability and Shift Presentations

**Files:**
- Modify: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: `InputIconMap.get_keyboard_label()` and `DynamicGlyph.keyboard_label` from Task 1.
- Verifies: four real `ActionButton` instances and both real `ActionBar` shift glyphs switch presentation without affecting input execution.

- [ ] **Step 1: Add real ability-slot presentation coverage**

Add:

```gdscript
func test_real_action_buttons_switch_between_keyboard_labels_and_controller_glyphs() -> void:
	InputManager._input(_pressed_joy_button())
	var buttons: Array[ActionButton] = []
	for index in 4:
		var button := ActionButtonScene.instantiate() as ActionButton
		button.glyph_action = StringName("action_%d" % (index + 1))
		add_child_autofree(button)
		buttons.append(button)
	await get_tree().process_frame

	InputManager._input(_pressed_key())
	for index in 4:
		assert_eq(buttons[index].dynamic_glyph.keyboard_label.text, str(index + 1))
		assert_true(buttons[index].dynamic_glyph.keyboard_label.visible)
		assert_null(buttons[index].dynamic_glyph.texture_normal)

	InputManager._input(_pressed_joy_button())
	for button: ActionButton in buttons:
		assert_false(button.dynamic_glyph.keyboard_label.visible)
		assert_not_null(button.dynamic_glyph.texture_normal)
```

Use an ordinary pressed key that does not activate a semantic battle action. Reuse or add `_pressed_key()` and `_pressed_joy_button()` helpers.

- [ ] **Step 2: Add real ActionBar shift coverage**

Instantiate `res://src/battle/action_bar.tscn` with a minimal `TrackingBattleManager` assigned before adding it to the tree:

```gdscript
func test_real_shift_controls_switch_between_shift_label_and_trigger() -> void:
	InputManager._input(_pressed_joy_button())
	var manager := TrackingBattleManager.new()
	add_child_autofree(manager)
	var bar := preload("res://src/battle/action_bar.tscn").instantiate() as ActionBar
	bar.battle_manager = manager
	add_child_autofree(bar)
	await get_tree().process_frame
	var shift_glyphs: Array[DynamicGlyph] = [
		bar.get_node("LeftShift/DynamicGlyph") as DynamicGlyph,
		bar.get_node("RightShift/DynamicGlyph") as DynamicGlyph,
	]

	InputManager._input(_pressed_key())
	for glyph: DynamicGlyph in shift_glyphs:
		assert_eq(glyph.keyboard_label.text, "SHIFT")
		assert_true(glyph.keyboard_label.visible)
		assert_null(glyph.texture_normal)

	InputManager._input(_pressed_joy_button())
	for glyph: DynamicGlyph in shift_glyphs:
		assert_false(glyph.keyboard_label.visible)
		assert_not_null(glyph.texture_normal)
```

If the minimal manager requires its `battle_state_changed` signal only, use the existing `TrackingBattleManager`; do not add production constructors or test-only hooks.

- [ ] **Step 3: Confirm disabled presentation remains dimmed in keyboard mode**

Extend `test_action_button_glyph_dims_with_disabled_state`:

```gdscript
InputManager._input(_pressed_key())
action_button.dynamic_glyph.set_action(&"action_1")
action_button.disabled = true
assert_true(action_button.dynamic_glyph.keyboard_label.visible)
assert_eq(action_button.dynamic_glyph.keyboard_label.text, "1")
assert_lt(action_button.dynamic_glyph.modulate.a, 1.0)
action_button.disabled = false
assert_eq(action_button.dynamic_glyph.modulate.a, 1.0)
```

- [ ] **Step 4: Run focused battle verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
```

Expected: real slots show `1–4` then controller textures; shift controls show `SHIFT` then triggers; disabled opacity passes; battle execution tests remain unchanged and green.

- [ ] **Step 5: Run editor and full-suite verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
git status --short
```

Expected: editor exits 0; the full suite has zero failing tests; no parser errors or crashes; staged hero resources remain staged and GUT theme remains unstaged.

- [ ] **Step 6: Commit only the integration test**

```bash
git add test/integration/test_battle_controller_navigation.gd
git commit --only test/integration/test_battle_controller_navigation.gd -m "test: cover battle hotkey presentation"
```

Using `--only` is mandatory so the staged XP resources remain outside the commit.
