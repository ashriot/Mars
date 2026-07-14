# Input Ownership and Focus Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace cursor-snapped navigation with explicit controller/keyboard/mouse ownership, a retained logical focus with a 70% neutral fill, an independent hardware mouse cursor, and a scan-only software pointer.

**Architecture:** `InputManager` owns two orthogonal states: `InputMode` and `PresentationMode`. `NavigationUXLayer` retains logical GUI focus, paints it only in focus presentation, and uses a transparent input blocker to prevent stale mouse hover while focus is authoritative. `NavigationCursor` becomes a scan-only software pointer; map and battle adapters retain their existing reticle/card highlights and never target or warp the physical mouse.

**Tech Stack:** Godot 4.6.3, GDScript, Godot Theme/StyleBox resources, GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3; do not change the engine version, plugins, dependencies, or project-wide formats.
- Run every automated Godot command with `HOME=/tmp/mars-godot-home`.
- Preserve unrelated user work and commit only files named by the current task.
- Do not create a Git worktree for this effort.
- Do not move or warp the physical mouse position in any navigation path.
- Mouse motion cannot leave controller ownership; the first controller-to-mouse click is a consumed handoff.
- Keyboard input leaving controller ownership reveals the physical cursor and performs its action immediately.
- The first arrow/WASD press after pointer presentation restores retained focus without moving it; the next press navigates.
- Ordinary controller navigation uses focus/reticle/card presentation and never shows a snapped arrow.
- The controls hint-bar typography and floating-panel redesign remain deferred.

---

## File Structure

- `src/singletons/input_manager.gd` — owns input family, pointer/focus presentation, cursor visibility, and event handoff consumption.
- `data/theme/styleboxes/button_focus.tres` — defines the shared 70% neutral focus fill.
- `src/ui/navigation/navigation_focus.gd` — applies/restores focus styles without scaling controls.
- `src/ui/navigation/navigation_ux_layer.gd` — retains logical focus and synchronizes visible focus plus mouse-input blocking.
- `src/ui/navigation/navigation_ux_layer.tscn` — adds the transparent blocker used while focus presentation is authoritative.
- `src/ui/navigation/navigation_cursor.gd` — scan-only software pointer with explicit show/hide operations.
- `src/map/dungeon_map.gd` — shows the software pointer only during controller scan targeting.
- `src/battle/battle_scene.gd` — keeps semantic target highlights but stops assigning cursor targets.
- `src/hub/*.gd` and selected hub scenes — remove cursor-state metadata and identify nonstandard focus surfaces.
- `test/unit/` and `test/integration/` — replace warp/cursor assertions with transition, retained-focus, style, scan, reticle, and highlight assertions.
- `docs/coordinate-spaces.md` and `docs/testing/controller-manual-checklist.md` — document hardware-pointer independence and the revised manual acceptance sequence.

---

### Task 1: Explicit input and presentation state

**Files:**
- Modify: `src/singletons/input_manager.gd:3-168`
- Modify: `test/unit/test_input_manager.gd:1-260`

**Interfaces:**
- Produces: `enum PresentationMode { POINTER, FOCUS }`
- Produces: `signal presentation_mode_changed(mode: PresentationMode)`
- Produces: `func get_presentation_mode() -> PresentationMode`
- Produces: `func _set_presentation_mode(mode: PresentationMode) -> void`
- Produces: `_consumed_mouse_button: MouseButton`, cleared after its matching release.
- Preserves: `InputMode`, `input_mode_changed`, controller-family detection, and semantic family rebinding.

- [ ] **Step 1: Replace cursor/warp tests with failing state-transition tests**

Update the test subclass to record hardware-cursor and handled-event seams:

```gdscript
class TestInputManager extends InputManager:
	var mouse_modes: Array[Input.MouseMode] = []
	var handled_event_count := 0
	var custom_cursor_hotspot := Vector2.INF

	func _set_mouse_mode(mode: Input.MouseMode) -> void:
		mouse_modes.append(mode)

	func _install_hardware_cursor(_texture: Texture2D, hotspot: Vector2) -> void:
		custom_cursor_hotspot = hotspot

	func _mark_input_handled() -> void:
		handled_event_count += 1
```

Replace `CursorBehavior` and expected-warp cases with named tests covering:

