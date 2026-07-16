# Hub Controller Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a controller-first party-management shell with four top tabs, immediate vertical hero selection, explicit hero/content depth, pulsing exact focus, chrome-only depth emphasis, and deterministic focus restoration.

**Architecture:** `PartyMenu` owns top-level tab and depth state while Roles and Items expose narrow focus-memory and cancellation boundaries. Existing shared navigation and glyph systems gain opt-in hub behavior: pulsing focus styles and controller-only shoulder glyphs. Hub components expose chrome surfaces so inactive borders darken without changing content opacity.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` scenes, vendored GUT 9.6.1, existing `NavigationUXLayer`, `NavigationFocus`, `DynamicGlyph`, and `DisplayProfileService`.

## Global Constraints

- Use Godot 4.6.3; Godot 4.7 remains unsupported because of known iOS visual issues.
- Use `HOME=/tmp/mars-godot-home` for every automated Godot command.
- Preserve direct mouse/touch activation and the established controller-to-pointer handoff rules.
- Do not add hub-specific keyboard shortcuts or keyboard glyph substitutions for shoulder controls.
- Do not change progression rules, equipment transactions, inventory contents, or save formats.
- Options and Journal contain only centered `COMING SOON` informational views.
- Preserve required `.uid` and `.import` sidecars created by Godot; never commit `.godot/`.
- Preserve the unrelated existing modification to `src/map/dungeon_map.tscn` and exclude it from every task commit.
- Support and verify `1920x1080` desktop and `1280x800` compact output.

---

## File Structure

### New files

- `src/hub/hub_chrome.gd` — duplicates authored `StyleBoxFlat` resources and changes only border/shadow energy.
- `src/hub/hub_coming_soon.tscn` — reusable centered informational content for Options and Journal.
- `test/unit/test_hub_chrome.gd` — protects chrome-only dimming and restoration.

### Modified runtime files

- `project.godot` — replaces the old page/section shortcuts with four controller-only hub actions.
- `src/singletons/input_map.gd` — maps those actions to L1/R1/L2/R2 glyphs for every controller family, with no keyboard mapping.
- `src/battle/dynamic_glyph.gd` — adds opt-in controller-only fade behavior that retains layout space.
- `src/ui/navigation/navigation_focus.gd` — adds an opt-in pulsing fill while preserving the existing default focus style.
- `src/hub/party_menu.tscn` / `src/hub/party_menu.gd` — own tabs, selected hero, navigation depth, stubs, routing, and restoration.
- `src/hub/hero_panel.tscn` / `src/hub/hero_panel.gd` — become ordinary focus targets, request content entry, and expose Items focus/chrome helpers.
- `src/hub/skill_tree_panel.tscn` / `src/hub/skill_tree_panel.gd` — remap role switching, connect rank-page controls, and expose focus restoration.
- `src/hub/role_panel.gd`, `src/hub/skill_tree_node.gd`, `src/hub/role_anchor_node.gd` — opt into pulse and chrome presentation.
- `src/hub/inventory_panel.gd`, `src/hub/item_button.gd`, `src/hub/equipment_panel.gd`, `src/hub/mod_slot.gd` — expose stable Items focus identity and chrome surfaces.
- `docs/testing/controller-manual-checklist.md` — replace obsolete shoulder bindings and add the approved visual/input checks.

### Modified tests

- `test/unit/test_input_manager.gd`
- `test/unit/test_dynamic_glyph.gd`
- `test/unit/test_navigation_focus.gd`
- `test/integration/test_hub_progression.gd`
- `test/integration/test_hub_responsive_layout.gd`
- `test/integration/test_standard_focus_navigation.gd`
- `test/integration/test_controller_playable_loop.gd`

---

### Task 1: Semantic Hub Shoulder Actions and Controller-Only Glyphs

**Files:**
- Modify: `project.godot:135-158`
- Modify: `src/singletons/input_map.gd:23-87`
- Modify: `src/singletons/input_manager.gd:32-107`
- Modify: `src/battle/dynamic_glyph.gd:1-46`
- Test: `test/unit/test_input_manager.gd:287-307`
- Test: `test/unit/test_dynamic_glyph.gd`

**Interfaces:**
- Produces: `hub_tab_previous`, `hub_tab_next`, `hub_role_previous`, and `hub_role_next` `InputMap` actions.
- Produces: `DynamicGlyph.controller_only: bool`, `DynamicGlyph.fade_duration: float`, and existing `set_action(action: StringName) -> void` behavior.
- Consumes: `InputManager.input_mode_changed`, `InputManager.controller_type_changed`, and `InputIconMap.get_glyph(type, action)`.

- [ ] **Step 1: Write failing semantic-action tests**

Replace the old page/section assertions in `test_input_manager.gd` with controller-only hub expectations:

```gdscript
func test_hub_shoulder_actions_are_controller_only() -> void:
	var expected := {
		&"hub_tab_previous": [JOY_AXIS_TRIGGER_LEFT, -1],
		&"hub_tab_next": [JOY_AXIS_TRIGGER_RIGHT, -1],
		&"hub_role_previous": [-1, JOY_BUTTON_LEFT_SHOULDER],
		&"hub_role_next": [-1, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: StringName in expected:
		assert_true(InputMap.has_action(action), str(action))
		assert_eq(InputMap.action_get_events(action).filter(func(event): return event is InputEventKey).size(), 0, "%s has no keyboard shortcut" % action)
		if expected[action][0] >= 0:
			assert_true(_has_joy_axis(action, expected[action][0], 1.0), str(action))
		else:
			assert_true(_has_joy_button(action, expected[action][1]), str(action))
	assert_false(InputMap.has_action(&"page_previous"))
	assert_false(InputMap.has_action(&"page_next"))
	assert_false(InputMap.has_action(&"section_previous"))
	assert_false(InputMap.has_action(&"section_next"))
```

Update `test_required_semantic_actions_exist()` to list the four new actions and omit the four removed actions.

Also add touch ownership coverage:

```gdscript
func test_touch_press_leaves_controller_mode_and_selects_pointer_presentation() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	manager._input(touch)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
```

- [ ] **Step 2: Write failing controller-only glyph tests**

Append to `test_dynamic_glyph.gd`:

```gdscript
func test_controller_only_glyph_keeps_controller_texture_and_layout_in_keyboard_mode() -> void:
	var glyph := DynamicGlyph.new()
	glyph.controller_only = true
	glyph.fade_duration = 0.0
	add_child_autofree(glyph)
	glyph.set_action(&"hub_tab_previous")
	glyph.refresh(true, InputIconMap.ControllerType.PLAYSTATION)
	assert_true(glyph.visible)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "playstation_trigger_l2.svg")
	assert_eq(glyph.modulate.a, 1.0)
	glyph.refresh(false, InputIconMap.ControllerType.PLAYSTATION)
	assert_true(glyph.visible, "retains layout space")
	assert_eq(glyph.texture_normal.resource_path.get_file(), "playstation_trigger_l2.svg")
	assert_eq(glyph.modulate.a, 0.0)


func test_controller_only_glyph_resolves_every_runtime_family() -> void:
	for family: InputIconMap.ControllerType in InputIconMap.runtime_controller_types():
		if family == InputIconMap.ControllerType.KEYBOARD_MOUSE:
			continue
		for action: StringName in [&"hub_tab_previous", &"hub_tab_next", &"hub_role_previous", &"hub_role_next"]:
			assert_not_null(InputIconMap.get_glyph(family, action), "%s %s" % [family, action])
```

- [ ] **Step 3: Run focused tests and confirm the red state**

Run:

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_input_manager|test_dynamic_glyph" -gexit
```

Expected: failures report missing new actions/glyphs and missing `controller_only` behavior; no parser errors.

- [ ] **Step 4: Replace the old project actions with controller-only hub actions**

In `project.godot`, replace `page_previous`, `page_next`, `section_previous`, and `section_next` with actions containing only these controller events:

```text
hub_tab_previous: InputEventJoypadMotion axis=4 axis_value=1.0
hub_tab_next: InputEventJoypadMotion axis=5 axis_value=1.0
hub_role_previous: InputEventJoypadButton button_index=9
hub_role_next: InputEventJoypadButton button_index=10
```

Do not add `InputEventKey` entries.

- [ ] **Step 5: Add glyph mappings for every controller family**

Add these keys inside each non-keyboard `GLYPH_FILES` family in `input_map.gd`; do not add them to `KEYBOARD_MOUSE`:

```gdscript
&"hub_tab_previous": "xbox_lt.svg", &"hub_tab_next": "xbox_rt.svg",
&"hub_role_previous": "xbox_lb.svg", &"hub_role_next": "xbox_rb.svg",
```

Use the family-equivalent files:

```text
PlayStation: playstation_trigger_l2/r2/l1/r1.svg
Nintendo: switch_button_zl/zr/l/r.svg
Steam Controller: controller_button_l2/r2/l1/r1.svg
Steam Deck: steamdeck_button_l2/r2/l1/r1.svg
Xbox: xbox_lt/rt/lb/rb.svg
```

- [ ] **Step 6: Implement opt-in controller-only fading**

Extend `DynamicGlyph` without changing its default behavior:

```gdscript
@export var controller_only := false
@export var fade_duration := 0.18
var _fade_tween: Tween


func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	if controller_only:
		var glyph := InputIconMap.get_glyph(family, action)
		if glyph == null:
			_clear_texture()
			return
		_set_texture(glyph)
		show()
		_fade_to(1.0 if show_controller_glyph else 0.0)
		return
	var resolved_family := family if show_controller_glyph else InputIconMap.ControllerType.KEYBOARD_MOUSE
	var glyph := InputIconMap.get_glyph(resolved_family, action)
	if glyph == null:
		_clear_texture()
		return
	_set_texture(glyph)
	show()
	modulate.a = 1.0


func _set_texture(glyph: Texture2D) -> void:
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph


func _fade_to(alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade_duration <= 0.0:
		modulate.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

Kill `_fade_tween` from `_exit_tree()` and make `_clear_texture()` reset `modulate.a = 0.0 if controller_only else 1.0`.

In `InputManager`, classify a pressed `InputEventScreenTouch` as meaningful pointer ownership and handle it before the mouse-button branch:

```gdscript
if event is InputEventScreenTouch:
	_set_active_mode(InputMode.KEYBOARD_MOUSE)
	_set_presentation_mode(PresentationMode.POINTER)
	return
```

Add `if event is InputEventScreenTouch: return event.pressed` to `is_meaningful_event()`. Do not consume the touch transaction; the pressed control continues through Godot's normal touch GUI path.

- [ ] **Step 7: Run focused tests and import validation**

Run the command from Step 3, then:

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: selected tests pass; import exits `0` with no parser errors.

- [ ] **Step 8: Commit Task 1**

```sh
git add project.godot src/singletons/input_map.gd src/singletons/input_manager.gd src/battle/dynamic_glyph.gd test/unit/test_input_manager.gd test/unit/test_dynamic_glyph.gd
git commit -m "feat: add controller-only hub shoulder actions"
```

---

### Task 2: Opt-In Hub Pulse and Chrome-Only Depth Styling

**Files:**
- Create: `src/hub/hub_chrome.gd`
- Create: `src/hub/hub_chrome.gd.uid` through Godot import
- Modify: `src/ui/navigation/navigation_focus.gd`
- Test: `test/unit/test_navigation_focus.gd`
- Test: `test/unit/test_hub_chrome.gd`

**Interfaces:**
- Produces: metadata key `navigation_focus_pulse: bool` recognized by `NavigationFocus.apply(control)`.
- Produces: `HubChrome.capture(surface: Control, style_name: StringName = &"panel") -> void`.
- Produces: `HubChrome.set_base_style(surface: Control, style: StyleBoxFlat, style_name: StringName = &"panel") -> void`.
- Produces: `HubChrome.get_base_style(surface: Control) -> StyleBoxFlat`.
- Produces: `HubChrome.set_active(surface: Control, active: bool, energy: float = 0.22) -> void`.
- Consumes: `StyleBoxFlat.border_color`, `StyleBoxFlat.shadow_color`, and existing NavigationFocus state restoration.

- [ ] **Step 1: Write failing pulse tests**

Append to `test_navigation_focus.gd`:

```gdscript
func test_opt_in_hub_focus_uses_pulsing_fill_and_default_focus_does_not() -> void:
	var pulsing := Button.new()
	pulsing.set_meta("navigation_focus_pulse", true)
	add_child_autofree(pulsing)
	NavigationFocus.apply(pulsing)
	var pulse_state: Dictionary = NavigationFocus._states[pulsing.get_instance_id()]
	assert_true(pulse_state.has("tween"))
	assert_not_null(pulse_state.tween)
	var style := pulsing.get_theme_stylebox(&"focus") as StyleBoxFlat
	assert_almost_eq(style.bg_color.a, 0.45, 0.001)
	NavigationFocus.clear(pulsing)
	assert_false(NavigationFocus._states.has(pulsing.get_instance_id()))

	var ordinary := Button.new()
	add_child_autofree(ordinary)
	NavigationFocus.apply(ordinary)
	assert_false(NavigationFocus._states[ordinary.get_instance_id()].has("tween"))
	NavigationFocus.clear(ordinary)
```

- [ ] **Step 2: Write failing chrome tests**

Create `test/unit/test_hub_chrome.gd`:

```gdscript
extends GutTest


func test_inactive_chrome_darkens_only_edges_and_restores_authored_style() -> void:
	var surface := Panel.new()
	var authored := StyleBoxFlat.new()
	authored.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	authored.border_color = Color(0.8, 1.0, 0.2, 1.0)
	authored.shadow_color = Color(0.8, 1.0, 0.2, 0.5)
	surface.add_theme_stylebox_override(&"panel", authored)
	add_child_autofree(surface)
	HubChrome.capture(surface)
	HubChrome.set_active(surface, false)
	var inactive := surface.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(inactive.bg_color, authored.bg_color)
	assert_lt(inactive.border_color.get_luminance(), authored.border_color.get_luminance())
	assert_lt(inactive.shadow_color.get_luminance(), authored.shadow_color.get_luminance())
	HubChrome.set_active(surface, true)
	var restored := surface.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(restored.bg_color, authored.bg_color)
	assert_eq(restored.border_color, authored.border_color)
	assert_eq(restored.shadow_color, authored.shadow_color)
```

- [ ] **Step 3: Run focused tests and confirm the red state**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_navigation_focus|test_hub_chrome" -gexit
```

Expected: failures report missing pulse state and missing `HubChrome`; no parser errors.

- [ ] **Step 4: Implement opt-in pulse lifecycle**

In `navigation_focus.gd`, duplicate `FOCUS_STYLE` per application, add it to the saved state, and start a surface-owned tween only for metadata opt-in:

```gdscript
const HUB_PULSE_LOW_ALPHA := 0.45
const HUB_PULSE_HIGH_ALPHA := 0.80


static func _focus_style_and_tween(control: Control, surface: Control) -> Dictionary:
	var style := FOCUS_STYLE.duplicate() as StyleBoxFlat
	if not bool(control.get_meta("navigation_focus_pulse", false)):
		return {"style": style}
	style.bg_color.a = HUB_PULSE_LOW_ALPHA
	var tween := surface.create_tween().set_loops()
	tween.tween_property(style, "bg_color:a", HUB_PULSE_HIGH_ALPHA, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(style, "bg_color:a", HUB_PULSE_LOW_ALPHA, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return {"style": style, "tween": tween}
```

Call this helper before saving `_states`, store the returned `tween` when present, apply the returned style, and kill the tween at the start of `clear()` and `_release_state()` when valid. Preserve every existing label/style restoration field.

- [ ] **Step 5: Implement `HubChrome`**

Create `src/hub/hub_chrome.gd`:

```gdscript
extends RefCounted
class_name HubChrome

const BASE_STYLE_META := &"hub_chrome_base_style"
const STYLE_NAME_META := &"hub_chrome_style_name"
const ACTIVE_META := &"hub_chrome_active"


static func capture(surface: Control, style_name: StringName = &"panel") -> void:
	if not is_instance_valid(surface):
		return
	var style := surface.get_theme_stylebox(style_name) as StyleBoxFlat
	if style == null:
		return
	set_base_style(surface, style, style_name)


static func set_base_style(surface: Control, style: StyleBoxFlat, style_name: StringName = &"panel") -> void:
	if not is_instance_valid(surface) or style == null:
		return
	surface.set_meta(BASE_STYLE_META, style.duplicate())
	surface.set_meta(STYLE_NAME_META, style_name)
	set_active(surface, bool(surface.get_meta(ACTIVE_META, true)))


static func get_base_style(surface: Control) -> StyleBoxFlat:
	if not is_instance_valid(surface):
		return null
	if not surface.has_meta(BASE_STYLE_META):
		capture(surface)
	var base := surface.get_meta(BASE_STYLE_META, null) as StyleBoxFlat
	return base.duplicate() as StyleBoxFlat if base else null


static func set_active(surface: Control, active: bool, energy: float = 0.22) -> void:
	if not is_instance_valid(surface):
		return
	if not surface.has_meta(BASE_STYLE_META):
		capture(surface)
	var base := surface.get_meta(BASE_STYLE_META) as StyleBoxFlat
	if base == null:
		return
	surface.set_meta(ACTIVE_META, active)
	var style_name: StringName = surface.get_meta(STYLE_NAME_META, &"panel")
	var style := base.duplicate() as StyleBoxFlat
	if not active:
		style.border_color = _edge_color(base.border_color, energy)
		style.shadow_color = _edge_color(base.shadow_color, energy)
	surface.add_theme_stylebox_override(style_name, style)


static func _edge_color(color: Color, energy: float) -> Color:
	return Color(color.r * energy, color.g * energy, color.b * energy, color.a)
```

- [ ] **Step 6: Run tests and import**

Run the focused command from Step 3 and the isolated import command from Task 1 Step 7.

Expected: all selected tests pass and import exits `0`.

- [ ] **Step 7: Commit Task 2**

```sh
git add src/hub/hub_chrome.gd src/hub/hub_chrome.gd.uid src/ui/navigation/navigation_focus.gd test/unit/test_navigation_focus.gd test/unit/test_hub_chrome.gd
git commit -m "feat: add pulsing hub focus presentation"
```

---

### Task 3: Four-Tab Party Shell and Hero/Content Depth

**Files:**
- Create: `src/hub/hub_coming_soon.tscn`
- Modify: `src/hub/party_menu.tscn`
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/hero_panel.tscn`
- Modify: `src/hub/hero_panel.gd`
- Test: `test/integration/test_hub_progression.gd`
- Test: `test/integration/test_standard_focus_navigation.gd`

**Interfaces:**
- Produces: `PartyMenu.Tab { ROLES, ITEMS, OPTIONS, JOURNAL }`.
- Produces: `PartyMenu.Depth { HERO_RAIL, CONTENT }` and `current_depth: Depth`.
- Produces: `PartyMenu.change_tab(delta: int) -> void`, `enter_content() -> bool`, and `return_to_hero_rail() -> void`.
- Produces: `HeroPanel.content_requested(hero_panel: HeroPanel)` signal and `set_chrome_active(active: bool) -> void`.
- Consumes: actions from Task 1, pulse metadata from Task 2, and `NavigationUXLayer.push_modal()`.

- [ ] **Step 1: Write failing shell and hero-depth tests**

Add a focused fixture and tests to `test_hub_progression.gd`:

```gdscript
func test_party_opens_on_expanded_hero_and_up_down_select_immediately() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
	assert_eq(party.current_hero_idx, 0)
	assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(0))
	party.hero_list_container.get_child(1).grab_focus()
	await get_tree().process_frame
	assert_eq(party.current_hero_idx, 1)
	assert_true((party.hero_list_container.get_child(1) as HeroPanel)._is_expanded)
	assert_false((party.hero_list_container.get_child(0) as HeroPanel)._is_expanded)


