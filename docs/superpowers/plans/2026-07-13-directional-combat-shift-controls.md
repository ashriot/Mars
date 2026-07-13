# Directional Combat Shift Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Give the left and right combat role cards independent L2/Q and R2/E inputs with matching Kenney glyphs.

**Architecture:** Replace the ambiguous combat-only shift_action input with shift_left and shift_right. InputIconMap remains the glyph lookup, while ActionBar owns card availability and translates each action into the existing shift_button_pressed(direction) signal.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, Kenney Input Prompts SVG assets.

## Global Constraints

- shift_left is keyboard Q plus the controller left trigger; shift_right is keyboard E plus the controller right trigger.
- A directional action activates only its matching visible, enabled card and never falls back.
- Both sides may activate when they intentionally display the same unlocked role.
- Existing mouse activation and embedded combat glyph presentation remain unchanged.
- The global action-hint panel remains hidden in combat.
- Preserve pre-existing uncommitted changes; stage only files named by the current task.
- Run automated Godot commands with HOME=/tmp/mars-godot-home.

---

### Task 1: Directional Input and Glyph Contract

**Files:**
- Create: assets/graphics/glyphs/keyboard_mouse/vector/keyboard_q.svg
- Create: assets/graphics/glyphs/keyboard_mouse/vector/keyboard_e.svg
- Modify: project.godot:184-189
- Modify: src/singletons/input_map.gd:20-66
- Modify: test/unit/test_glyph_assets.gd:3-15
- Modify: test/unit/test_input_icon_map.gd:10-36
- Modify: test/unit/test_input_manager.gd:266-276
- Modify: test/unit/test_dynamic_glyph.gd:49-55

**Interfaces:**
- Consumes: Godot InputMap, the upstream Kenney Q/E SVGs in /Users/adam/Downloads/kenney_input-prompts_1/Keyboard & Mouse/Vector/, and InputIconMap.get_glyph_path(type, action) -> String.
- Produces: shift_left and shift_right semantic actions and glyph mappings for every InputIconMap.ControllerType.

- [ ] **Step 1: Write the failing asset, binding, and glyph tests**

Update the curated keyboard list:

~~~gdscript
const BATTLE_KEYBOARD_GLYPHS := [
	"keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg",
	"keyboard_q.svg", "keyboard_e.svg",
]
~~~

Replace shift_action with shift_left and shift_right in test_required_semantic_actions_exist, then add:

~~~gdscript
func test_combat_shift_actions_use_directional_keys_and_triggers() -> void:
	assert_true(_has_physical_key(&"shift_left", KEY_Q))
	assert_true(_has_joy_axis(&"shift_left", JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_true(_has_physical_key(&"shift_right", KEY_E))
	assert_true(_has_joy_axis(&"shift_right", JOY_AXIS_TRIGGER_RIGHT, 1.0))
~~~

In test_input_icon_map.gd, include both new actions in the controller-family resource loop and use:

~~~gdscript
var expected := {
	&"action_1": "keyboard_1.svg",
	&"action_2": "keyboard_2.svg",
	&"action_3": "keyboard_3.svg",
	&"action_4": "keyboard_4.svg",
	&"shift_left": "keyboard_q.svg",
	&"shift_right": "keyboard_e.svg",
}
~~~

Replace the dynamic-glyph shift test with:

~~~gdscript
func test_directional_shift_keyboard_mode_uses_kenney_textures() -> void:
	glyph.set_action(&"shift_left")
	assert_true(glyph.texture_normal.resource_path.ends_with("keyboard_q.svg"))
	glyph.set_action(&"shift_right")
	assert_true(glyph.texture_normal.resource_path.ends_with("keyboard_e.svg"))
~~~

- [ ] **Step 2: Run the focused tests and verify RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dynamic_glyph -gexit
~~~

Expected: failures identify missing Q/E assets, absent semantic actions, and empty directional glyph paths.

- [ ] **Step 3: Restore the exact upstream Kenney assets**

Copy the unchanged source contents from:

~~~text
/Users/adam/Downloads/kenney_input-prompts_1/Keyboard & Mouse/Vector/keyboard_q.svg
/Users/adam/Downloads/kenney_input-prompts_1/Keyboard & Mouse/Vector/keyboard_e.svg
~~~

to the matching runtime filenames. Do not redraw them. Retain the .import sidecars Godot generates.

- [ ] **Step 4: Replace the shared project input action**

Replace the shift_action block in project.godot with:

~~~ini
shift_left={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":4,"axis_value":1.0,"script":null)
]
}
shift_right={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":5,"axis_value":1.0,"script":null)
]
}
~~~

- [ ] **Step 5: Add exact directional glyph mappings**

Preserve all other dictionary entries and replace shift_action as follows:

~~~gdscript
ControllerType.KEYBOARD_MOUSE: {&"shift_left": "keyboard_q.svg", &"shift_right": "keyboard_e.svg"}
ControllerType.XBOX: {&"shift_left": "xbox_lt.svg", &"shift_right": "xbox_rt.svg"}
ControllerType.PLAYSTATION: {&"shift_left": "playstation_trigger_l2.svg", &"shift_right": "playstation_trigger_r2.svg"}
ControllerType.NINTENDO_SWITCH: {&"shift_left": "switch_button_zl.svg", &"shift_right": "switch_button_zr.svg"}
ControllerType.NINTENDO_SWITCH_2: {&"shift_left": "switch_button_zl.svg", &"shift_right": "switch_button_zr.svg"}
ControllerType.STEAM_CONTROLLER: {&"shift_left": "controller_button_l2.svg", &"shift_right": "controller_button_r2.svg"}
ControllerType.STEAM_DECK: {&"shift_left": "steamdeck_button_l2.svg", &"shift_right": "steamdeck_button_r2.svg"}
~~~