```gdscript
func test_controller_hides_pointer_and_selects_focus_presentation() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_HIDDEN)


func test_mouse_motion_cannot_leave_controller_mode() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_motion(Vector2(12, 0)))
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)


func test_one_pixel_mouse_motion_selects_pointer_only_in_keyboard_mouse_mode() -> void:
	manager._set_presentation_mode(manager.PresentationMode.FOCUS)
	manager._input(_mouse_motion(Vector2(1, 0)))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)


func test_controller_mouse_handoff_consumes_press_and_matching_release() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
	assert_eq(manager.handled_event_count, 2)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)


func test_keyboard_from_controller_reveals_pointer_and_does_not_consume_action() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_key(KEY_UP))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_VISIBLE)
	assert_eq(manager.handled_event_count, 0)


func test_first_direction_after_pointer_restores_focus_and_is_consumed() -> void:
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	manager._input(_key(KEY_DOWN))
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.handled_event_count, 1)
	manager._input(_key(KEY_DOWN))
	assert_eq(manager.handled_event_count, 1)


func test_non_navigation_key_from_pointer_is_not_consumed() -> void:
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	manager._input(_physical_key(KEY_1))
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
	assert_eq(manager.handled_event_count, 0)


func test_ready_installs_styled_hardware_cursor_at_arrow_tip() -> void:
	manager._ready()
	assert_eq(manager.custom_cursor_hotspot, Vector2(2, 2))
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_VISIBLE)


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: failures because `PresentationMode`, cursor seams, and click-transaction consumption do not exist.

- [ ] **Step 3: Implement the two-axis state machine and hardware cursor ownership**

In `InputManager`, remove `CursorBehavior`, `MOUSE_MOTION_THRESHOLD`, `WARP_POSITION_TOLERANCE`, `WARP_SUPPRESSION_MS`, `expect_mouse_warp()`, `_suppress_expected_mouse_warp()`, and `_now_ms()`. Add:

```gdscript
enum InputMode { KEYBOARD_MOUSE, CONTROLLER }
enum PresentationMode { POINTER, FOCUS }

const HARDWARE_CURSOR := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")
const HARDWARE_CURSOR_HOTSPOT := Vector2(2, 2)
const DIRECTIONAL_NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
]

signal presentation_mode_changed(mode: PresentationMode)

var _presentation_mode := PresentationMode.POINTER
var _consumed_mouse_button: MouseButton = MOUSE_BUTTON_NONE


func get_presentation_mode() -> PresentationMode:
	return _presentation_mode


func _set_presentation_mode(mode: PresentationMode) -> void:
	if _presentation_mode == mode:
		return
	_presentation_mode = mode
	presentation_mode_changed.emit(mode)


func _is_directional_navigation_key(event: InputEventKey) -> bool:
	for action in DIRECTIONAL_NAVIGATION_ACTIONS:
		if event.is_action(action):
			return true
	return false


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	Input.mouse_mode = mode


