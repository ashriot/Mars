# Terminal UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the small RichText-link terminal with a large, responsive command-line modal whose semantic hotkeys, clickable rows, and guarded extraction flow remain readable and reliable at 1200×800.

**Architecture:** `Terminal` remains the modal and interaction-state owner and preserves its existing `option_selected(choice_id)` and `closed` boundaries. A focused `TerminalProtocolRow` component owns one row's text, dynamic glyph, focus presentation, and activation signal; `InputManager` and `InputIconMap` remain the global input-mode and glyph-family authorities.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` scenes, retained Kenney SVG input glyphs, NavigationUXLayer, and GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3; do not run this plan with Godot 4.7.
- Run every automated test with `HOME=/tmp/mars-godot-home` so tests cannot read or write normal save data.
- Treat 1200×800 as the minimum acceptance viewport and also verify 1280×800 and 1920×1080 manually.
- Preserve existing protocol effects, upgrades, scan behavior, extraction rewards, GameManager routing, terminal payloads, and save formats.
- Keep the command-line visual language; do not replace the terminal with conventional cards.
- Keep the currently disabled CRT overlay disabled during this implementation.
- Use semantic actions and `InputIconMap`; do not inspect raw controller buttons inside terminal runtime code.
- Preserve required Godot `.uid` and `.import` sidecars generated for changed or new source assets.
- Execute in an isolated worktree because the primary worktree contains unrelated user changes; do not stage, restore, or commit those changes.

---

## File Structure

- `src/singletons/input_map.gd` — map five terminal-specific semantic actions to keyboard and controller-family glyphs.
- `src/singletons/input_manager.gd` — classify terminal shortcuts as navigation-style input and keep Security on the active family's confirm-position button.
- `project.godot` — bind keyboard 1–5 and the terminal-specific controller layout.
- `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg` — retained keyboard prompt needed by the new semantic action.
- `src/map/terminal_protocol_row.gd` and `src/map/terminal_protocol_row.tscn` — reusable terminal-styled row control.
- `src/map/terminal.gd` and `src/map/terminal.tscn` — responsive modal layout, protocol definitions, typing/ready/extraction/closing state machine, and modal ownership.
- Focused unit tests protect input/glyph resolution, row behavior, and terminal state transitions.
- Existing integration tests protect modal focus, map restoration, full controller routing, and terminal extraction behavior.
- `docs/testing/controller-manual-checklist.md` — handheld terminal acceptance steps.

---

### Task 1: Add the Terminal-Specific Semantic Inputs and Glyphs

**Files:**
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg`
- Modify: `project.godot:54-186`
- Modify: `src/singletons/input_map.gd:15-68`
- Modify: `src/singletons/input_manager.gd:10-18`
- Test: `test/unit/test_glyph_assets.gd`
- Test: `test/unit/test_input_icon_map.gd`
- Test: `test/unit/test_input_manager.gd`

**Interfaces:**
- Consumes: Godot `InputMap`, `InputIconMap.get_glyph_path(type, action) -> String`, the active-family confirm/cancel mapping, and retained L1/LB and R1/RB glyphs.
- Produces: `&"terminal_security"` (1 + confirm-position face button), `&"terminal_scan"` (2 + left shoulder), `&"terminal_medical"` (3 + left face button), `&"terminal_finance"` (4 + top face button), and `&"terminal_extract"` (5 + right shoulder). Existing `&"cancel"` remains Escape + Circle/B.

- [ ] **Step 1: Write the failing glyph and input tests**

Extend `test/unit/test_glyph_assets.gd`:

```gdscript
const TERMINAL_KEYBOARD_GLYPHS := ["keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg", "keyboard_5.svg"]

func test_terminal_keyboard_glyph_sources_are_curated() -> void:
	for file_name: String in TERMINAL_KEYBOARD_GLYPHS:
		assert_true(
			FileAccess.file_exists("res://assets/graphics/glyphs/keyboard_mouse/vector/%s" % file_name),
			file_name,
		)
```

Extend `test/unit/test_input_icon_map.gd`:

```gdscript
func test_terminal_actions_resolve_keyboard_and_every_controller_family() -> void:
	var actions: Array[StringName] = [&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance", &"terminal_extract"]
	var keyboard_files := ["keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg", "keyboard_5.svg"]
	for index in actions.size():
		assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.KEYBOARD_MOUSE, actions[index]).ends_with(keyboard_files[index]))
	for family in InputIconMap.runtime_controller_types():
		if family == InputIconMap.ControllerType.KEYBOARD_MOUSE:
			continue
		for action: StringName in actions:
			var path := InputIconMap.get_glyph_path(family, action)
			assert_ne(path, "", "%s %s" % [family, action])
			assert_true(ResourceLoader.exists(path), path)