func test_party_content_entry_back_and_stub_tabs_keep_focus_valid() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	assert_true(party.skill_view.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.ITEMS)
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.OPTIONS)
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
	assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(party.current_hero_idx))
	assert_true(party.get_node("Content/OptionsComingSoon").visible)
	party.change_tab(1)
	assert_true(party.get_node("Content/JournalComingSoon").visible)
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.ROLES)


func test_pointer_tab_and_hero_selection_update_controller_context() -> void:
	var party := await _opened_party_with_three_heroes()
	party.tab_buttons[PartyMenu.Tab.ITEMS].pressed.emit()
	assert_eq(party.current_tab, PartyMenu.Tab.ITEMS)
	var second := party.hero_list_container.get_child(1) as HeroPanel
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	second._gui_input(click)
	assert_eq(party.current_hero_idx, 1)
	party.return_to_hero_rail()
	assert_same(get_viewport().gui_get_focus_owner(), second)
```

Add this fixture using duplicate production heroes and restoring `SaveSystem.party_roster` in teardown:

```gdscript
func _opened_party_with_three_heroes() -> PartyMenu:
	SaveSystem.party_roster.assign([
		load("res://data/heroes/asher/asher.tres").duplicate(true),
		load("res://data/heroes/echo/echo.tres").duplicate(true),
		load("res://data/heroes/sands/sands.tres").duplicate(true),
	])
	var party := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child_autofree(party)
	party.open()
	await get_tree().process_frame
	return party