func _install_hardware_cursor(texture: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
```

Install the custom cursor in `_ready()`, then implement `_input()` in this order: consume a pending matching mouse release; ignore controller-owned mouse motion; switch meaningful keyboard/mouse-owned motion to `POINTER`; switch meaningful controller input to `CONTROLLER` plus `FOCUS` and hide the hardware cursor; switch keyboard input to `KEYBOARD_MOUSE`, reveal the cursor, retain `FOCUS` when leaving controller mode, and consume only the first directional press leaving pointer presentation; switch any keyboard/mouse-owned mouse press to `POINTER`; consume the initiating press only when the previous owner was `CONTROLLER`.

Use this event flow:

```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _consumed_mouse_button != MOUSE_BUTTON_NONE:
		_mark_input_handled()
		if event.button_index == _consumed_mouse_button and not event.pressed:
			_consumed_mouse_button = MOUSE_BUTTON_NONE
		return
	if event is InputEventMouseMotion:
		if _active_mode == InputMode.KEYBOARD_MOUSE and not event.relative.is_zero_approx():
			_set_presentation_mode(PresentationMode.POINTER)
		return
	if not is_meaningful_event(event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_active_mode(InputMode.CONTROLLER)
		_set_presentation_mode(PresentationMode.FOCUS)
		_set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_set_active_controller_type(InputIconMap.get_controller_type_from_name(Input.get_joy_name(event.device)))
		return
	if event is InputEventKey:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			_set_presentation_mode(PresentationMode.FOCUS)
		elif _presentation_mode == PresentationMode.POINTER and _is_directional_navigation_key(event):
			_set_presentation_mode(PresentationMode.FOCUS)
			_mark_input_handled()
		return
	if event is InputEventMouseButton:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_presentation_mode(PresentationMode.POINTER)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			_consumed_mouse_button = event.button_index
			_mark_input_handled()
```

Keep `restore_active_mode()` and `_set_active_mode()` responsible for reapplying visible/hidden mouse mode even if the requested owner already matches, so battle scene inheritance cannot leave stale cursor visibility.

- [ ] **Step 4: Run focused tests and verify they pass**

Run the Task 1 command again.

Expected: all `test_input_manager.gd` tests pass; no expected-warp or `CursorBehavior` references remain in that file.

- [ ] **Step 5: Commit Task 1**

```sh
git add src/singletons/input_manager.gd test/unit/test_input_manager.gd
git commit -m "refactor: separate input and presentation ownership"
```

---

### Task 2: Neutral focus-fill presentation

**Files:**
- Modify: `data/theme/styleboxes/button_focus.tres:1-14`
- Modify: `src/ui/navigation/navigation_focus.gd:1-60`
- Modify: `src/hub/item_button.gd:1-55`
- Modify: `src/hub/mod_slot.gd:1-70`
- Modify: `src/hub/equipment_panel.gd:1-45`
- Modify: `src/hub/equipment_panel.tscn:1-125`
- Modify: `test/unit/test_navigation_focus.gd:1-60`
- Modify: `test/integration/test_hub_progression.gd:500-700`

**Interfaces:**
- Consumes: `InputManager.PresentationMode` only through `NavigationUXLayer` in Task 3.
- Produces: `NavigationFocus.apply(control: Control) -> void` and `NavigationFocus.clear(control: Control) -> void` with no scale or pivot changes.
- Produces metadata contract: `navigation_focus_surface: NodePath` on a nonstandard focus control points to a `Button`, `Panel`, or `PanelContainer` whose style is temporarily overridden.

- [ ] **Step 1: Write failing focus-style tests**

Replace scale-tween expectations with style restoration and contrast expectations:

```gdscript
func test_button_focus_uses_seventy_percent_fill_and_dark_text_without_scaling() -> void:
	var control := Button.new()
	control.scale = Vector2(1.4, 0.8)
	control.pivot_offset = Vector2(7, 9)
	add_child_autofree(control)
	NavigationFocus.apply(control)
	var style := control.get_theme_stylebox(&"focus") as StyleBoxFlat
	assert_almost_eq(style.bg_color.a, 0.7, 0.001)
	assert_eq(control.get_theme_color(&"font_focus_color"), Color(0.19607843, 0.19607843, 0.19607843, 1))
	assert_eq(control.scale, Vector2(1.4, 0.8))
	assert_eq(control.pivot_offset, Vector2(7, 9))


func test_clear_restores_authored_style_and_label_colors() -> void:
	var control := TextureButton.new()
	var surface := Panel.new()
	var label := Label.new()
	control.add_child(surface)
	control.add_child(label)
	control.set_meta("navigation_focus_surface", NodePath("Panel"))
	var original_style := StyleBoxFlat.new()
	original_style.bg_color = Color.BLUE
	surface.add_theme_stylebox_override(&"panel", original_style)
	label.add_theme_color_override(&"font_color", Color.GREEN)
	add_child_autofree(control)
	NavigationFocus.apply(control)
	assert_ne(surface.get_theme_stylebox(&"panel"), original_style)
	assert_eq(label.get_theme_color(&"font_color"), Color(0.19607843, 0.19607843, 0.19607843, 1))
	NavigationFocus.clear(control)
	assert_same(surface.get_theme_stylebox(&"panel"), original_style)
	assert_eq(label.get_theme_color(&"font_color"), Color.GREEN)
```

Add this representative hub assertion for all nonstandard focus surfaces:

```gdscript
func test_nonstandard_hub_controls_expose_valid_focus_surfaces() -> void:
	var item := preload("res://src/hub/item_button.tscn").instantiate() as ItemButton
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	var equipment := preload("res://src/hub/equipment_panel.tscn").instantiate() as EquipmentPanel
	add_child_autofree(item)
	add_child_autofree(slot)
	add_child_autofree(equipment)
	await get_tree().process_frame
	var controls: Array[Control] = [
		item.get_focus_control(),
		slot.get_focus_control(),
		equipment.equip_button,
		equipment.tune_btn,
	]
	for control in controls:
		assert_true(control.has_meta("navigation_focus_surface"))
		var surface := control.get_node_or_null(control.get_meta("navigation_focus_surface")) as Control
		assert_not_null(surface)
		NavigationFocus.apply(control)
		var style_name := &"focus" if surface is Button else &"panel"
		var style := surface.get_theme_stylebox(style_name) as StyleBoxFlat
		assert_almost_eq(style.bg_color.a, 0.7, 0.001)
		NavigationFocus.clear(control)
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_focus -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
```

Expected: focus tests fail because the implementation still scales controls and preserves the empty focus style.

- [ ] **Step 3: Implement the shared focus style and restoration state**

Set `button_focus.tres` to `bg_color = Color(1, 1, 1, 0.7)` with the existing 3-pixel white border and 12-pixel corner radii.

Rewrite `NavigationFocus` around saved style/color state:

```gdscript
const FOCUS_STYLE := preload("res://data/theme/styleboxes/button_focus.tres")
const FOCUS_FOREGROUND := Color(0.19607843, 0.19607843, 0.19607843, 1)

static var _states: Dictionary = {}


static func apply(control: Control) -> void:
	if not is_instance_valid(control) or _states.has(control.get_instance_id()):
		return
	var surface := _resolve_surface(control)
	if not is_instance_valid(surface):
		return
	var style_name := &"focus" if surface is Button else &"panel"
	var labels: Array[Dictionary] = []
	for label in _focus_labels(control, surface):
		labels.append({
			"label": weakref(label),
			"had_override": label.has_theme_color_override(&"font_color"),
			"color": label.get_theme_color(&"font_color"),
		})
		label.add_theme_color_override(&"font_color", FOCUS_FOREGROUND)
	var state := {
		"control": weakref(control),
		"surface": weakref(surface),
		"style_name": style_name,
		"had_style_override": surface.has_theme_stylebox_override(style_name),
		"style": surface.get_theme_stylebox(style_name),
		"labels": labels,
		"had_font_focus_override": control.has_theme_color_override(&"font_focus_color"),
		"font_focus_color": control.get_theme_color(&"font_focus_color"),
	}
	_states[control.get_instance_id()] = state
	surface.add_theme_stylebox_override(style_name, FOCUS_STYLE)
	if control is Button:
		control.add_theme_color_override(&"font_focus_color", FOCUS_FOREGROUND)
	var cleanup := _release_state.bind(control.get_instance_id())
	if not control.tree_exiting.is_connected(cleanup):
		control.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
```

Implement `_resolve_surface()` from the metadata contract, defaulting ordinary `Button` and `Panel` controls to themselves. Implement `_focus_labels()` as the unique union of `Label` descendants under the focus control and resolved surface. `clear()` restores or removes each saved override synchronously and erases `_states`; it never creates a tween or touches `scale`/`pivot_offset`.

Use these resolution and restoration rules:

```gdscript
static func _resolve_surface(control: Control) -> Control:
	if control.has_meta("navigation_focus_surface"):
		return control.get_node_or_null(control.get_meta("navigation_focus_surface")) as Control
	if control is Button or control is Panel or control is PanelContainer:
		return control
	return null


static func _focus_labels(control: Control, surface: Control) -> Array[Label]:
	var labels: Array[Label] = []
	for root in [control, surface]:
		for child in root.find_children("*", "Label", true, false):
			if child is Label and not labels.has(child):
				labels.append(child)
	return labels


static func clear(control: Control) -> void:
	if not is_instance_valid(control) or not _states.has(control.get_instance_id()):
		return
	var state: Dictionary = _states[control.get_instance_id()]
	var surface := state.surface.get_ref() as Control
	if is_instance_valid(surface):
		if state.had_style_override:
			surface.add_theme_stylebox_override(state.style_name, state.style)
		else:
			surface.remove_theme_stylebox_override(state.style_name)
	for label_state: Dictionary in state.labels:
		var label := label_state.label.get_ref() as Label
		if not is_instance_valid(label):
			continue
		if label_state.had_override:
			label.add_theme_color_override(&"font_color", label_state.color)
		else:
			label.remove_theme_color_override(&"font_color")
	if control is Button:
		if state.had_font_focus_override:
			control.add_theme_color_override(&"font_focus_color", state.font_focus_color)
		else:
			control.remove_theme_color_override(&"font_focus_color")
	_states.erase(control.get_instance_id())
```

- [ ] **Step 4: Author explicit focus surfaces for TextureButton controls**

Set these metadata paths during `_ready()`:

```gdscript
# ItemButton
$Button.set_meta("navigation_focus_surface", NodePath("Header"))

# ModSlot
button.set_meta("navigation_focus_surface", NodePath(".."))

# EquipmentPanel
equip_button.set_meta("navigation_focus_surface", NodePath("../Header"))
tune_btn.set_meta("navigation_focus_surface", NodePath("../TuneFocusSurface"))
```

Add `TuneFocusSurface` as a `Panel` sibling immediately before `TuneBtn` in `equipment_panel.tscn`, with the same 44×44 bounds, `mouse_filter = Control.MOUSE_FILTER_IGNORE`, and a transparent normal panel style. The metadata lets `NavigationFocus` replace that panel style without obscuring the maintenance icon.

- [ ] **Step 5: Run focused tests and verify they pass**

Run the Task 2 command again.

Expected: focus/unit and representative hub tests pass; no focus test waits for a scale tween.

- [ ] **Step 6: Commit Task 2**

```sh
git add data/theme/styleboxes/button_focus.tres src/ui/navigation/navigation_focus.gd src/hub/item_button.gd src/hub/mod_slot.gd src/hub/equipment_panel.gd src/hub/equipment_panel.tscn test/unit/test_navigation_focus.gd test/integration/test_hub_progression.gd
git commit -m "feat: replace focus scaling with neutral fill"
```

---

### Task 3: Retained focus and pointer-owned hover

**Files:**
- Modify: `src/ui/navigation/navigation_ux_layer.gd:1-423`
- Modify: `src/ui/navigation/navigation_ux_layer.tscn:1-16`
- Modify: `test/integration/test_navigation_ux_layer.gd:1-630`
- Modify: `test/integration/test_standard_focus_navigation.gd:1-210`

**Interfaces:**
- Consumes: `InputManager.get_presentation_mode()` and `InputManager.presentation_mode_changed` from Task 1.
- Consumes: `NavigationFocus.apply()` / `clear()` from Task 2.
- Produces: `@onready var pointer_input_blocker: Control = $PointerInputBlocker`.
- Preserves: screen registration, modal stack, focusless modal behavior, hint ownership, and adapter restoration.

- [ ] **Step 1: Write failing retained-focus and hover-suppression integration tests**

Add tests using three real `Button` controls with authored focus neighbors:

```gdscript
func test_mouse_motion_hides_focus_but_retains_navigation_origin() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	var top: Button = setup.top
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	top.grab_focus()
	await get_tree().process_frame
	assert_true(NavigationFocus._states.has(top.get_instance_id()))
	InputManager._input(_mouse_motion(Vector2(12, 0)))
	assert_same(ux.get_focus_target(), top)
	assert_same(get_viewport().gui_get_focus_owner(), top)
	assert_false(NavigationFocus._states.has(top.get_instance_id()))
	assert_false(ux.pointer_input_blocker.visible)


func test_first_keyboard_direction_after_pointer_only_restores_top_focus() -> void:
	var setup := await _three_button_screen()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.top)
	assert_true(NavigationFocus._states.has(setup.top.get_instance_id()))
	get_viewport().push_input(_released_key(KEY_DOWN))
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)