- [ ] **Step 6: Run the Step 2 command and verify GREEN**

Expected: all four selected suites pass and both new SVGs resolve through ResourceLoader.

- [ ] **Step 7: Commit the input contract**

~~~bash
git add project.godot src/singletons/input_map.gd test/unit/test_glyph_assets.gd test/unit/test_input_icon_map.gd test/unit/test_input_manager.gd test/unit/test_dynamic_glyph.gd assets/graphics/glyphs/keyboard_mouse/vector/keyboard_q.svg assets/graphics/glyphs/keyboard_mouse/vector/keyboard_q.svg.import assets/graphics/glyphs/keyboard_mouse/vector/keyboard_e.svg assets/graphics/glyphs/keyboard_mouse/vector/keyboard_e.svg.import
git commit -m "feat: add directional combat shift inputs"
~~~

### Task 2: Deterministic Action-Bar Routing

**Files:**
- Modify: src/battle/action_bar.gd:163-193
- Modify: src/battle/action_bar.tscn:370-384,484-501
- Modify: test/integration/test_battle_controller_navigation.gd:102-122,342-367

**Interfaces:**
- Consumes: shift_left, shift_right, Task 1 glyph mappings, and shift_button_pressed(direction: String).
- Produces: ActionBar.activate_shift(direction: String) -> bool.

- [ ] **Step 1: Write the failing routing test**

Replace the existing shared-direction test with:

~~~gdscript
func test_directional_shift_actions_activate_only_their_matching_available_side() -> void:
	var bar := ActionBar.new()
	bar.buttons_disabled = false
	bar.sliding = false
	bar.left_shift_ui = Control.new()
	bar.right_shift_ui = Control.new()
	bar.left_shift_button = Button.new()
	bar.right_shift_button = Button.new()
	bar.add_child(bar.left_shift_ui)
	bar.add_child(bar.right_shift_ui)
	bar.left_shift_ui.add_child(bar.left_shift_button)
	bar.right_shift_ui.add_child(bar.right_shift_button)
	autofree(bar)
	watch_signals(bar)

	bar._unhandled_input(_action_event(&"shift_left"))
	assert_signal_emitted_with_parameters(bar, "shift_button_pressed", ["left"])
	bar._unhandled_input(_action_event(&"shift_right"))
	assert_signal_emitted_with_parameters(bar, "shift_button_pressed", ["right"])
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "both cards may show the same role")

	bar.left_shift_ui.visible = false
	bar._unhandled_input(_action_event(&"shift_left"))
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "left never falls back to right")
	bar.right_shift_button.disabled = true
	bar._unhandled_input(_action_event(&"shift_right"))
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "right never falls back to left")
~~~

Update the real shift-glyph test to assert:

~~~gdscript
InputManager._input(_pressed_key())
assert_eq(left_glyph.texture_normal.resource_path.get_file(), "keyboard_q.svg")
assert_eq(right_glyph.texture_normal.resource_path.get_file(), "keyboard_e.svg")

InputManager._input(_pressed_joy_button())
assert_same(left_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"shift_left"))
assert_same(right_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"shift_right"))
~~~

- [ ] **Step 2: Run the battle suite and verify RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
~~~

Expected: new semantic events do not emit shifts and both scene glyphs still reference the removed shared action.

- [ ] **Step 3: Implement directional activation**

Replace the shared action branch and _available_shift_direction with:

~~~gdscript
	if event.is_action_pressed(&"shift_left"):
		if activate_shift("left") and is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"shift_right"):
		if activate_shift("right") and is_inside_tree():
			get_viewport().set_input_as_handled()
		return


func activate_shift(direction: String) -> bool:
	var shift_ui: Control = left_shift_ui if direction == "left" else right_shift_ui if direction == "right" else null
	var shift_button: Button = left_shift_button if direction == "left" else right_shift_button if direction == "right" else null
	if shift_ui == null or not shift_ui.visible or shift_button == null or shift_button.disabled:
		return false
	_on_shift_button_pressed(direction)
	return true
~~~

- [ ] **Step 4: Wire the two scene glyphs**

~~~ini
[node name="DynamicGlyph" type="TextureButton" parent="LeftShift"]
action = &"shift_left"

[node name="DynamicGlyph" type="TextureButton" parent="RightShift"]
action = &"shift_right"
~~~

- [ ] **Step 5: Run battle and playable-loop verification**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
~~~

Expected: both suites pass, embedded glyphs work, and the global combat hint bar remains empty.

- [ ] **Step 6: Run full verification**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
~~~

Expected: import exits 0, all GUT tests pass, and diff check exits 0. Documented macOS certificate and Godot shutdown leak diagnostics are accepted only when test counts and exit status are successful.

- [ ] **Step 7: Perform manual DualSense acceptance**

1. Verify left and right cards display L2 and R2.
2. Verify L2 activates only the left role and R2 only the right role.
3. With one additional role mirrored on both sides, verify either trigger reaches it.
4. In keyboard/mouse mode, verify Q/E glyphs and matching activation.
5. Verify clicking either role card still works.

- [ ] **Step 8: Commit after manual acceptance**

The integration test already contains an approved uncommitted hint-panel regression. Review the complete diff before staging and keep that fix intact:

~~~bash
git diff -- src/battle/action_bar.gd src/battle/action_bar.tscn test/integration/test_battle_controller_navigation.gd
git add src/battle/action_bar.gd src/battle/action_bar.tscn test/integration/test_battle_controller_navigation.gd
git commit -m "fix: align combat controls with embedded glyphs"
~~~