```

- [ ] **Step 2: Replace obsolete standard-focus tests**

In `test_standard_focus_navigation.gd`, replace tests that expect bottom Roles/Items/Back focus neighbors with:

```gdscript
func test_party_tab_strip_is_clickable_but_controller_default_is_selected_hero() -> void:
	_add_ux()
	SaveSystem.party_roster.assign([load("res://data/heroes/asher/asher.tres").duplicate(true)])
	var hub := HubScene.instantiate() as Hub
	add_child_autofree(hub)
	await get_tree().process_frame
	hub.party_menu.open()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), hub.party_menu.hero_list_container.get_child(0))
	for button: Button in hub.party_menu.tab_buttons:
		assert_true(button.visible)
		assert_false(button.disabled)
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(hub.party_menu.back_button.focus_mode, Control.FOCUS_NONE)
```

- [ ] **Step 3: Run focused tests and confirm the red state**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_hub_progression|test_standard_focus_navigation" -gexit
```

Expected: failures report missing tabs/depth APIs and the old default tab focus.

- [ ] **Step 4: Build the top tab strip and stub views**

In `party_menu.tscn`:

- move `Header` to the top safe area;
- replace `ModeTabs/Skills` and `ModeTabs/Inventory` with `TabStrip/PreviousGlyph`, four toggle buttons named `Roles`, `Items`, `Options`, `Journal`, and `NextGlyph`;
- assign controller-only `DynamicGlyph` nodes the `hub_tab_previous` and `hub_tab_next` actions;
- make all four tab buttons `FOCUS_NONE` so they remain directly clickable without entering the D-pad focus graph;
- make both display-only glyphs `FOCUS_NONE` with `mouse_filter = MOUSE_FILTER_IGNORE`, and retain their layout space at both sides of the strip;
- remove the bottom mode-tab container;
- retain the clickable Back button for pointer/touch users, but set it to `FOCUS_NONE` because controller Back is handled semantically;
- instance two copies of `hub_coming_soon.tscn` under `Content` as `OptionsComingSoon` and `JournalComingSoon`.