func test_controller_direction_from_pointer_moves_immediately_and_hides_mouse() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, true))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_true(ux.pointer_input_blocker.visible)


func test_focus_presentation_resolves_invalid_retained_target_to_fallback() -> void:
	var setup := await _three_button_screen()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	setup.top.disabled = true
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_same(setup.ux.get_focus_target(), setup.middle)
	assert_true(NavigationFocus._states.has(setup.middle.get_instance_id()))
```

Create the fixture and event helpers in the same test script so every test uses the same authored navigation graph:

```gdscript
func _three_button_screen() -> Dictionary:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := VBoxContainer.new()
	screen.position = Vector2(100, 100)
	var top := Button.new()
	var middle := Button.new()
	var bottom := Button.new()
	for index in 3:
		var button: Button = [top, middle, bottom][index]
		button.text = ["TOP", "MIDDLE", "BOTTOM"][index]
		button.custom_minimum_size = Vector2(240, 40)
		button.focus_mode = Control.FOCUS_ALL
		screen.add_child(button)
	top.focus_neighbor_bottom = top.get_path_to(middle)
	middle.focus_neighbor_top = middle.get_path_to(top)
	middle.focus_neighbor_bottom = middle.get_path_to(bottom)
	bottom.focus_neighbor_top = bottom.get_path_to(middle)
	add_child_autofree(screen)
	ux.register_screen(screen, top)
	await get_tree().process_frame
	return {"ux": ux, "screen": screen, "top": top, "middle": middle, "bottom": bottom}


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _released_key(keycode: Key) -> InputEventKey:
	var event := _key(keycode)
	event.pressed = false
	return event