func test_terminal_controller_glyphs_match_behavior_groups() -> void:
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.PLAYSTATION, &"terminal_security").ends_with("playstation_button_cross.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.PLAYSTATION, &"terminal_scan").ends_with("playstation_trigger_l1.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.PLAYSTATION, &"terminal_medical").ends_with("playstation_button_square.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.PLAYSTATION, &"terminal_finance").ends_with("playstation_button_triangle.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.PLAYSTATION, &"terminal_extract").ends_with("playstation_trigger_r1.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.NINTENDO_SWITCH, &"terminal_security").ends_with("switch_button_a.svg"))
	assert_true(InputIconMap.get_glyph_path(InputIconMap.ControllerType.NINTENDO_SWITCH, &"cancel").ends_with("switch_button_b.svg"))
```

Extend `test/unit/test_input_manager.gd`:

```gdscript
var original_terminal_security_events: Array[InputEvent]

# Append to before_each():
original_terminal_security_events = InputMap.action_get_events(&"terminal_security")

# Append to after_each():
_restore_action(&"terminal_security", original_terminal_security_events)

func _joy_button_for(action: StringName) -> JoyButton:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return JOY_BUTTON_INVALID

func test_terminal_actions_use_numbers_shoulders_and_non_cancel_face_buttons() -> void:
	var expected := {
		&"terminal_security": [KEY_1, JOY_BUTTON_A],
		&"terminal_scan": [KEY_2, JOY_BUTTON_LEFT_SHOULDER],
		&"terminal_medical": [KEY_3, JOY_BUTTON_X],
		&"terminal_finance": [KEY_4, JOY_BUTTON_Y],
		&"terminal_extract": [KEY_5, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: StringName in expected:
		var events := InputMap.action_get_events(action)
		assert_eq(events.filter(func(event): return event is InputEventKey and event.physical_keycode == expected[action][0]).size(), 1, str(action))
		assert_eq(events.filter(func(event): return event is InputEventJoypadButton and event.button_index == expected[action][1]).size(), 1, str(action))

func test_nintendo_rebinds_terminal_security_to_a_and_keeps_b_as_cancel() -> void:
	manager._set_active_controller_type(InputIconMap.ControllerType.NINTENDO_SWITCH)
	assert_eq(_joy_button_for(&"terminal_security"), JOY_BUTTON_B)
	assert_eq(_joy_button_for(&"cancel"), JOY_BUTTON_A)

func test_terminal_extraction_keyboard_shortcut_selects_snapped_keyboard_mode() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.FREE)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_5
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)

func test_required_semantic_actions_exist() -> void:
	for action in [
		&"nav_up", &"nav_down", &"nav_left", &"nav_right", &"confirm", &"cancel",
		&"page_previous", &"page_next", &"section_previous", &"section_next",
		&"action_1", &"action_2", &"action_3", &"action_4", &"shift_left", &"shift_right",
		&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance", &"terminal_extract",
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down",
		&"zoom_in", &"zoom_out", &"recenter", &"refund_progression",
	]:
		assert_true(InputMap.has_action(action), str(action))
```

- [ ] **Step 2: Run the focused tests and verify they fail for the missing action and glyph**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: the new assertions fail because `keyboard_5.svg` and the five terminal-specific actions do not exist.

- [ ] **Step 3: Add the keyboard glyph source**

Create `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg` with the same 64×64 keycap geometry as the retained 1–4 glyphs:

```svg
<svg width="64" height="64" xmlns="http://www.w3.org/2000/svg">
  <g>
    <path stroke="none" fill="#FFFFFF" d="M16 8 L48 8 Q56 8 56 16 L56 48 Q56 56 48 56 L16 56 Q8 56 8 48 L8 16 Q8 8 16 8 M27 23 L39 23 39 27 31 27 31 31 35 31 Q40 31 40 36 40 41 35 41 L27 41 27 37 34 37 Q36 37 36 35 36 33 34 33 L27 33 27 23"/>
  </g>
</svg>
```

Run a headless editor import so Godot creates `keyboard_5.svg.import`:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path "$PWD" --quit
```

- [ ] **Step 4: Add semantic mappings and bindings**

Merge these five entries into each corresponding family in `InputIconMap.GLYPH_FILES`:

```gdscript
var terminal_glyph_files := {
	ControllerType.KEYBOARD_MOUSE: { &"terminal_security": "keyboard_1.svg", &"terminal_scan": "keyboard_2.svg", &"terminal_medical": "keyboard_3.svg", &"terminal_finance": "keyboard_4.svg", &"terminal_extract": "keyboard_5.svg" },
	ControllerType.XBOX: { &"terminal_security": "xbox_button_a.svg", &"terminal_scan": "xbox_lb.svg", &"terminal_medical": "xbox_button_x.svg", &"terminal_finance": "xbox_button_y.svg", &"terminal_extract": "xbox_rb.svg" },
	ControllerType.PLAYSTATION: { &"terminal_security": "playstation_button_cross.svg", &"terminal_scan": "playstation_trigger_l1.svg", &"terminal_medical": "playstation_button_square.svg", &"terminal_finance": "playstation_button_triangle.svg", &"terminal_extract": "playstation_trigger_r1.svg" },
	ControllerType.NINTENDO_SWITCH: { &"terminal_security": "switch_button_a.svg", &"terminal_scan": "switch_button_l.svg", &"terminal_medical": "switch_button_y.svg", &"terminal_finance": "switch_button_x.svg", &"terminal_extract": "switch_button_r.svg" },
	ControllerType.NINTENDO_SWITCH_2: { &"terminal_security": "switch_button_a.svg", &"terminal_scan": "switch_button_l.svg", &"terminal_medical": "switch_button_y.svg", &"terminal_finance": "switch_button_x.svg", &"terminal_extract": "switch_button_r.svg" },
	ControllerType.STEAM_CONTROLLER: { &"terminal_security": "steam_button_a.svg", &"terminal_scan": "controller_button_l1.svg", &"terminal_medical": "steam_button_x.svg", &"terminal_finance": "steam_button_y.svg", &"terminal_extract": "controller_button_r1.svg" },
	ControllerType.STEAM_DECK: { &"terminal_security": "steamdeck_button_a.svg", &"terminal_scan": "steamdeck_button_l1.svg", &"terminal_medical": "steamdeck_button_x.svg", &"terminal_finance": "steamdeck_button_y.svg", &"terminal_extract": "steamdeck_button_r1.svg" },
}
```

Add all five terminal actions to `InputManager.NAVIGATION_ACTIONS`.

Add these five InputMap blocks after `action_4` in `project.godot`:

```ini
terminal_security={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":49,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":0,"pressure":0.0,"pressed":false,"script":null)
]
}
terminal_scan={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":50,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":9,"pressure":0.0,"pressed":false,"script":null)
]
}
terminal_medical={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":51,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":2,"pressure":0.0,"pressed":false,"script":null)
]
}
terminal_finance={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":52,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":3,"pressure":0.0,"pressed":false,"script":null)
]
}
terminal_extract={
"deadzone": 0.25,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":53,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":10,"pressure":0.0,"pressed":false,"script":null)
]
}
```

Extend `InputManager._apply_family_bindings()` so Security follows the same family-dependent physical position as Confirm:

```gdscript
func _apply_family_bindings(type: InputIconMap.ControllerType) -> void:
	var bindings := InputIconMap.confirm_cancel_buttons(type)
	bindings[&"terminal_security"] = bindings[&"confirm"]
	for action: StringName in bindings:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = bindings[action] as JoyButton
		InputMap.action_add_event(action, joy_event)
```

- [ ] **Step 5: Run focused tests and verify they pass**

Run the three commands from Step 2.

Expected: all selected scripts pass; no missing-glyph, missing-action, or parse error appears.

- [ ] **Step 6: Commit the semantic input slice**

```bash
git add project.godot src/singletons/input_map.gd src/singletons/input_manager.gd \
  assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg \
  assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg.import \
  test/unit/test_glyph_assets.gd test/unit/test_input_icon_map.gd test/unit/test_input_manager.gd
git commit -m "feat: add terminal protocol inputs"
```

---

### Task 2: Build the Terminal Protocol Row Component

**Files:**
- Create: `src/map/terminal_protocol_row.gd`
- Create: `src/map/terminal_protocol_row.gd.uid` through Godot import
- Create: `src/map/terminal_protocol_row.tscn`
- Create: `test/unit/test_terminal_protocol_row.gd`
- Create: `test/unit/test_terminal_protocol_row.gd.uid` through Godot import

**Interfaces:**
- Consumes: `DynamicGlyph.set_action(new_action: StringName) -> void` and the existing SUSE Mono font resources.
- Produces: `TerminalProtocolRow.configure(choice_id: StringName, action: StringName, title: String, outcome: String, upgraded: bool) -> void`, `TerminalProtocolRow.set_interactable(enabled: bool) -> void`, getters `get_choice_id() -> StringName` and `get_action() -> StringName`, and signal `activated(choice_id: StringName)`.

- [ ] **Step 1: Write the failing row-component tests**

Create `test/unit/test_terminal_protocol_row.gd`:

```gdscript
extends GutTest

const RowScene := preload("res://src/map/terminal_protocol_row.tscn")

func _row() -> TerminalProtocolRow:
	var row := RowScene.instantiate() as TerminalProtocolRow
	add_child_autofree(row)
	return row

func test_configure_sets_stable_identity_text_upgrade_and_semantic_glyph() -> void:
	var row := _row()
	row.configure(&"opt_fin_up", &"terminal_finance", "INTERCEPT PAYMENT", "+10.0 BITS", true)
	assert_eq(row.get_choice_id(), &"opt_fin_up")
	assert_eq(row.get_action(), &"terminal_finance")
	assert_eq(row.title_label.text, "INTERCEPT PAYMENT")
	assert_eq(row.outcome_label.text, "+10.0 BITS")
	assert_true(row.upgraded_label.visible)
	assert_eq(row.glyph.action, &"terminal_finance")

func test_press_emits_choice_once_and_disabled_row_is_inert() -> void:
	var row := _row()
	row.configure(&"opt_scan", &"terminal_scan", "HIJACK LOCAL FEED", "SECTOR SCAN", false)
	watch_signals(row)
	row.emit_signal(&"pressed")
	assert_signal_emitted_with_parameters(row, "activated", [&"opt_scan"])
	row.set_interactable(false)
	row.emit_signal(&"pressed")
	assert_signal_emit_count(row, "activated", 1)
	assert_true(row.disabled)

func test_focus_presentation_uses_terminal_caret_without_toggle_state() -> void:
	var row := _row()
	row.grab_focus()
	await get_tree().process_frame
	assert_true(row.caret_label.visible)
	row.release_focus()
	await get_tree().process_frame
	assert_false(row.caret_label.visible)
```

- [ ] **Step 2: Run the row test and verify it fails because the component does not exist**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
```

Expected: FAIL while loading the missing scene/script.

- [ ] **Step 3: Implement the row script**

Create `src/map/terminal_protocol_row.gd`:

```gdscript
extends Button
class_name TerminalProtocolRow

signal activated(choice_id: StringName)

@onready var caret_label: Label = %Caret
@onready var glyph: DynamicGlyph = %DynamicGlyph
@onready var title_label: Label = %Title
@onready var upgraded_label: Label = %Upgraded
@onready var outcome_label: Label = %Outcome

var _choice_id: StringName
var _action: StringName

func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_entered.connect(_refresh_focus_presentation)
	focus_exited.connect(_refresh_focus_presentation)
	_refresh_focus_presentation()

func configure(choice_id: StringName, action: StringName, title: String, outcome: String, upgraded: bool) -> void:
	_choice_id = choice_id
	_action = action
	title_label.text = title
	outcome_label.text = outcome
	upgraded_label.visible = upgraded
	glyph.set_action(action)

func set_interactable(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func get_choice_id() -> StringName:
	return _choice_id

func get_action() -> StringName:
	return _action

func _on_pressed() -> void:
	if not disabled:
		activated.emit(_choice_id)

func _refresh_focus_presentation() -> void:
	if is_node_ready():
		caret_label.visible = has_focus()
```

- [ ] **Step 4: Build the row scene**

Create `src/map/terminal_protocol_row.tscn` with this exact hierarchy:

```text
TerminalProtocolRow (Button, script terminal_protocol_row.gd, minimum 0×72, focus all, flat)
└── Margin (MarginContainer, mouse ignore, full rect, 12px horizontal / 8px vertical)
    └── Content (HBoxContainer, separation 12)
        ├── Caret (Label, unique name, text "›", minimum width 24, initially hidden)
        ├── DynamicGlyph (DynamicGlyph, unique name, 48×48, mouse ignore)
        ├── Title (Label, unique name, SUSE Mono Bold, font size 34, expand horizontally)
        ├── Upgraded (Label, unique name, text "[UPGRADED]", gold, font size 22)
        └── Outcome (Label, unique name, SUSE Mono, font size 26, right aligned)
```

Give the root Button transparent normal/hover/pressed styleboxes. Give `focus` a `StyleBoxFlat` with a translucent orange background, 2-pixel orange border, 6-pixel left inset border, and 6-pixel corner radii. Set every child to `MOUSE_FILTER_IGNORE` so the root owns clicking.

- [ ] **Step 5: Import, run the row tests, and verify they pass**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path "$PWD" --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
```

Expected: 3/3 row tests pass, generated `.uid` sidecars exist, and no missing-node error appears.

- [ ] **Step 6: Commit the reusable row**

```bash
git add src/map/terminal_protocol_row.gd src/map/terminal_protocol_row.gd.uid \
  src/map/terminal_protocol_row.tscn test/unit/test_terminal_protocol_row.gd \
  test/unit/test_terminal_protocol_row.gd.uid
git commit -m "feat: add terminal protocol row"
```

---

### Task 3: Replace RichText Links with the Responsive Terminal State Machine

**Files:**
- Modify: `src/map/terminal.gd`
- Modify: `src/map/terminal.tscn`
- Rewrite focused expectations: `test/unit/test_terminal.gd`

**Interfaces:**
- Consumes: `TerminalProtocolRow` from Task 2, semantic actions `terminal_security`, `terminal_scan`, `terminal_medical`, `terminal_finance`, `terminal_extract`, `confirm`, and `cancel`, and the existing `NavigationUXLayer.push_modal/pop_modal` API.
- Produces: `Terminal.TerminalState { TYPING, READY, CONFIRMING_EXTRACTION, CLOSING }`, `setup(data: Dictionary) -> bool`, `handle_semantic_action(action: StringName) -> bool`, `finish_typing() -> void`, `get_protocol_row(index: int) -> TerminalProtocolRow`, and preserved signals `option_selected(choice_id: StringName)` and `closed`.

- [ ] **Step 1: Replace link-oriented unit assertions with failing structured-state tests**

Keep the existing `_terminal()` fixture, add `await get_tree().process_frame` after `setup()`, and replace RichText-link assertions with:

```gdscript
func _payload(upgrade_key: String = "", facility: String = "TEST", bits: int = 12, alert: int = 10) -> Dictionary:
	return {
		"upgrade_key": upgrade_key,
		"bits": bits,
		"alert": alert,
		"facility_name": facility,
		"session_id": "TEST-SESSION",
	}

func test_setup_configures_five_structured_rows_and_one_upgrade() -> void:
	for upgrade_key in ["", "security", "scan", "medical", "finance"]:
		var terminal := _terminal(upgrade_key)
		var ids: Array[StringName] = []
		var upgraded_count := 0
		for index in 5:
			var row := terminal.get_protocol_row(index)
			ids.append(row.get_choice_id())
			upgraded_count += int(row.upgraded_label.visible)
		assert_eq(ids.size(), 5)
		assert_eq(ids.duplicate().reduce(func(unique, id): return unique + int(ids.count(id) == 1), 0), 5)
		assert_eq(upgraded_count, 0 if upgrade_key.is_empty() else 1)
		terminal.free()

func test_first_protocol_input_during_typing_only_finishes_animation() -> void:
	var terminal := _terminal()
	watch_signals(terminal)
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_true(terminal.handle_semantic_action(&"terminal_security"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"terminal_security"))
	assert_signal_emitted_with_parameters(terminal, "option_selected", [&"opt_sec"])

func test_protocols_one_through_four_execute_immediately_and_exactly_once() -> void:
	for index in 4:
		var terminal := _terminal()
		terminal.finish_typing()
		watch_signals(terminal)
		assert_true(terminal.handle_semantic_action([&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance"][index]))
		assert_signal_emit_count(terminal, "option_selected", 1)
		assert_eq(terminal.interaction_state, terminal.TerminalState.CLOSING)
		terminal.handle_semantic_action(&"terminal_security")
		assert_signal_emit_count(terminal, "option_selected", 1)
		terminal.free()

func test_extraction_requires_confirm_and_cancel_returns_to_ready() -> void:
	var terminal := _terminal()
	terminal.finish_typing()
	watch_signals(terminal)
	assert_true(terminal.handle_semantic_action(&"terminal_extract"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.CONFIRMING_EXTRACTION)
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"terminal_scan"))
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"cancel"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
	assert_true(terminal.handle_semantic_action(&"terminal_extract"))
	assert_true(terminal.handle_semantic_action(&"confirm"))
	assert_signal_emitted_with_parameters(terminal, "option_selected", [&"opt_extract"])
	assert_eq(terminal.interaction_state, terminal.TerminalState.CLOSING)

func test_setup_resets_confirmation_typing_and_one_shot_state() -> void:
	var terminal := _terminal()
	terminal.finish_typing()
	terminal.handle_semantic_action(&"terminal_extract")
	terminal.setup(_payload("medical", "SECOND", 25, 15))
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_false(terminal.confirmation_panel.visible)
	assert_eq(terminal.get_protocol_row(2).get_choice_id(), &"opt_med_up")
	assert_false(terminal.close_button.disabled)

func test_incomplete_presentation_data_disables_every_protocol_but_can_close() -> void:
	var terminal := TerminalScene.instantiate()
	add_child_autofree(terminal)
	assert_false(terminal.setup({"facility_name": "BROKEN"}))
	for index in 5:
		assert_true(terminal.get_protocol_row(index).disabled)
	assert_false(terminal.close_button.disabled)
	watch_signals(terminal)
	assert_true(terminal.handle_semantic_action(&"cancel"))
	await get_tree().create_timer(0.3).timeout
	assert_signal_emit_count(terminal, "closed", 1)
```

Retain and adapt the existing repeated-close and in-flight-setup tests so they activate rows or `handle_semantic_action()` instead of calling `_on_text_link_clicked()`.

- [ ] **Step 2: Run the terminal unit tests and verify the new state tests fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
```

Expected: failures mention missing `TerminalState`, `get_protocol_row`, `finish_typing`, and the new scene nodes.

- [ ] **Step 3: Rebuild the terminal scene as a full-viewport responsive modal**

Replace the fixed-offset scene with this hierarchy:

```text
Terminal (Control, full rect, script terminal.gd)
├── Backdrop (ColorRect, full rect, black alpha 0.55, mouse stop)
└── Panel (Panel, anchors 0.045/0.05/0.955/0.95, minimum 1080×720)
    ├── Header (ColorRect, top full width, height 76)
    │   ├── HeaderText (Label, SUSE Mono Bold, 34)
    │   └── CloseButton (TextureButton, top right, 52×52, source assets/graphics/icons/map/cancel.png)
    ├── BodyMargin (MarginContainer, below header, 38px horizontal / 28px vertical)
    │   └── Body (VBoxContainer)
    │       ├── Status (Label, SUSE Mono, 24)
    │       ├── Prompt (Label, SUSE Mono Bold, 28)
    │       └── Protocols (VBoxContainer, separation 8)
    │           ├── Security (TerminalProtocolRow instance)
    │           ├── Scan (TerminalProtocolRow instance)
    │           ├── Medical (TerminalProtocolRow instance)
    │           ├── Finance (TerminalProtocolRow instance)
    │           └── Extraction (TerminalProtocolRow instance)
    ├── Footer (HBoxContainer, bottom, 32px margins)
    │   ├── TraceWarning (Label, expand)
    │   └── ContextText (Label)
    └── ConfirmationPanel (PanelContainer, centered, hidden)
        └── ConfirmationContent (VBoxContainer)
            ├── Warning (Label, "WARNING: ABANDON CURRENT RUN?")
            ├── Consequence (Label, tactical-retreat copy)
            └── ConfirmationActions (HBoxContainer)
                ├── ConfirmButton (Button containing DynamicGlyph confirm + label)
                └── CancelButton (Button containing DynamicGlyph cancel + label)
```

Keep the existing orange/brown panel style, increase its border to 10–12 logical pixels, and ensure the five 72-pixel rows plus header/footer fit inside 720 logical pixels. Remove the RichTextLabel link interaction and leave `TerminalFilter.visible = false` if retaining the shader node.

- [ ] **Step 4: Implement structured definitions and state routing in `terminal.gd`**

Use these declarations and semantic routing boundaries:

```gdscript
extends Control

signal option_selected(choice_id: StringName)
signal closed

enum TerminalState { TYPING, READY, CONFIRMING_EXTRACTION, CLOSING }

const PROTOCOL_ACTIONS: Array[StringName] = [&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance"]
const EXTRACTION_ACTION := &"terminal_extract"
const EXTRACTION_ID := &"opt_extract"

@onready var close_button: TextureButton = %CloseButton
@onready var protocols: VBoxContainer = %Protocols
@onready var confirmation_panel: Control = %ConfirmationPanel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var header_text: Label = %HeaderText
@onready var status_label: Label = %Status

var interaction_state := TerminalState.TYPING
var type_tween: Tween
var close_tween: Tween
var _lifecycle_generation := 0
var _rows: Array[TerminalProtocolRow] = []
var _typing_labels: Array[Label] = []
```

Build definitions with one helper that preserves all current IDs and values:

```gdscript
func _protocol_definitions(data: Dictionary) -> Array[Dictionary]:
	var upgrade_key: String = data.upgrade_key
	return [
		{ id = &"opt_sec_up" if upgrade_key == "security" else &"opt_sec", action = &"terminal_security", title = "REBOOT SECURITY" if upgrade_key == "security" else "SCRAMBLE CAMERAS", outcome = "ALERT -%d%%" % int(data.alert), upgraded = upgrade_key == "security" },
		{ id = &"opt_scan_up" if upgrade_key == "scan" else &"opt_scan", action = &"terminal_scan", title = "HIJACK CAMERA NETWORK" if upgrade_key == "scan" else "HIJACK LOCAL FEED", outcome = "WIDE SCAN" if upgrade_key == "scan" else "SECTOR SCAN", upgraded = upgrade_key == "scan" },
		{ id = &"opt_med_up" if upgrade_key == "medical" else &"opt_med", action = &"terminal_medical", title = "DISPENSE ADRENALINE" if upgrade_key == "medical" else "DISPENSE PAINKILLERS", outcome = "HEAL + BOOST" if upgrade_key == "medical" else "HEAL INJURY", upgraded = upgrade_key == "medical" },
		{ id = &"opt_fin_up" if upgrade_key == "finance" else &"opt_fin", action = &"terminal_finance", title = "INTERCEPT PAYMENT" if upgrade_key == "finance" else "BIT MINE", outcome = "+%.1f BITS" % (float(data.bits) / 10.0), upgraded = upgrade_key == "finance" },
		{ id = EXTRACTION_ID, action = EXTRACTION_ACTION, title = "SIGNAL EXTRACTION", outcome = "TACTICAL RETREAT", upgraded = false },
	]
```

Route all keyboard, controller, focus, and mouse activation through one method:

```gdscript
func handle_semantic_action(action: StringName) -> bool:
	if interaction_state == TerminalState.CLOSING:
		return action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm", &"cancel"]
	if interaction_state == TerminalState.TYPING:
		if action == &"cancel":
			_begin_close()
			return true
		if action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm"]:
			finish_typing()
			return true
		return false
	if interaction_state == TerminalState.CONFIRMING_EXTRACTION:
		if action == &"confirm":
			_commit_choice(EXTRACTION_ID)
			return true
		if action == &"cancel":
			_leave_extraction_confirmation()
			return true
		return action in PROTOCOL_ACTIONS or action == EXTRACTION_ACTION
	if action == &"cancel":
		_begin_close()
		return true
	if action == EXTRACTION_ACTION:
		_enter_extraction_confirmation()
		return true
	var action_index := PROTOCOL_ACTIONS.find(action)
	if action_index >= 0:
		_commit_choice(_rows[action_index].get_choice_id())
		return true
	return false
```

Connect and route every activation through the same seams:

```gdscript
func _ready() -> void:
	for child in protocols.get_children():
		if child is TerminalProtocolRow:
			_rows.append(child)
			(child as TerminalProtocolRow).activated.connect(_on_protocol_activated)
	_typing_labels.assign([header_text, status_label, %Prompt, %TraceWarning])
	close_button.pressed.connect(func(): handle_semantic_action(&"cancel"))
	confirm_button.pressed.connect(func(): handle_semantic_action(&"confirm"))
	cancel_button.pressed.connect(func(): handle_semantic_action(&"cancel"))
	_ensure_modal_registered()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var navigation := _navigation_ux_layer()
	if navigation and not navigation.is_top_modal(self):
		return
	var actions: Array[StringName] = [&"cancel", &"confirm", EXTRACTION_ACTION]
	actions.append_array(PROTOCOL_ACTIONS)
	for action: StringName in actions:
		if event.is_action_pressed(action) and handle_semantic_action(action):
			get_viewport().set_input_as_handled()
			return

func _on_protocol_activated(choice_id: StringName) -> void:
	if interaction_state == TerminalState.TYPING:
		finish_typing()
		return
	if interaction_state != TerminalState.READY:
		return
	if choice_id == EXTRACTION_ID:
		_enter_extraction_confirmation()
	else:
		_commit_choice(choice_id)

func get_protocol_row(index: int) -> TerminalProtocolRow:
	return _rows[index] if index >= 0 and index < _rows.size() else null
```

`finish_typing()` kills `type_tween`, restores every animated label's visible ratio or modulate to its final value, and sets `interaction_state = READY`. `_enter_extraction_confirmation()` disables all rows, shows the panel, and focuses Confirm. `_leave_extraction_confirmation()` hides the panel, enables rows, sets Ready, and returns focus to Extraction. `_commit_choice()` sets Closing before emitting and starts the existing non-close fade/free path.

Implement those methods with these exact state boundaries:

```gdscript
func finish_typing() -> void:
	if interaction_state != TerminalState.TYPING:
		return
	if is_instance_valid(type_tween):
		type_tween.kill()
	for label: Label in _typing_labels:
		label.visible_ratio = 1.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 1.0
	interaction_state = TerminalState.READY

func _set_rows_interactable(enabled: bool) -> void:
	for row: TerminalProtocolRow in _rows:
		row.set_interactable(enabled)

func _enter_extraction_confirmation() -> void:
	interaction_state = TerminalState.CONFIRMING_EXTRACTION
	_set_rows_interactable(false)
	confirmation_panel.show()
	confirm_button.grab_focus.call_deferred()

func _leave_extraction_confirmation() -> void:
	confirmation_panel.hide()
	_set_rows_interactable(true)
	interaction_state = TerminalState.READY
	_rows[4].grab_focus.call_deferred()

func _commit_choice(choice_id: StringName) -> void:
	if interaction_state == TerminalState.CLOSING:
		return
	interaction_state = TerminalState.CLOSING
	_set_rows_interactable(false)
	close_button.disabled = true
	option_selected.emit(choice_id)
	_animate_close(false)

func _begin_close() -> void:
	if interaction_state == TerminalState.CLOSING:
		return
	interaction_state = TerminalState.CLOSING
	_set_rows_interactable(false)
	close_button.disabled = true
	_animate_close(true)

func _animate_close(emit_closed: bool) -> void:
	var close_generation := _lifecycle_generation
	close_tween = create_tween()
	close_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await close_tween.finished
	if close_generation != _lifecycle_generation:
		return
	close_tween = null
	hide()
	var navigation := _navigation_ux_layer()
	if navigation and navigation.is_top_modal(self):
		navigation.pop_modal(self)
	if emit_closed:
		closed.emit()
	else:
		queue_free()
```

Use `_begin_close()` at both cancel branches in `handle_semantic_action()`; it has no boolean parameter.

- [ ] **Step 5: Restore modal setup and reset behavior**

In `_ready()`, populate `_rows` from `%Protocols`, connect each `activated` signal, connect close/confirm/cancel buttons, and call `_ensure_modal_registered()` so tests and fallback presentation remain safe even before `setup()`.

Implement modal ownership and passive-hint suppression once:

```gdscript
func _ensure_modal_registered() -> void:
	var navigation := _navigation_ux_layer()
	if not navigation:
		return
	if not navigation.is_top_modal(self):
		navigation.push_modal(self, _rows[0])
	navigation.publish_hints([])
```

In `setup(data)`, increment `_lifecycle_generation`, cancel both tweens, reset opacity and visibility, hide confirmation, enable the close button, call `_ensure_modal_registered()`, and validate the five presentation fields before indexing them:

```gdscript
func setup(data: Dictionary) -> bool:
	_reset_lifecycle()
	_ensure_modal_registered()
	if not _has_valid_presentation_data(data):
		header_text.text = "PARADIGM TERMINAL // DATA ERROR"
		status_label.text = "PROTOCOL DIRECTORY UNAVAILABLE"
		_set_rows_interactable(false)
		interaction_state = TerminalState.READY
		return false
	var definitions := _protocol_definitions(data)
	for index in 5:
		var definition: Dictionary = definitions[index]
		_rows[index].configure(definition.id, definition.action, definition.title, definition.outcome, definition.upgraded)
		_rows[index].set_interactable(true)
	header_text.text = "PARADIGM TERMINAL v4.2 // %s" % str(data.facility_name)
	status_label.text = "NEURAL AUTH: SUCCESS · FIREWALL: OFF · SESSION %s" % str(data.session_id)
	interaction_state = TerminalState.TYPING
	_start_typing_effect()
	_rows[0].grab_focus.call_deferred()
	return true

func _has_valid_presentation_data(data: Dictionary) -> bool:
	for field in ["upgrade_key", "bits", "alert", "facility_name", "session_id"]:
		if not data.has(field):
			return false
	return (
		data.upgrade_key is String
		and (data.bits is int or data.bits is float)
		and (data.alert is int or data.alert is float)
		and data.facility_name is String
		and data.session_id is String
	)
```

Use these lifecycle helpers so typing remains brief, deterministic, and skippable:

```gdscript
func _reset_lifecycle() -> void:
	_lifecycle_generation += 1
	for tween: Tween in [type_tween, close_tween]:
		if is_instance_valid(tween):
			tween.kill()
	type_tween = null
	close_tween = null
	modulate.a = 1.0
	show()
	confirmation_panel.hide()
	close_button.disabled = false
	for label: Label in _typing_labels:
		label.visible_ratio = 1.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 1.0

func _start_typing_effect() -> void:
	for label: Label in _typing_labels:
		label.visible_ratio = 0.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 0.15
	type_tween = create_tween().set_parallel(true)
	for label: Label in _typing_labels:
		type_tween.tween_property(label, "visible_ratio", 1.0, 0.3)
	for row: TerminalProtocolRow in _rows:
		type_tween.tween_property(row, "modulate:a", 1.0, 0.35)
	type_tween.chain().tween_callback(finish_typing)
```

Keep `_exit_tree()` removing modal ownership. Keep the generation guard around asynchronous closing so a new `setup()` invalidates an earlier close callback.

- [ ] **Step 6: Run terminal and row tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
```

Expected: all terminal and row tests pass; each choice emits once; extraction never emits before Confirm.

- [ ] **Step 7: Commit the terminal behavior and layout**

```bash
git add src/map/terminal.gd src/map/terminal.tscn test/unit/test_terminal.gd
git commit -m "feat: redesign terminal interaction"
```

---

### Task 4: Integrate Modal Focus, Controller Routing, and Responsive Bounds

**Files:**
- Modify: `test/integration/test_dungeon_restore.gd:938-967`
- Modify: `test/integration/test_standard_focus_navigation.gd:103-140`
- Modify: `test/integration/test_controller_playable_loop.gd:252-263`
- Modify: `test/integration/test_game_manager_interactions.gd:419-440`
- Modify: `test/integration/test_navigation_ux_layer.gd` only if existing modal assertions need the new default control
- Add responsive assertions to: `test/unit/test_terminal.gd`

**Interfaces:**
- Consumes: `Terminal.get_protocol_row(index) -> TerminalProtocolRow`, `Terminal.finish_typing()`, the state model from Task 3, and existing NavigationUXLayer modal APIs.
- Produces: tested title/hub/map/terminal/battle/result continuity with the first protocol as terminal focus and current global input glyphs visible immediately.

- [ ] **Step 1: Update integration expectations to the new public behavior**

In `test_terminal_modal_temporarily_owns_cursor_then_restores_live_map_adapter`, replace close-button expectations with:

```gdscript
var first_protocol := terminal.get_protocol_row(0)
assert_eq(get_viewport().gui_get_focus_owner(), first_protocol)
assert_same(navigation.get_focus_target(), first_protocol)
assert_same(navigation.cursor._target, first_protocol)
assert_eq(navigation.hint_bar.get_hint_count(), 0)
```

Make the equivalent replacement in `test_nested_party_and_terminal_cancel_only_top_and_restore_each_layer`.

In the controller playable loop, verify inherited family before terminal-local input and press Finance twice because the first press intentionally completes typing:

```gdscript
var terminal := router.manager.overlay_layer.get_child(0)
var finance := terminal.get_protocol_row(3)
assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
assert_same(finance.glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"terminal_finance"))
_assert_focus(terminal.get_protocol_row(0))
await _send(&"terminal_finance")
assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
await _send(&"terminal_finance")
```

In the real terminal extraction test, replace `_on_text_link_clicked("opt_extract")` with:

```gdscript
terminal.finish_typing()
assert_true(terminal.handle_semantic_action(&"terminal_extract"))
assert_true(terminal.handle_semantic_action(&"confirm"))
```

- [ ] **Step 2: Add responsive layout assertions**

Add this helper and test to `test/unit/test_terminal.gd`:

```gdscript
func _terminal_in_viewport(size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	var terminal := TerminalScene.instantiate()
	viewport.add_child(terminal)
	terminal.setup(_payload("", "RESPONSIVE", 12, 10))
	await get_tree().process_frame
	return {viewport = viewport, terminal = terminal}

func test_terminal_panel_and_protocols_fit_minimum_and_desktop_viewports() -> void:
	for size in [Vector2i(1200, 800), Vector2i(1920, 1080)]:
		var fixture := await _terminal_in_viewport(size)
		var terminal = fixture.terminal
		var panel: Control = terminal.get_node("Panel")
		assert_true(panel.position.x >= size.x * 0.04)
		assert_true(panel.position.y >= size.y * 0.04)
		assert_true(panel.position.x + panel.size.x <= size.x * 0.96)
		assert_true(panel.position.y + panel.size.y <= size.y * 0.96)
		for index in 5:
			var row := terminal.get_protocol_row(index)
			assert_true(panel.get_global_rect().encloses(row.get_global_rect()), "%s row %d" % [size, index])
```

- [ ] **Step 3: Run integration and terminal tests and confirm the old focus assumptions fail before adjustment, then pass after adjustment**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
```

Expected: all selected scripts pass; terminal focus starts on Security; map focus restores after close; the controller loop executes Finance only after the typing skip; extraction requires the explicit confirmation sequence.

- [ ] **Step 4: Commit the integration coverage**

```bash
git add test/unit/test_terminal.gd test/integration/test_dungeon_restore.gd \
  test/integration/test_standard_focus_navigation.gd \
  test/integration/test_controller_playable_loop.gd \
  test/integration/test_game_manager_interactions.gd \
  test/integration/test_navigation_ux_layer.gd
git commit -m "test: cover responsive terminal flow"
```

Omit `test/integration/test_navigation_ux_layer.gd` from the commit if it required no change.

---

### Task 5: Update Manual Acceptance and Run Final Verification

**Files:**
- Modify: `docs/testing/controller-manual-checklist.md:79-102`

**Interfaces:**
- Consumes: the completed responsive terminal and all automated coverage from Tasks 1–4.
- Produces: a concise manual acceptance path for Steam Deck scale, DualSense hotkeys, mouse behavior, extraction safety, and map restoration.

- [ ] **Step 1: Replace the generic terminal checklist bullets with explicit acceptance steps**

Under `## Dungeon map and terminal`, replace the final two terminal bullets with:

```markdown
- [ ] At 1200×800 and 1280×800, open a terminal from the fixed map path; the inset panel nearly fills the screen, all five protocol rows and their outcomes are readable, and no header, footer, glyph, row, or confirmation content clips.
- [ ] On DualSense, verify Cross executes Security, L1 enters Scan targeting, Square executes Medical, and Triangle executes Finance after the typing animation; the first protocol input during typing only completes the animation.
- [ ] On keyboard, verify 1–4 execute the same protocols and 5 only opens extraction confirmation.
- [ ] Verify Circle always closes/backs out in the normal terminal, R1 opens extraction confirmation, Cross confirms Tactical Retreat exactly once, and Circle returns to the protocol list from confirmation without closing or consuming the terminal.
- [ ] With a mouse, click protocols 1–4 directly; click Extraction, then use its explicit Confirm and Cancel controls.
- [ ] Switch between controller and keyboard-and-mouse while the terminal is open; every embedded glyph updates immediately and the global passive hint bar remains hidden.
- [ ] Close normally and cancel scan targeting after reopening; focus returns to the live map adapter, and the reopened terminal resets typing, extraction confirmation, and one-shot state.
```

- [ ] **Step 2: Run formatting and focused verification**

Run:

```bash
git diff --check
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
```

Expected: `git diff --check` is silent and every selected script passes.

- [ ] **Step 3: Run the complete GUT suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all tests pass with no parser errors, crashes, unexpected failures, or writes to ordinary save slots. Documented expected test errors and engine shutdown leak diagnostics remain acceptable only when the process exits successfully.

- [ ] **Step 4: Inspect the final change boundary**

Run:

```bash
git status --short
git diff --stat HEAD~4..HEAD
git log --oneline -5
```

Expected: only terminal input/glyph files, the terminal row and scene, terminal/input tests, relevant integration tests, and the controller checklist belong to this effort. No unrelated battle-healing, audio-layout, save, progression, or dungeon-camera changes appear.

- [ ] **Step 5: Commit the acceptance checklist**

```bash
git add docs/testing/controller-manual-checklist.md
git commit -m "docs: add terminal acceptance checks"
```

- [ ] **Step 6: Perform manual acceptance before integration**

Run the game at 1200×800, 1280×800, and 1920×1080. Complete every new terminal checklist item with mouse/keyboard and DualSense. Record any purely visual spacing or typewriter-speed adjustment as a focused follow-up commit, rerun `test_terminal.gd`, and rerun the complete suite before declaring the branch ready.

---

## Completion Criteria

- The terminal fills approximately 90–91% of the viewport while leaving a visible dungeon margin.
- All terminal content is readable and unclipped at 1200×800.
- Security, Scan, Medical, and Finance use keyboard 1–4 and Cross/A, L1/LB, Square/X, and Triangle/Y respectively and execute once.
- Extraction uses keyboard 5 or the right shoulder, never executes before explicit Confirm, and cancels back to the protocol list.
- Mouse activation, fallback focus navigation, typewriter skipping, reopening, and close behavior share the same state machine.
- The terminal inherits the global input mode and controller family immediately.
- Existing protocol effects, scan flow, extraction routing, payloads, and saves are unchanged.
- Focused tests, the complete GUT suite, and the manual terminal checklist pass.