Create `hub_coming_soon.tscn` as a full-rect `CenterContainer` containing a non-focusable Label with `text = "COMING SOON"`, `mouse_filter = MOUSE_FILTER_IGNORE`, and the existing bold monospace font.

- [ ] **Step 5: Make hero panels focusable and emit content entry**

In `hero_panel.tscn`, set the root `HeroPanel.focus_mode = Control.FOCUS_ALL`. In `hero_panel.gd`:

```gdscript
signal content_requested(hero_panel: HeroPanel)


func _ready() -> void:
	DisplayProfile.bind(apply_display_profile)
	set_meta("navigation_focus_surface", NodePath("Content/Header"))
	set_meta("navigation_focus_pulse", true)
	custom_minimum_size.y = collapsed_y
	# Preserve the existing equipment signal connections below this setup.


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)
		return
	if has_focus() and (event.is_action_pressed(&"confirm") or event.is_action_pressed(&"nav_right")):
		get_viewport().set_input_as_handled()
		content_requested.emit(self)


func set_chrome_active(active: bool) -> void:
	HubChrome.set_active($Content/Header, active)
```

Capture the header style after display-profile sizing so compact border dimensions remain authoritative.

- [ ] **Step 6: Implement PartyMenu tab/depth state and focus routing**

Add the state and tab descriptors:

```gdscript
enum Tab { ROLES, ITEMS, OPTIONS, JOURNAL }
enum Depth { HERO_RAIL, CONTENT }

@onready var tab_buttons: Array[Button] = [
	$Header/TabStrip/Roles,
	$Header/TabStrip/Items,
	$Header/TabStrip/Options,
	$Header/TabStrip/Journal,
]

var current_tab: Tab = Tab.ROLES
var current_depth: Depth = Depth.HERO_RAIL
var _content_focus_memory: Dictionary = {}
```

Connect tab presses, hero `focus_entered`, `panel_selected`, and `content_requested`. Implement:

```gdscript
func change_tab(delta: int) -> void:
	if delta == 0:
		return
	_store_content_focus()
	current_tab = posmod(int(current_tab) + delta, tab_buttons.size())
	if current_tab in [Tab.OPTIONS, Tab.JOURNAL]:
		current_depth = Depth.HERO_RAIL
	_update_active_view()
	if current_depth == Depth.CONTENT and current_tab in [Tab.ROLES, Tab.ITEMS]:
		_restore_content_focus()
	else:
		_focus_selected_hero()


func enter_content() -> bool:
	if current_tab in [Tab.OPTIONS, Tab.JOURNAL]:
		return false
	current_depth = Depth.CONTENT
	_update_depth_presentation()
	return _restore_content_focus()


func return_to_hero_rail() -> void:
	_store_content_focus()
	current_depth = Depth.HERO_RAIL
	_update_depth_presentation()
	_focus_selected_hero()


func _content_memory_key() -> String:
	return "%s:%d" % [party_roster[current_hero_idx].hero_id, int(current_tab)]


func _store_content_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner and is_ancestor_of(owner):
		_content_focus_memory[_content_memory_key()] = get_path_to(owner)


func _restore_content_focus() -> bool:
	var remembered := get_node_or_null(_content_focus_memory.get(_content_memory_key(), NodePath())) as Control
	if _is_valid_focus(remembered):
		remembered.grab_focus()
		return true
	if current_tab == Tab.ROLES:
		return skill_view.focus_node("")
	if current_tab == Tab.ITEMS:
		var panel := _get_panel_by_index(current_hero_idx)
		var fallback := _first_focusable_descendant(panel)
		if fallback:
			fallback.grab_focus()
			return true
	return false


func _first_focusable_descendant(root: Control) -> Control:
	if root == null:
		return null
	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if _is_valid_focus(control):
			return control
	return null


func _is_valid_focus(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled)
```

`_on_hero_panel_selected()` must select and expand immediately whether invoked by mouse or `focus_entered`. `_refresh_hero_list()` must set explicit wrapping `focus_neighbor_top/bottom` paths after every panel is added. `open()` must push the modal with the selected HeroPanel, not a tab button.

Route `hub_tab_previous/next` before ordinary focus activation in `_unhandled_input`. Back first delegates to nested content cancellation, then calls `return_to_hero_rail()`, then closes from `HERO_RAIL`. Left returns to the hero rail only from content.

- [ ] **Step 7: Implement view and depth presentation**

Update `_update_active_view()` to show exactly one of Roles, Items, Options, or Journal and set the corresponding tab pressed without emitting signals. Add:

```gdscript
func _update_depth_presentation() -> void:
	for index in range(hero_list_container.get_child_count()):
		var panel := hero_list_container.get_child(index) as HeroPanel
		panel.set_chrome_active(current_depth == Depth.HERO_RAIL or index == current_hero_idx)
```

This task deliberately changes hero chrome only. Roles and Items add their own concrete chrome surfaces in their independently tested tasks.

- [ ] **Step 8: Run focused tests and import**

Run Step 3 and the isolated import command.

Expected: selected tests pass; no null focus, parser error, or modal leak.

- [ ] **Step 9: Commit Task 3**

```sh
git add src/hub/hub_coming_soon.tscn src/hub/party_menu.tscn src/hub/party_menu.gd src/hub/hero_panel.tscn src/hub/hero_panel.gd test/integration/test_hub_progression.gd test/integration/test_standard_focus_navigation.gd
git commit -m "feat: add controller-first party menu shell"
```

---

### Task 4: Roles Remapping, Rank-Page Access, and Focus Memory

**Files:**
- Modify: `src/hub/skill_tree_panel.tscn`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/role_panel.tscn`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/skill_tree_node.gd`
- Modify: `src/hub/role_anchor_node.gd`
- Modify: `src/hub/party_menu.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Produces: `SkillTreePanel.restore_focus() -> bool`, `remember_focus() -> String`, `set_chrome_active(active: bool) -> void`, and `cancel_navigation() -> bool`.
- Consumes: `hub_role_previous/next`, `HubChrome`, `NavigationFocus` pulse metadata, and existing stable node IDs.

- [ ] **Step 1: Write failing Roles behavior tests**

Add to `test_hub_progression.gd`:

```gdscript
func test_roles_use_bumpers_and_rank_pages_are_spatial() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var role_before := panel.current_role_idx
	panel._unhandled_input(_action_event(&"hub_role_next"))
	assert_eq(panel.current_role_idx, posmod(role_before + 1, panel.role_list_container.get_child_count()))
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	assert_true(panel.move_focus(Vector2.DOWN) or panel.focus_current_page_tab())
	assert_true(panel.tabs_container.is_ancestor_of(get_viewport().gui_get_focus_owner()) or get_viewport().gui_get_focus_owner() in panel.tabs_container.get_children())
	assert_true(panel.focus_node_from_page_tabs())
	assert_true(panel._node_owns_focus())


func test_roles_restore_stable_node_per_hero_role_and_page() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.focus_node("gun.atk_1"))
	var remembered := panel.remember_focus()
	assert_eq(remembered, "gun.atk_1")
	panel.change_role(1)
	panel.change_role(-1)
	assert_true(panel.restore_focus())
	assert_eq(panel.focused_node_id, "gun.atk_1")
```

- [ ] **Step 2: Run Roles tests and confirm the red state**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_hub_progression|test_skill_tree_navigation" -gexit
```

Expected: missing new APIs and old shoulder routing fail.

- [ ] **Step 3: Connect and constrain visible rank-page buttons**

In `_ready()`, connect every page button exactly once and mark it for hub pulse:

```gdscript
func _ready() -> void:
	DisplayProfile.bind(apply_display_profile)
	for index in range(tabs_container.get_child_count()):
		var button := tabs_container.get_child(index) as Button
		button.pressed.connect(_on_tab_pressed.bind(index))
		button.set_meta("navigation_focus_pulse", true)
```