func _joy_direction(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
```

Also replace all `ux.cursor._target` and physical-warp assertions with logical focus plus `NavigationFocus._states` assertions. Keep modal/focusless tests unchanged except that the scan-only cursor must remain hidden.

- [ ] **Step 2: Run focused integration tests and verify they fail**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
```

Expected: failures because the UX layer always paints focus, targets the cursor, and has no pointer blocker.

- [ ] **Step 3: Add the transparent pointer blocker**

Add this final full-viewport control to `navigation_ux_layer.tscn` before `NavigationCursor`:

```gdscript
[node name="PointerInputBlocker" type="Control" parent="."]
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
```

It is visually empty. In `FOCUS`, it intercepts stale mouse hover/clicks above ordinary UI. `InputManager` changes to `POINTER` synchronously during a real keyboard/mouse-owned motion or click, so the blocker hides before GUI hit testing. A controller-to-mouse click is still marked handled by Task 1.

- [ ] **Step 4: Synchronize focus painting without releasing logical focus**

Connect the presentation signal in `_ready()` and add:

```gdscript
func _on_presentation_mode_changed(mode: InputManager.PresentationMode) -> void:
	pointer_input_blocker.visible = mode == InputManager.PresentationMode.FOCUS
	if mode == InputManager.PresentationMode.POINTER:
		if is_instance_valid(_focus_target):
			NavigationFocus.clear(_focus_target)
		return
	ensure_valid_focus()
	if _is_focusable(_focus_target):
		NavigationFocus.apply(_focus_target)


func _update_focus_target(control: Control) -> void:
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	_focus_target = control
	if _is_focusable(control) \
			and InputManager.get_presentation_mode() == InputManager.PresentationMode.FOCUS:
		NavigationFocus.apply(control)
```

Initialize this state in `_ready()`. Remove every focus/world cursor assignment from `set_adapter()`, `_update_focus_target()`, and `_clear_presentation()`. Do not release actual GUI focus when entering `POINTER`; only clear its visible treatment.

- [ ] **Step 5: Run focused integration tests and verify they pass**

Run the Task 3 command again.

Expected: both integration scripts pass; pointer motion hides only focus presentation, first keyboard navigation restores without moving, and controller navigation moves immediately.

- [ ] **Step 6: Commit Task 3**

```sh
git add src/ui/navigation/navigation_ux_layer.gd src/ui/navigation/navigation_ux_layer.tscn test/integration/test_navigation_ux_layer.gd test/integration/test_standard_focus_navigation.gd
git commit -m "feat: retain focus across pointer presentation"
```

---

### Task 4: Scan-only software pointer

**Files:**
- Modify: `src/ui/navigation/navigation_cursor.gd:1-151`
- Modify: `src/map/dungeon_map.gd:460-660,1125-1225`
- Modify: `test/unit/test_navigation_cursor.gd:1-285`
- Modify: `test/integration/test_dungeon_restore.gd:430-730,1100-1240`

**Interfaces:**
- Produces: `NavigationCursor.show_at_screen_position(screen_position: Vector2) -> void`.
- Produces: `NavigationCursor.hide_pointer() -> void`.
- Removes: cursor states, focus/world targets, free/snapped behavior, physical-warp seams, expected-warp bookkeeping, and mouse-mode ownership.

- [ ] **Step 1: Replace cursor-warp tests with failing scan-pointer tests**

Reduce `test_navigation_cursor.gd` to the scan-only contract:

```gdscript
func test_scan_pointer_starts_hidden_with_arrow_texture() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	assert_false(cursor.visible)
	assert_eq(cursor.texture.resource_path.get_file(), "pointer_c.svg")


func test_show_at_screen_position_moves_and_shows_without_touching_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_eq(cursor.position, Vector2(320, 180))
	assert_true(cursor.visible)
	cursor.hide_pointer()
	assert_false(cursor.visible)
```

Rewrite the existing scan handoff regression around the scan-only contract:

```gdscript
func test_scan_mouse_motion_preserves_controller_pointer_until_consumed_click_handoff() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var physical_mouse := dungeon_map.get_viewport().get_mouse_position()
	dungeon_map.start_targeting_mode(1)
	var controller_position := dungeon_map.scan_controller.pointer_position
	var selected_before := dungeon_map.scan_controller.selected_node

	InputManager._input(_mouse_motion(Vector2(10, 5)))
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_true(navigation.cursor.visible)
	assert_eq(navigation.cursor.position, controller_position)
	assert_same(dungeon_map.scan_controller.selected_node, selected_before)

	InputManager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	InputManager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(InputManager.get_presentation_mode(), InputManager.PresentationMode.POINTER)
	assert_false(navigation.cursor.visible)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)
	assert_same(dungeon_map.scan_controller.selected_node, selected_before)
	assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)
```

Reuse explicit `_mouse_motion(relative)` and `_mouse_button(button, pressed)` constructors in this test file; do not call `Viewport.warp_mouse()` in test setup.

- [ ] **Step 2: Run cursor and dungeon tests and verify they fail**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: old warp/cursor APIs conflict with the scan-only expectations.

- [ ] **Step 3: Reduce `NavigationCursor` to explicit scan presentation**

Replace the script body with:

```gdscript
extends TextureRect
class_name NavigationCursor

const POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")


func _ready() -> void:
	texture = POINTER_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_at_screen_position(screen_position: Vector2) -> void:
	position = screen_position
	show()


func hide_pointer() -> void:
	hide()
```

It must not call `Input.mouse_mode`, read `Viewport.get_mouse_position()`, process every frame, or call `Viewport.warp_mouse()`.

- [ ] **Step 4: Update dungeon scan ownership**

Change `_clear_navigation_cursor()` to unconditionally call `navigation.cursor.hide_pointer()` when the UX layer exists. Keep `_show_scan_cursor()` gated by `MapState.TARGETING`, controller mode, and `_controller_scan_target_valid`; it supplies the projected scan screen position explicitly.

In the controller-to-mouse click integration test, send both press and release through `InputManager`, assert neither invokes scan confirmation nor the hovered node click, then send a second click and assert ordinary mouse behavior resumes.

- [ ] **Step 5: Run focused tests and verify they pass**

Run the Task 4 command again.

Expected: cursor and dungeon scripts pass with no physical-warp assertions or cursor-state enum references.

- [ ] **Step 6: Commit Task 4**

```sh
git add src/ui/navigation/navigation_cursor.gd src/map/dungeon_map.gd test/unit/test_navigation_cursor.gd test/integration/test_dungeon_restore.gd
git commit -m "refactor: reserve software cursor for scanning"
```

---

### Task 5: Remove cursor-driven battle and hub behavior

**Files:**
- Modify: `src/battle/battle_scene.gd:130-225`
- Modify: `src/hub/skill_tree_node.gd:1-75`
- Modify: `src/hub/role_anchor_node.gd:1-25`
- Modify: `src/hub/item_button.gd:15-50`
- Modify: `src/hub/mod_slot.gd:20-65`
- Modify: `src/hub/equipment_panel.gd:25-45,112-135,200-220`
- Modify: `src/hub/inventory_panel.gd:255-266`
- Modify: `src/hub/party_menu.gd:65-85`
- Modify: `test/integration/test_battle_controller_navigation.gd:200-310,450-520`
- Modify: `test/integration/test_controller_playable_loop.gd:240-310`
- Modify: `test/integration/test_hub_progression.gd:120-210,320-420,500-700,720-800`

**Interfaces:**
- Consumes: scan-only `NavigationCursor` from Task 4.
- Preserves: battle `_controller_target`, enemy hover/unhover calls, map reticles, focus neighbors, inventory state, and skill purchase rules.
- Produces: `SkillTreeNode._can_afford: bool`, replacing cursor metadata as purchase authority.

- [ ] **Step 1: Write failing semantic-presentation tests**

Replace battle cursor assertions with existing semantic highlight assertions:

```gdscript
func test_battle_target_change_uses_actor_highlight_without_cursor() -> void:
	var fixture := await _navigation_fixture()
	fixture.manager.current_action = Action.new()
	fixture.enemy.is_valid_target = true
	fixture.scene._set_controller_target(fixture.enemy)
	assert_same(fixture.scene._controller_target, fixture.enemy)
	assert_eq(fixture.manager.enemy_hover_count, 1)
	assert_false(fixture.ux.cursor.visible)
```

Replace hub cursor-state assertions with actual public behavior. Protect purchase authority explicitly:

```gdscript
func test_skill_node_purchase_authority_uses_availability_and_affordability() -> void:
	var ui := preload("res://src/hub/skill_tree_node.tscn").instantiate() as SkillTreeNode
	add_child_autofree(ui)
	await get_tree().process_frame
	ui.set_availability(true, true)
	assert_true(ui.is_purchasable())
	ui.set_availability(true, false)
	assert_false(ui.is_purchasable())
	ui.set_availability(false, true)
	assert_false(ui.is_purchasable())
```

Rename and rewrite the affected existing scenarios as follows:

- `test_inventory_and_equipment_controls_publish_controller_semantics` becomes `test_inventory_and_equipment_controls_use_shared_focus_surfaces` and asserts the Task 2 metadata/style contract.
- `test_inventory_spawn_path_retains_dragging_and_links_every_enabled_slot` becomes `test_inventory_spawn_path_links_every_enabled_slot` and keeps focus-neighbor/activation assertions without cursor-drag state.
- `test_invalid_mod_drop_uses_disabled_cursor_without_focus_override` becomes `test_disabled_mod_slot_cannot_focus_or_activate`; it asserts `button.disabled`, `focus_mode == FOCUS_NONE`, and no `NavigationFocus` state.
- `test_keyboard_and_controller_skill_navigation_synchronize_cursor_through_input_pipeline` becomes `test_keyboard_and_controller_skill_navigation_share_retained_focus`; it asserts focus owner, `PresentationMode`, and focus style without a cursor/warp seam.

- [ ] **Step 2: Run battle, loop, and hub tests and verify they fail**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
```

Expected: failures from removed cursor APIs and old metadata assertions.

- [ ] **Step 3: Remove battle cursor targeting while preserving highlights**

Delete `_update_cursor()` and its call sites. Keep `_set_controller_target()` responsible for unhovering the old enemy, assigning `_controller_target`, hovering the new enemy, and publishing hints:

```gdscript
func _set_controller_target(target: ActorCard) -> void:
	if is_instance_valid(_controller_target) and _controller_target is EnemyCard:
		manager._on_enemy_unhovered(_controller_target as EnemyCard)
	_controller_target = target
	if target is EnemyCard:
		manager._on_enemy_hovered(target as EnemyCard)
	_publish_controller_hints()
```

Restoration and teardown continue to update `_controller_target`; they never show the scan-only cursor.

- [ ] **Step 4: Remove dead cursor-state metadata from hub controls**

In `SkillTreeNode`, store affordability directly:

```gdscript
var _can_afford := false


func set_availability(is_available: bool, can_afford: bool) -> void:
	if state == NodeState.UNLOCKED:
		_can_afford = false
		return
	disabled = false
	_can_afford = is_available and can_afford
	if is_available:
		state = NodeState.AVAILABLE
		modulate = Color.WHITE if can_afford else Color.GAINSBORO
		modulate.a = 1.0
		cost_label.modulate = modulate
	else:
		state = NodeState.LOCKED
		modulate = Color(1, 1, 1, 0.25)


func is_purchasable() -> bool:
	return state == NodeState.AVAILABLE and _can_afford
```

Remove every `cursor_state` assignment from skill, role, party, item, mod, and equipment scripts. Remove `ItemButton.set_dragging()`, `ItemButton.set_drop_validity()`, and their only caller in `InventoryPanel`. Remove `ModSlot.set_drop_validity()` and its redundant caller after `setup()` already establishes enabled state. Do not replace these with no-op compatibility methods.

- [ ] **Step 5: Run focused tests and verify they pass**

Run the Task 5 command again.

Expected: all three scripts pass; `rg -n 'CursorState|cursor_state|set_world_target|set_focus_target|warp_mouse' src test --glob '*.gd'` returns no ordinary-navigation references.

- [ ] **Step 6: Commit Task 5**

```sh
git add src/battle/battle_scene.gd src/hub/skill_tree_node.gd src/hub/role_anchor_node.gd src/hub/item_button.gd src/hub/mod_slot.gd src/hub/equipment_panel.gd src/hub/inventory_panel.gd src/hub/party_menu.gd test/integration/test_battle_controller_navigation.gd test/integration/test_controller_playable_loop.gd test/integration/test_hub_progression.gd
git commit -m "refactor: remove cursor-driven navigation state"
```

---

### Task 6: Cross-system regression coverage and documentation

**Files:**
- Modify: `test/integration/test_navigation_ux_layer.gd`
- Modify: `test/integration/test_standard_focus_navigation.gd`
- Modify: `test/integration/test_dungeon_restore.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`
- Modify: `docs/coordinate-spaces.md:1-80`
- Modify: `docs/testing/controller-manual-checklist.md:1-130`

**Interfaces:**
- Consumes: all production interfaces from Tasks 1-5.
- Produces: complete playable-loop regression coverage and updated manual acceptance criteria.

- [ ] **Step 1: Add the full handoff sequence integration test**

Add one nonduplicative sequence to `test_navigation_ux_layer.gd`, using the Task 3 fixture to exercise the entire contract:

```gdscript
func test_pointer_keyboard_controller_handoffs_preserve_one_logical_focus() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	var top: Button = setup.top
	var middle: Button = setup.middle
	var bottom: Button = setup.bottom
	var bottom_press_count := 0
	bottom.pressed.connect(func() -> void: bottom_press_count += 1)

	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), top)
	get_viewport().push_input(_released_key(KEY_DOWN))
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), middle)
	get_viewport().push_input(_released_key(KEY_DOWN))

	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, true))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), bottom)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_true(ux.pointer_input_blocker.visible)
	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, false))

	get_viewport().push_input(_key(KEY_UP))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), middle)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	get_viewport().push_input(_released_key(KEY_UP))

	InputManager._input(_mouse_motion(Vector2(12, 0)))
	assert_same(ux.get_focus_target(), middle)
	assert_false(NavigationFocus._states.has(middle.get_instance_id()))

	InputManager._input(_joy_direction(JOY_BUTTON_A, true))
	var click_position := bottom.get_global_rect().get_center()
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, true))
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, false))
	await get_tree().process_frame
	assert_eq(bottom_press_count, 0)
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, true))
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, false))
	await get_tree().process_frame
	assert_eq(bottom_press_count, 1)