When refreshing a role, show only `_supported_pages(_current_role_panel())`; disable and hide every other page button. Assign left/right neighbors among visible buttons only.

In `role_panel.tscn`, add controller-only `DynamicGlyph` nodes named `PreviousRoleGlyph` and `NextRoleGlyph` inside the role header, with actions `hub_role_previous` and `hub_role_next`. Reserve their space on opposite sides of the centered role name. In `RolePanel.set_expanded()`, show the glyph containers only for the expanded role. Add:

```gdscript
func set_role_shortcuts_enabled(enabled: bool) -> void:
	$Content/PreviousRoleGlyph.visible = enabled and is_currently_expanded
	$Content/NextRoleGlyph.visible = enabled and is_currently_expanded
```

After every role refresh or switch, `SkillTreePanel` calls `set_role_shortcuts_enabled(role_list_container.get_child_count() > 1)` on each panel. The DynamicGlyph nodes themselves retain layout space across controller/keyboard ownership; only collapsed role panels suppress the containers.

- [ ] **Step 4: Replace shoulder routing and add spatial page transitions**

Replace the old section/page branches:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"hub_role_previous"):
		change_role(-1)
	elif event.is_action_pressed(&"hub_role_next"):
		change_role(1)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_up"):
		move_focus(Vector2.UP)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_down"):
		if not move_focus(Vector2.DOWN):
			focus_current_page_tab()
	elif _node_owns_focus() and event.is_action_pressed(&"nav_left"):
		move_focus(Vector2.LEFT)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_right"):
		move_focus(Vector2.RIGHT)
	elif _page_tabs_own_focus() and event.is_action_pressed(&"nav_up"):
		focus_node_from_page_tabs()
	elif _node_owns_focus() and event.is_action_pressed(&"confirm"):
		confirm_focused_node()
	else:
		return
	get_viewport().set_input_as_handled()
```

Implement:

```gdscript
func focus_current_page_tab() -> bool:
	var button := tabs_container.get_child(current_page) as Button
	if button == null or not button.visible or button.disabled:
		return false
	button.grab_focus()
	return true


func focus_node_from_page_tabs() -> bool:
	return focus_node(_remembered_node_for_current_context())


func _page_tabs_own_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and (owner == tabs_container or tabs_container.is_ancestor_of(owner))
```

Do not make Back move node focus into the page strip; PartyMenu owns Back-to-hero behavior.

- [ ] **Step 5: Expose Roles focus/chrome boundaries**

Add:

```gdscript
func remember_focus() -> String:
	_store_focus_memory()
	_store_hero_context()
	return focused_node_id


func restore_focus() -> bool:
	return focus_node(_remembered_node_for_current_context())


func cancel_navigation() -> bool:
	return false


func set_chrome_active(active: bool) -> void:
	for child in role_list_container.get_children():
		if child is RolePanel:
			(child as RolePanel).set_chrome_active(active)
```

In `RolePanel`, capture its Header chrome and forward activity to generated nodes. In `SkillTreeNode` and `RoleAnchorNode`, set `navigation_focus_surface` to their `Panel`, set `navigation_focus_pulse = true`, capture that panel with `HubChrome`, and expose `set_chrome_active(active)`.

Replace PartyMenu's generic Roles path memory with stable Roles memory and extend depth presentation:

```gdscript
func _store_roles_focus() -> void:
	_content_focus_memory[_content_memory_key()] = skill_view.remember_focus()


func _restore_roles_focus() -> bool:
	return skill_view.restore_focus()


func _update_depth_presentation() -> void:
	for index in range(hero_list_container.get_child_count()):
		var panel := hero_list_container.get_child(index) as HeroPanel
		panel.set_chrome_active(current_depth == Depth.HERO_RAIL or index == current_hero_idx)
	skill_view.set_chrome_active(current_depth == Depth.CONTENT and current_tab == Tab.ROLES)
```

Route `_store_content_focus()` and `_restore_content_focus()` through these functions when `current_tab == Tab.ROLES`; retain the generic Task 3 path for Items until its focused task replaces it.

- [ ] **Step 6: Update Roles action hints**

Replace `section_previous`/`page_previous` hints with the controller-only role action:

```gdscript
var hints: Array[Dictionary] = [
	{action = &"confirm", label = "Upgrade" if purchasable else "Inspect", enabled = purchasable or inspectable},
	{action = &"cancel", label = "Back", enabled = true},
	{action = &"hub_role_previous", label = "Role", enabled = role_list_container.get_child_count() > 1},
]
```

The top embedded glyphs communicate tab switching; do not add global hint-bar tab entries.

- [ ] **Step 7: Run focused tests and import**

Run Step 2 and isolated import.

Expected: all selected tests pass; roles wrap, rank pages remain reachable, and node IDs restore.

- [ ] **Step 8: Commit Task 4**

```sh
git add src/hub/skill_tree_panel.tscn src/hub/skill_tree_panel.gd src/hub/role_panel.tscn src/hub/role_panel.gd src/hub/skill_tree_node.gd src/hub/role_anchor_node.gd src/hub/party_menu.gd test/integration/test_hub_progression.gd
git commit -m "feat: remap hub role and rank navigation"
```

---

### Task 5: Items Focus Identity, Nested Back, and Chrome Integration

**Files:**
- Modify: `src/hub/hero_panel.gd`
- Modify: `src/hub/inventory_panel.gd`
- Modify: `src/hub/item_button.gd`
- Modify: `src/hub/equipment_panel.gd`
- Modify: `src/hub/mod_slot.gd`
- Modify: `src/hub/party_menu.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Produces: `HeroPanel.items_default_focus() -> Control`, `items_focus_key(control: Control) -> String`, and `restore_items_focus(key: String) -> bool`.
- Produces: `InventoryPanel.focus_key(control: Control) -> String`, `restore_focus(key: String) -> bool`, `default_focus() -> Control`, and real `set_chrome_active(active: bool)`.
- Produces: `ItemButton.get_focus_key() -> String`.
- Consumes: existing `InventoryPanel.cancel_navigation() -> bool` and item/equipment stable IDs.

- [ ] **Step 1: Write failing Items restoration and Back tests**

Add to `test_hub_progression.gd`:

```gdscript
func test_items_back_unwinds_mode_before_returning_to_hero() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(party.current_hero_idx) as HeroPanel
	party.inventory_view.request_equip_mode(hero_panel.data.weapon, Equipment.Slot.WEAPON)
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.EQUIP)
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.VIEW)
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)


func test_items_restore_stable_equipment_and_inventory_focus() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(0) as HeroPanel
	hero_panel.armor_panel.tune_btn.grab_focus()
	party.return_to_hero_rail()
	assert_true(party.enter_content())
	assert_same(get_viewport().gui_get_focus_owner(), hero_panel.armor_panel.tune_btn)
```

- [ ] **Step 2: Run Items tests and confirm the red state**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_hub_progression|test_hub_responsive_layout" -gexit
```

Expected: focus restoration and depth assertions fail while existing inventory transaction tests remain green.

- [ ] **Step 3: Add stable focus keys to item controls**

In `ItemButton`:

```gdscript
func get_focus_key() -> String:
	if _item_ref is Equipment:
		return "equipment:%s" % (_item_ref as Equipment).id
	if _item_ref is EquipmentMod:
		return "mod:%s" % (_item_ref as EquipmentMod).id
	if _item_ref is InventoryItem:
		return "item:%s" % (_item_ref as InventoryItem).id
	return ""
```

Mark `$Button` with `navigation_focus_pulse = true`, capture `$Button/Header` chrome, and add `set_chrome_active(active)`.

- [ ] **Step 4: Add InventoryPanel focus lookup and chrome forwarding**

Implement:

```gdscript
func focus_key(control: Control) -> String:
	for child in grid.get_children():
		if child is ItemButton and (child.get_focus_control() == control or child.is_ancestor_of(control)):
			return (child as ItemButton).get_focus_key()
	return ""


func default_focus() -> Control:
	for child in grid.get_children():
		if child is ItemButton:
			var control := (child as ItemButton).get_focus_control()
			if not control.disabled and control.visible:
				return control
	return null


func restore_focus(key: String) -> bool:
	for child in grid.get_children():
		if child is ItemButton and (child as ItemButton).get_focus_key() == key:
			var control := (child as ItemButton).get_focus_control()
			if not control.disabled and control.is_visible_in_tree():
				control.grab_focus()
				return true
	var fallback := default_focus()
	if fallback:
		fallback.grab_focus()
		return true
	return false


func set_chrome_active(active: bool) -> void:
	for child in grid.get_children():
		if child is ItemButton:
			(child as ItemButton).set_chrome_active(active)
```

- [ ] **Step 5: Add equipment focus keys and pulse metadata**

In `EquipmentPanel._ready()`, mark `equip_button` and `tune_btn` with `navigation_focus_pulse = true` and capture their focus surfaces. In `ModSlot._ready()`, mark its focus button likewise and capture the slot panel.

When `EquipmentPanel.apply_display_profile()` changes header border widths, derive from `HubChrome.get_base_style(header)` and finish with `HubChrome.set_base_style(header, header_style)` rather than capturing the currently displayed active/dim clone. This preserves both compact sizing and authored bright colors across profile changes at either navigation depth.

In `HeroPanel`, implement stable relative-path keys for fixed equipment controls:

```gdscript
func items_default_focus() -> Control:
	for control: Control in [weapon_panel.equip_button, armor_panel.equip_button, weapon_panel.tune_btn, armor_panel.tune_btn]:
		if control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
			return control
	return null


func items_focus_key(control: Control) -> String:
	return "hero:%s" % get_path_to(control) if is_instance_valid(control) and is_ancestor_of(control) else ""


func restore_items_focus(key: String) -> bool:
	var relative_path := key.trim_prefix("hero:")
	var control := get_node_or_null(NodePath(relative_path)) as Control if key.begins_with("hero:") else items_default_focus()
	if control == null or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
		control = items_default_focus()
	if control == null:
		return false
	control.grab_focus()
	return true
```

Extend `set_chrome_active()` to update the hero header, both EquipmentPanel headers/focus surfaces, and enabled ModSlot panels without changing child modulation.

- [ ] **Step 6: Complete PartyMenu Items memory and cancellation routing**

Store Items memory by hero ID:

```gdscript
func _items_memory_key() -> String:
	return "items:%s" % party_roster[current_hero_idx].hero_id


func _store_items_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var panel := _get_panel_by_index(current_hero_idx)
	var key := panel.items_focus_key(owner) if panel and panel.is_ancestor_of(owner) else inventory_view.focus_key(owner)
	if not key.is_empty():
		_content_focus_memory[_items_memory_key()] = key


func _restore_items_focus() -> bool:
	var key: String = _content_focus_memory.get(_items_memory_key(), "")
	var panel := _get_panel_by_index(current_hero_idx)
	if (key.is_empty() or key.begins_with("hero:")) and panel and panel.restore_items_focus(key):
		return true
	return inventory_view.restore_focus(key)


func _update_depth_presentation() -> void:
	for index in range(hero_list_container.get_child_count()):
		var panel := hero_list_container.get_child(index) as HeroPanel
		panel.set_chrome_active(current_depth == Depth.HERO_RAIL or index == current_hero_idx)
	var content_active := current_depth == Depth.CONTENT
	skill_view.set_chrome_active(content_active and current_tab == Tab.ROLES)
	inventory_view.set_chrome_active(content_active and current_tab == Tab.ITEMS)
```

When Back is pressed in Items content, call `inventory_view.cancel_navigation()` first. If it returns `true`, keep `Depth.CONTENT`, restore the originating equipment control, and consume the event. Only a later Back returns to the hero rail.

- [ ] **Step 7: Run focused tests and import**

Run Step 2 and isolated import.

Expected: selected tests pass, nested Items state unwinds once, and stable equipment focus restores.

- [ ] **Step 8: Commit Task 5**

```sh
git add src/hub/hero_panel.gd src/hub/inventory_panel.gd src/hub/item_button.gd src/hub/equipment_panel.gd src/hub/mod_slot.gd src/hub/party_menu.gd test/integration/test_hub_progression.gd
git commit -m "feat: restore controller focus across hub items"
```

---

### Task 6: Responsive Layout, Full-Loop Coverage, and Manual Acceptance

**Files:**
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/party_menu.tscn`
- Modify: `test/integration/test_hub_responsive_layout.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`
- Modify: `docs/testing/controller-manual-checklist.md`

**Interfaces:**
- Consumes: all Tasks 1–5 public interfaces.
- Produces: final responsive offsets/sizes, end-to-end controller coverage, and authoritative manual acceptance steps.

- [ ] **Step 1: Write failing responsive shell tests**

Update `test_hub_responsive_layout.gd` to assert the top strip and all tabs fit at compact output:

```gdscript
func test_compact_hub_top_tabs_and_stub_content_fit_deck_output() -> void:
	var menu := await _compact_party_menu()
	var tab_strip := menu.get_node("Header/TabStrip") as Control
	assert_true(ResponsiveFixture.fits_output(tab_strip, DECK_SIZE))
	for button: Button in menu.tab_buttons:
		assert_true(ResponsiveFixture.fits_output(button, DECK_SIZE))
		assert_gte(ResponsiveFixture.physical_rect(button, DECK_SIZE).size.y, 48.0)
	menu.change_tab(2)
	assert_true(ResponsiveFixture.fits_output(menu.get_node("Content/OptionsComingSoon"), DECK_SIZE))
	assert_same(menu.get_viewport().gui_get_focus_owner(), menu.hero_list_container.get_child(menu.current_hero_idx))
```

Remove assertions for the deleted bottom Header and old Back offsets; retain inventory/equipment sizing assertions.

- [ ] **Step 2: Update the playable-loop hub path before implementation**

Change the hub portion of `test_controller_playable_loop.gd` to enter through the hero rail and semantic actions:

```gdscript
var party := hub.party_menu
party.open()
await get_tree().process_frame
assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(0))
await _send_semantic(&"confirm")
assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
await _send_semantic(&"hub_role_next")
await _send_semantic(&"hub_role_previous")
```

Preserve the existing stable-node purchase assertions after this entry sequence.

- [ ] **Step 3: Run responsive and loop tests and confirm the red state**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_hub_responsive_layout|test_controller_playable_loop" -gexit
```

Expected: new layout/entry assertions fail until final offsets and controller path are complete.

- [ ] **Step 4: Finalize desktop and compact layout values**

In `PartyMenu.apply_display_profile()` set the top strip and content safe bounds without changing glyph-space width between input modes. Use these physical acceptance constraints rather than scaling down text:

```gdscript
var compact := profile == DisplayProfileService.Profile.COMPACT
$Header.offset_top = 20.0
$Header.offset_bottom = 92.0 if compact else 84.0
$Header.offset_left = 30.0
$Header.offset_right = -30.0
mode_tabs.add_theme_constant_override(&"separation", 12 if compact else 8)
```

Adjust `HeroList` and `Content` top/bottom offsets so they begin below the strip, remain inside the output, and preserve existing equipment expanded heights. Keep each compact tab and clickable Back surface at least `48` physical pixels high.

- [ ] **Step 5: Update the manual controller checklist**

Replace the obsolete hub bullets at lines 109–116 with:

```markdown
- [ ] Party menu opens on the selected expanded hero; Up/Down immediately selects, expands, and pulses exactly one hero.
- [ ] Right or Confirm enters content; Left or Back returns directly to the selected hero; Back again closes party management.
- [ ] L2/R2 wrap Roles, Items, Options, and Journal from hero and content depth; top controller-family glyphs match and fade without layout shift after keyboard input, mouse click, or touch.
- [ ] Options and Journal show `COMING SOON`, keep focus on the selected hero, and never leave focus null.
- [ ] In Roles, L1/R1 wrap unlocked roles; D-pad reaches every authored rank-page button and stable node focus restores per hero, role, and page.
- [ ] In Items, Back cancels Equip/Tune/Mod before returning to the hero rail; equipment and inventory focus restore to a valid stable context.
- [ ] Exact controller focus uses one neutral background pulse. Hero/content depth darkens only inactive white/neon edges; text, icons, stats, costs, gauges, and backgrounds remain fully readable.
- [ ] Mouse/touch directly select heroes, tabs, roles, pages, equipment, and items, and the next controller input resumes from synchronized focus state.
```

Retain modal, input-handoff, Steam Deck, and controller-family checks elsewhere in the document.

- [ ] **Step 6: Run the complete focused hub/navigation set**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_input_manager|test_dynamic_glyph|test_navigation_focus|test_hub_chrome|test_hub_progression|test_hub_responsive_layout|test_skill_tree_navigation|test_skill_tree_responsive_layout|test_standard_focus_navigation|test_navigation_ux_layer|test_controller_playable_loop" -gexit
```

Expected: every selected test passes; no parser errors, crashes, or unexpected failures.

- [ ] **Step 7: Run isolated import and the complete suite**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: both commands exit `0`; record exact test and assertion totals. The documented macOS CA warning and engine-shutdown diagnostics are acceptable only with successful exit and no unexpected failures.

- [ ] **Step 8: Run manual desktop-proxy acceptance**

At physical `1280x800`, then `1920x1080`, complete the updated Title and hub checklist using a controller. Record OS, controller and connection, resolution, commit, and concise notes. Verify pulse cadence, edge contrast, dense-text readability, every tab/role/page, Items cancellation, mouse/keyboard/touch handoff, and absence of layout shift. Leave Steam Deck hardware acceptance unchecked until performed on hardware.

- [ ] **Step 9: Commit Task 6**

```sh
git add src/hub/party_menu.gd src/hub/party_menu.tscn test/integration/test_hub_responsive_layout.gd test/integration/test_controller_playable_loop.gd docs/testing/controller-manual-checklist.md
git commit -m "test: verify controller-first hub navigation"
```

---

## Final Review Checklist

- Every top-level tab is visible, clickable, and reachable through controller-only L2/R2 actions.
- Hero selection remains vertical, immediate, expanded, and synchronized with focus.
- One and only one hub control pulses during focus presentation.
- Inactive depth changes only edge chrome; readable content opacity remains unchanged.
- Roles use L1/R1 and rank pages remain spatially reachable.
- Options and Journal have informational content and valid hero-rail focus.
- Items cancellation and focus restoration preserve all existing transactions.
- Controller glyphs use the active family, fade on keyboard/click/touch handoff, and retain layout space.
- All focused tests, import validation, and the complete suite pass under isolated `HOME`.
- The unrelated `src/map/dungeon_map.tscn` change remains unstaged and uncommitted.