```

Add the helper used by the final click transaction:

```gdscript
func _mouse_button_at(position: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	return event
```

Use signal counters and concrete focus-owner assertions at each line. Do not duplicate the unit transition matrix or use timing-based waits beyond required process frames.

- [ ] **Step 2: Run all controller/navigation-focused scripts**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_focus -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
```

Expected: exit 0; every selected script passes with no parser errors, crashes, or unexpected engine errors.

- [ ] **Step 3: Update coordinate-space guidance**

Revise `docs/coordinate-spaces.md` to state:

```markdown
- The hardware pointer is always driven by physical mouse input and is never warped by keyboard or controller navigation.
- Ordinary controller navigation hides that pointer and uses GUI focus, map reticles, or actor highlights.
- The scan software pointer is the sole controller-positioned pointer; it consumes an explicit projected screen position and never feeds back into OS pointer state.
- Mouse motion is ignored during controller ownership. A consumed click transaction performs controller-to-mouse ownership handoff.
```

Remove any statement implying that ordinary GUI focus and a software cursor visually overlap.

- [ ] **Step 4: Rewrite manual controller acceptance around focus/pointer ownership**

In `docs/testing/controller-manual-checklist.md`, replace focused-button scaling and semantic-cursor checks with:

```markdown
- [ ] Ordinary controller navigation hides the hardware arrow and shows no snapped cursor on focused buttons.
- [ ] Focused buttons and button-like controls use the clear 70% neutral fill with readable dark foregrounds across title orange, hub blue, terminal, and result palettes.
- [ ] Mouse motion in controller mode changes neither ownership nor visible focus; the first click reveals the independent pointer and activates nothing, while the second click activates exactly once.
- [ ] Mouse motion in keyboard-and-mouse mode hides visible focus but retains its logical origin; the first arrow/WASD press restores that origin and the second moves.
- [ ] Controller direction after pointer presentation hides the pointer and moves immediately; keyboard direction after controller presentation reveals the pointer and moves immediately.
- [ ] Battle uses actor highlighting and dungeon traversal uses its reticle without an ordinary navigation arrow.
- [ ] Security scanning alone shows the controller-positioned software pointer while the hardware pointer remains hidden and physically independent.
```

Retain existing device-family, hot-plug, terminal shortcut, scan-camera, modal, and full-loop checks.

- [ ] **Step 5: Import/parse and run the complete suite**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: both commands exit 0; all assertions pass; no parser errors, crashes, or unexpected failures. The documented macOS CA warning and successful-shutdown leak diagnostics remain acceptable.

- [ ] **Step 6: Record remaining manual verification honestly**

Do not mark hardware checklist boxes without performing them on the named physical device. In the handoff, report the complete automated totals and list controller hardware, couch-distance focus clarity, hover suppression, first-click consumption, and scan-pointer independence as remaining manual checks if they were not performed.

- [ ] **Step 7: Commit Task 6**

```sh
git add test/integration/test_navigation_ux_layer.gd test/integration/test_standard_focus_navigation.gd test/integration/test_dungeon_restore.gd test/integration/test_battle_controller_navigation.gd test/integration/test_controller_playable_loop.gd docs/coordinate-spaces.md docs/testing/controller-manual-checklist.md
git commit -m "test: cover input ownership handoffs"
```

---

## Final Acceptance

- [ ] `rg -n 'CursorBehavior|cursor_state|expect_mouse_warp|warp_mouse|set_focus_target|set_world_target' src test --glob '*.gd'` reports no removed ordinary-navigation API usage.
- [ ] `git status --short` contains only intentional task changes and required Godot sidecars.
- [ ] The focused test command and complete suite both exit 0.
- [ ] The final handoff reports exact test/assertion totals and separates unperformed physical-controller checks.
- [ ] The deferred controls hint-bar typography/panel redesign remains unchanged and is called out as follow-up work.
