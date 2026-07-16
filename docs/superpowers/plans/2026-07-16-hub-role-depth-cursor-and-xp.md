# Hub Role Depth, Cursor, and XP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hub focus flashing with a controller-only RPG cursor, add explicit role-selection/tree depths, move tab/page controls to L1/R1 and L2/R2, repair role-name visibility, and present compact plus exact hero XP.

**Architecture:** `NavigationUXLayer` keeps logical Godot focus authoritative and delegates hub-only pointer presentation to `NavigationCursor`; non-hub focus and the scan pointer remain isolated. `PartyMenu` owns hero/content depth, while `SkillTreePanel` owns `ROLE_SELECT`/`TREE` sub-depth and rank-page trigger latching. Hero and role panels own only their visual data presentation, including XP formatting and mutually exclusive role labels.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` scenes, vendored GUT 9.6.1, existing `NavigationUXLayer`, `NavigationCursor`, `NavigationFocus`, `DynamicGlyph`, and `DisplayProfileService`.

## Global Constraints

- Use Godot 4.6.3; Godot 4.7 remains unsupported because of known iOS visual issues.
- Use `HOME=/tmp/mars-godot-home` for every automated Godot command.
- Preserve direct mouse/touch activation and the independent physical mouse position; never warp the hardware pointer.
- Scope the software controller cursor to party management. Battle, dungeon, scan, terminal, and other screens retain their existing presentation.
- Do not synthesize mouse motion to create controller hover.
- Do not add hub-specific keyboard shortcuts or keyboard glyph substitutions for L1/R1/L2/R2.
- Do not change progression rules, equipment transactions, inventory contents, save formats, or authored role trees.
- Preserve required `.uid` and `.import` sidecars created by Godot; never commit `.godot/`.
- Preserve the unrelated modification to `src/map/dungeon_map.tscn` and exclude it from every task commit.
- Support and verify `1920x1080` desktop and `1280x800` compact output.
- Implement every behavior with a failing test first, run the focused test to observe the expected failure, then write production code.

---

## File Structure

### Shared navigation

- `src/ui/navigation/navigation_cursor.gd` — owns hub target tracking, lower-right anchoring, viewport clamping, replacement tween, and scan/hub cursor ownership separation.
- `src/ui/navigation/navigation_ux_layer.gd` — recognizes focused controls inside the active party menu and selects hub cursor/hover presentation without changing modal focus rules.
- `src/ui/navigation/navigation_focus.gd` — retains ordinary non-hub focus and adds a non-animated authored hover-equivalent hub treatment.
- `test/unit/test_navigation_cursor.gd` and `test/integration/test_navigation_ux_layer.gd` — protect cursor geometry, timing, ownership, handoff, and non-hub isolation.

### Hub presentation

- `src/hub/hero_panel.gd` / `src/hub/hero_panel.tscn` — render the HP/compact-XP summary and remove focus-pulse/chrome dependencies.
- `src/hub/role_panel.gd` / `src/hub/role_panel.tscn` — make role cards selectable, swap abbreviation/full name visibility, and show exact `AVAILABLE XP` only when expanded.
- `src/hub/equipment_panel.gd` / `src/hub/equipment_panel.tscn` — preserve mode-only edge indication while removing navigation focus/chrome mutation.
- `src/hub/item_button.gd` / `src/hub/item_button.tscn`, `src/hub/mod_slot.gd`, `src/hub/skill_tree_node.gd`, and `src/hub/role_anchor_node.gd` — remove pulse/chrome opt-ins while retaining ordinary authored content.
- Delete `src/hub/hub_chrome.gd` and `test/unit/test_hub_chrome.gd` after all runtime consumers are removed.

### Roles controls and state

- `project.godot` and `src/singletons/input_map.gd` — bind top tabs to L1/R1 and new rank-page actions to L2/R2 for every controller family.
- `src/hub/skill_tree_panel.gd` / `src/hub/skill_tree_panel.tscn` — own Roles sub-depth, spatial role selection, page-trigger latching, page glyphs, and stable restoration.
- `src/hub/party_menu.gd` — delegates Roles entry/Back to `SkillTreePanel`, keeps Items behavior intact, and removes tab-trigger analog latching.

### Verification and documentation

- `test/integration/test_hub_progression.gd` — primary behavioral coverage for Roles, XP, name visibility, color preservation, and Back unwinding.
- `test/unit/test_input_manager.gd` and `test/unit/test_dynamic_glyph.gd` — semantic binding and glyph-family coverage.
- `test/integration/test_hub_responsive_layout.gd`, `test/integration/test_standard_focus_navigation.gd`, and `test/integration/test_controller_playable_loop.gd` — responsive and end-to-end regression coverage.
- `docs/testing/controller-manual-checklist.md` — replaces obsolete pulse/darkening and shoulder-control checks with the approved cursor/depth model.

---

### Task 1: Hub Cursor Tracking and Authored Hover Presentation

**Files:**
- Modify: `src/ui/navigation/navigation_cursor.gd`
- Modify: `src/ui/navigation/navigation_ux_layer.gd`
- Modify: `src/ui/navigation/navigation_focus.gd`
- Test: `test/unit/test_navigation_cursor.gd`
- Test: `test/unit/test_navigation_focus.gd`
- Test: `test/integration/test_navigation_ux_layer.gd`

**Interfaces:**
- Produces: `NavigationCursor.track_hub_target(target: Control, animate: bool = true) -> void`.
- Produces: `NavigationCursor.clear_hub_target() -> void` and `NavigationCursor.is_tracking_hub_target() -> bool`.
- Preserves: `NavigationCursor.show_at_screen_position(screen_position: Vector2) -> void` and `hide_pointer() -> void` for scan presentation.
- Produces: `NavigationFocus.apply_hub_hover(control: Control) -> void`; existing `apply()`/`clear()` remain the non-hub path.
- Consumes: `InputManager.get_active_mode()`, `InputManager.get_presentation_mode()`, and existing registered-screen/modal focus ownership.

- [ ] **Step 1: Write failing cursor geometry, replacement, and ownership tests**

Extend `test_navigation_cursor.gd` with real `Control` targets:

```gdscript
func test_hub_target_uses_lower_right_anchor_and_preserves_physical_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(100, 80)
	target.size = Vector2(240, 60)
	add_child_autofree(target)
	var physical_mouse := get_viewport().get_mouse_position()
	cursor.track_hub_target(target, false)
	assert_true(cursor.visible)
	assert_eq(cursor.position, Vector2(346, 146))
	assert_eq(get_viewport().get_mouse_position(), physical_mouse)


func test_hub_target_clamps_complete_cursor_inside_viewport() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(1130, 650)
	target.size = Vector2(145, 145)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	assert_lte(cursor.position.x + cursor.size.x, viewport_size.x - cursor.VIEWPORT_MARGIN)
	assert_lte(cursor.position.y + cursor.size.y, viewport_size.y - cursor.VIEWPORT_MARGIN)


func test_new_hub_target_replaces_in_flight_cursor_tween() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := Control.new()
	var second := Control.new()
	first.position = Vector2(40, 40)
	second.position = Vector2(400, 300)
	first.size = Vector2(100, 40)
	second.size = Vector2(100, 40)
	add_child_autofree(first)
	add_child_autofree(second)
	cursor.track_hub_target(first, false)
	cursor.track_hub_target(second, true)
	var replaced := cursor._move_tween
	cursor.track_hub_target(first, true)
	assert_false(replaced.is_valid())
	assert_same(cursor._hub_target.get_ref(), first)


func test_scan_position_clears_hub_tracking_without_changing_scan_api() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_false(cursor.is_tracking_hub_target())
	assert_eq(cursor.position, Vector2(320, 180))
```

- [ ] **Step 2: Run cursor tests and confirm RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
```

Expected: failures because `track_hub_target`, `VIEWPORT_MARGIN`, `_move_tween`, `_hub_target`, and `is_tracking_hub_target` do not exist.

- [ ] **Step 3: Implement target tracking without disturbing scan ownership**

Add the following ownership and tracking structure to `navigation_cursor.gd`:

```gdscript
const HUB_MOVE_DURATION := 0.07
const HUB_ANCHOR_OFFSET := Vector2(6, 6)
const VIEWPORT_MARGIN := 4.0

enum PointerOwner { NONE, HUB, EXTERNAL }

var _owner := PointerOwner.NONE
var _hub_target: WeakRef
var _move_tween: Tween


func track_hub_target(target: Control, animate: bool = true) -> void:
	if not _valid_hub_target(target):
		clear_hub_target()
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_owner = PointerOwner.HUB
	_hub_target = weakref(target)
	var start := position
	if not visible or not animate:
		position = _hub_position(target)
		show()
		return
	show()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_method(func(weight: float) -> void:
		var live_target := _hub_target.get_ref() as Control if _hub_target else null
		if _valid_hub_target(live_target):
			position = start.lerp(_hub_position(live_target), weight)
	, 0.0, 1.0, HUB_MOVE_DURATION)


func clear_hub_target() -> void:
	if _owner != PointerOwner.HUB:
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.NONE
	hide()


func is_tracking_hub_target() -> bool:
	return _owner == PointerOwner.HUB and _hub_target != null


func _process(_delta: float) -> void:
	if _owner != PointerOwner.HUB or _move_tween and _move_tween.is_running():
		return
	var target := _hub_target.get_ref() as Control if _hub_target else null
	if not _valid_hub_target(target):
		clear_hub_target()
		return
	position = _hub_position(target)


func _hub_position(target: Control) -> Vector2:
	var requested := target.get_global_rect().end + HUB_ANCHOR_OFFSET
	var viewport_size := Vector2(get_viewport_rect().size)
	return Vector2(
		clampf(requested.x, VIEWPORT_MARGIN, viewport_size.x - size.x - VIEWPORT_MARGIN),
		clampf(requested.y, VIEWPORT_MARGIN, viewport_size.y - size.y - VIEWPORT_MARGIN),
	)


func _valid_hub_target(target: Control) -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree()
```

Update `show_at_screen_position()` to kill any hub tween, clear `_hub_target`, set `_owner = PointerOwner.EXTERNAL`, and position immediately. Update `hide_pointer()` to clear every owner and tween.

- [ ] **Step 4: Write failing hub-hover restoration tests**

Replace the old pulse-specific test in `test_navigation_focus.gd` with:

```gdscript
func test_hub_hover_uses_authored_hover_style_without_animation_and_restores_focus() -> void:
	var button := Button.new()
	var authored_focus := StyleBoxFlat.new()
	var authored_hover := StyleBoxFlat.new()
	authored_focus.bg_color = Color.RED
	authored_hover.bg_color = Color.CYAN
	button.add_theme_stylebox_override(&"focus", authored_focus)
	button.add_theme_stylebox_override(&"hover", authored_hover)
	add_child_autofree(button)
	NavigationFocus.apply_hub_hover(button)
	assert_eq((button.get_theme_stylebox(&"focus") as StyleBoxFlat).bg_color, Color.CYAN)
	assert_false(NavigationFocus._states[button.get_instance_id()].has("tween"))
	NavigationFocus.clear(button)
	assert_same(button.get_theme_stylebox(&"focus"), authored_focus)
```

- [ ] **Step 5: Run focus tests and confirm RED**

Run the `navigation_focus` focused command and expect failure because `apply_hub_hover` is missing.

- [ ] **Step 6: Implement static authored hover treatment**

Add `apply_hub_hover(control: Control)` to `navigation_focus.gd`. For `Button`, duplicate the existing `hover` style into a temporary `focus` override while saving the authored focus override in `_states`. For `TextureButton`, save `texture_focused` and assign `texture_hover` only when a hover texture exists. Do not start a tween, recolor labels, or resolve `navigation_focus_surface` metadata. Extend `clear()` to restore the saved style or texture according to the state kind.

- [ ] **Step 7: Write failing hub-only UX ownership tests**

In `test_navigation_ux_layer.gd`, instantiate a `Control` named `PartyMenu` with a focusable child and assert:

```gdscript
func test_controller_focus_inside_party_menu_shows_hub_cursor_only() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var party := Control.new()
	party.name = "PartyMenu"
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(200, 48)
	party.add_child(button)
	add_child_autofree(party)
	ux.register_screen(party, button)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	button.grab_focus()
	await get_tree().process_frame
	assert_true(ux.cursor.is_tracking_hub_target())
	assert_same(ux.cursor._hub_target.get_ref(), button)


func test_pointer_handoff_hides_only_hub_cursor_and_preserves_focus_origin() -> void:
	var setup := await _party_button_screen()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	setup.button.grab_focus()
	await get_tree().process_frame
	InputManager._input(_mouse_button_at(Vector2(500, 300), MOUSE_BUTTON_LEFT, true))
	assert_false(setup.ux.cursor.is_tracking_hub_target())
	assert_same(setup.ux.get_focus_target(), setup.button)
```

Also invert the existing assertion that ordinary controller focus never shows a cursor only for the hub fixture; retain the no-cursor assertion for a generic non-hub screen.

- [ ] **Step 8: Implement hub target recognition in `NavigationUXLayer`**

Add `_party_menu_for(control: Control) -> Control` that walks ancestors until a node named `PartyMenu` is found and verifies it is visible. Centralize focus presentation:

```gdscript
func _apply_focus_presentation(control: Control) -> void:
	if not _is_focusable(control):
		cursor.clear_hub_target()
		return
	if _party_menu_for(control):
		NavigationFocus.apply_hub_hover(control)
		if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
			cursor.track_hub_target(control)
		else:
			cursor.clear_hub_target()
		return
	cursor.clear_hub_target()
	NavigationFocus.apply(control)
```

Call it from `_update_focus_target()` and `_on_presentation_mode_changed()`. Every presentation-clearing path must call `cursor.clear_hub_target()`; never call `hide_pointer()` from ordinary focus cleanup because that would steal the scan cursor's external ownership.

- [ ] **Step 9: Run the three focused suites and commit**

Run `navigation_cursor`, `navigation_focus`, and `navigation_ux_layer`; require all tests to pass without parser errors. Then commit only Task 1 files:

```bash
git add src/ui/navigation/navigation_cursor.gd src/ui/navigation/navigation_ux_layer.gd src/ui/navigation/navigation_focus.gd test/unit/test_navigation_cursor.gd test/unit/test_navigation_focus.gd test/integration/test_navigation_ux_layer.gd
git commit -m "feat: add hub controller cursor"
```

---

### Task 2: Remove Legacy Hub Pulse, Focus Outlines, and Depth Darkening

**Files:**
- Delete: `src/hub/hub_chrome.gd`
- Delete: `src/hub/hub_chrome.gd.uid`
- Delete: `test/unit/test_hub_chrome.gd`
- Delete: `test/unit/test_hub_chrome.gd.uid`
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/hero_panel.gd`
- Modify: `src/hub/hero_panel.tscn`
- Modify: `src/hub/equipment_panel.gd`
- Modify: `src/hub/equipment_panel.tscn`
- Modify: `src/hub/item_button.gd`
- Modify: `src/hub/item_button.tscn`
- Modify: `src/hub/mod_slot.gd`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/role_panel.tscn`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/skill_tree_node.gd`
- Modify: `src/hub/role_anchor_node.gd`
- Modify: `src/hub/inventory_panel.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Consumes: Task 1 hub cursor and static hover presentation.
- Removes: `navigation_focus_pulse` metadata, `HubChrome`, and all depth-driven `set_chrome_active()` call chains.
- Preserves: mode-specific `EquipmentPanel.set_visual_state()` and `ModSlot.pulse()` edge-only indicators.

- [ ] **Step 1: Write failing authored-color and no-pulse tests**

Replace `test_hub_focus_and_depth_styles_never_change_content_colors()` and the shared-focus-surface assertions in `test_hub_progression.gd` with checks that snapshot the actual authored styles and colors, enter/leave every depth, and assert:

```gdscript
assert_false(hero.has_meta("navigation_focus_pulse"))
assert_false(hero.has_node("FocusOutline"))
assert_same(hero.get_node("Content/Header").get_theme_stylebox(&"panel"), header_style)
assert_eq(hero.get_node("Content/Stats/HP").modulate, hp_modulate)
assert_eq(role.get_node("Header").modulate, role_header_modulate)
assert_eq(item.get_node("Button/Header").modulate, item_header_modulate)
```

Add a recursive assertion that no visible hub control has `navigation_focus_pulse` metadata after opening Roles and Items.

- [ ] **Step 2: Run `hub_progression` and confirm RED**

Expected: failures because pulse metadata, focus/depth outlines, and `HubChrome` consumers still exist.

- [ ] **Step 3: Remove exact-focus and depth-only artifacts**

Apply these mechanical removals:

- remove `FocusOutline` from hero and item scenes;
- remove `DepthOutline` from role scene;
- remove all `navigation_focus_surface` metadata that points to those nodes;
- remove all `navigation_focus_pulse` metadata from hero, role/tree, item, equipment, mod, and rank-page controls;
- remove `HubChrome.capture`, `HubChrome.set_active`, and component `set_chrome_active()` methods used only by depth presentation;
- reduce `PartyMenu._update_depth_presentation()` to hint publication and any non-visual state synchronization;
- remove `SkillTreePanel.set_chrome_active()` and `InventoryPanel.set_chrome_active()` call chains;
- replace `HubChrome.get_base_style(header)` in `EquipmentPanel.apply_display_profile()` with `header.get_theme_stylebox(&"panel").duplicate()`, update `border_width_top`, and apply the duplicate directly as the panel override.

Keep the equipment mode outline, but rename `FocusOutline` to `ModeOutline`, make its default alpha zero, and update `set_visual_state()` to animate only this node while a nested equipment mode is active. Keep `ModSlot/SelectionOutline` because it represents selected modification state, not navigation focus.

- [ ] **Step 4: Delete unused chrome implementation and test**

After `rg -n "HubChrome|set_chrome_active|navigation_focus_pulse" src/hub` returns no runtime consumers, delete `hub_chrome.gd`, its UID, and its unit test plus UID.

- [ ] **Step 5: Run focused hub, focus, and responsive tests**

Run `hub_progression`, `hub_responsive_layout`, and `navigation_focus`. Expect all to pass and no assertions to depend on pulsing, extra focus outlines, or inactive edge energy.

- [ ] **Step 6: Commit**

Stage only the listed runtime/test files and commit:

```bash
git commit -m "refactor: replace hub focus effects with cursor"
```

---

### Task 3: Role-Name Visibility and Dual XP Presentation

**Files:**
- Modify: `src/hub/hero_panel.gd`
- Modify: `src/hub/hero_panel.tscn`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/role_panel.tscn`
- Test: `test/integration/test_hub_progression.gd`
- Test: `test/integration/test_hub_responsive_layout.gd`

**Interfaces:**
- Produces: `HeroPanel.format_xp(value: int) -> String`.
- Produces: `HeroPanel.refresh_stats()` refreshing both combat stats and compact XP.
- Preserves: exact `RolePanel.refresh_progression_state(hero)` updates after purchase.

- [ ] **Step 1: Write failing XP boundary tests**

Add a table-driven test:

```gdscript
func test_hero_xp_uses_adaptive_shorthand() -> void:
	var expected := {
		0: "0",
		9999: "9,999",
		10000: "10.0K",
		99949: "99.9K",
		99950: "100K",
		200000: "200K",
		1000000: "1.0M",
		1260000: "1.3M",
	}
	for value: int in expected:
		assert_eq(HeroPanel.format_xp(value), expected[value], str(value))
```

Add a real-panel assertion that the HP label is left of the XP label, HP's left edge aligns with the summary row, XP's right edge aligns with the row, and both remain inside the hero card at desktop and compact profiles.

- [ ] **Step 2: Write failing role-label and exact-XP tests**

Instantiate a `RolePanel`, call `set_expanded(false, 0, false)` then `set_expanded(true, 0, false)`, and assert:

```gdscript
assert_true(panel.header_label.visible)
assert_false(panel.role_name_label.visible)
assert_false(panel.xp_display.visible)
panel.set_expanded(true, 0, false)
assert_false(panel.header_label.visible)
assert_true(panel.role_name_label.visible)
assert_true(panel.xp_display.visible)
assert_eq(panel.xp_display.text, "AVAILABLE XP 200,000")
```

Also assert the visibility swap happens synchronously before advancing a width tween.

- [ ] **Step 3: Run `hub_progression` and confirm RED**

Expected: XP formatter missing; both role labels remain visible; role XP still uses the old bare-value-plus-`XP` copy.

- [ ] **Step 4: Implement compact XP formatting**

Add to `HeroPanel`:

```gdscript
static func format_xp(value: int) -> String:
	var safe := maxi(value, 0)
	if safe < 10000:
		return Utils.commafy(safe)
	if safe < 99950:
		return "%.1fK" % (safe / 1000.0)
	if safe < 1000000:
		return "%dK" % roundi(safe / 1000.0)
	return "%.1fM" % (safe / 1000000.0)
```

Replace the current HP `HBoxContainer` with a neutral `Summary` HBox containing a left HP group, an expanding spacer, and a right XP group. Move the current HP controls under `Summary/HP`, add `Summary/XP/Label` and `Summary/XP/Value`, and bind an `xp` RichTextLabel in the script. `_refresh_stats()` sets `xp.text = format_xp(int(data.current_xp))`.

- [ ] **Step 5: Implement mutually exclusive role labels and exact XP**

In `RolePanel.set_expanded()`, set visibility before starting the width tween:

```gdscript
header_label.visible = not is_expanded
role_name_label.visible = is_expanded
xp_display.visible = is_expanded
```

Change `_refresh_xp_ui()` to:

```gdscript
xp_display.text = "AVAILABLE XP %s" % Utils.commafy(hero_data.current_xp)
```

Remove the obsolete upper role-switch glyph nodes from `role_panel.tscn`; rank-page glyphs are introduced in Task 4.

- [ ] **Step 6: Run focused progression and responsive tests**

Require `hub_progression` and `hub_responsive_layout` to pass. Confirm the responsive test checks six-digit exact role XP and the widest compact abbreviations without clipping.

- [ ] **Step 7: Commit**

```bash
git add src/hub/hero_panel.gd src/hub/hero_panel.tscn src/hub/role_panel.gd src/hub/role_panel.tscn test/integration/test_hub_progression.gd test/integration/test_hub_responsive_layout.gd
git commit -m "feat: clarify hub role names and xp"
```

---

### Task 4: L1/R1 Tabs, L2/R2 Rank Pages, and Page Glyphs

**Files:**
- Modify: `project.godot`
- Modify: `src/singletons/input_map.gd`
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/skill_tree_panel.tscn`
- Test: `test/unit/test_input_manager.gd`
- Test: `test/unit/test_dynamic_glyph.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Produces: `hub_tab_previous` / `hub_tab_next` as controller-only L1/R1 actions.
- Produces: `hub_page_previous` / `hub_page_next` as controller-only L2/R2 axis actions.
- Removes: `hub_role_previous` / `hub_role_next` actions and glyph mappings.
- Produces: `SkillTreePanel._handle_page_trigger_motion(event: InputEventJoypadMotion) -> void` with 0.75 press and 0.25 release thresholds.

- [ ] **Step 1: Write failing binding and glyph tests**

Update `test_input_manager.gd` expectations to:

```gdscript
var expected := {
	&"hub_tab_previous": [-1, JOY_BUTTON_LEFT_SHOULDER],
	&"hub_tab_next": [-1, JOY_BUTTON_RIGHT_SHOULDER],
	&"hub_page_previous": [JOY_AXIS_TRIGGER_LEFT, -1],
	&"hub_page_next": [JOY_AXIS_TRIGGER_RIGHT, -1],
	&"hub_upgrade": [-1, JOY_BUTTON_Y],
}
assert_false(InputMap.has_action(&"hub_role_previous"))
assert_false(InputMap.has_action(&"hub_role_next"))
```

Update glyph-family tests to require tab, page, and upgrade glyphs for every runtime controller family. Explicitly assert PlayStation tab glyphs use L1/R1 and page glyphs use L2/R2.

- [ ] **Step 2: Run input and glyph tests and confirm RED**

Run `input_manager` and `dynamic_glyph`; expect old action/binding failures.

- [ ] **Step 3: Replace semantic actions and glyph mappings**

In `project.godot`, bind tab actions to joy buttons 9/10, add page actions on axes 4/5 at value 1.0, and remove role actions. In every non-keyboard controller map in `input_map.gd`, map tabs to shoulder glyphs and pages to trigger glyphs:

```gdscript
&"hub_tab_previous": "xbox_lb.svg", &"hub_tab_next": "xbox_rb.svg",
&"hub_page_previous": "xbox_lt.svg", &"hub_page_next": "xbox_rt.svg",
```

Use the equivalent PlayStation L1/R1/L2/R2, Switch L/R/ZL/ZR, Steam Controller L1/R1/L2/R2, and Steam Deck L1/R1/L2/R2 assets.

- [ ] **Step 4: Write failing page-trigger latch tests**

Add progression tests showing a held R2 moves from page 0 to page 1 exactly once, release rearms it, and a release under a nested modal still rearms it. Task 5 adds the new role-selection-depth guard after that depth exists.

- [ ] **Step 5: Move trigger latching from `PartyMenu` to `SkillTreePanel`**

Remove `_held_tab_triggers`, `_handle_tab_trigger_motion()`, and `_reset_tab_triggers()` from `PartyMenu`; digital shoulders now use ordinary action presses. Add page-trigger state in `SkillTreePanel`:

```gdscript
var _held_page_triggers := {
	JOY_AXIS_TRIGGER_LEFT: false,
	JOY_AXIS_TRIGGER_RIGHT: false,
}
```

Process release events before navigation ownership guards. On a new press at or above 0.75 while the current tree node or page strip owns Roles focus, call `change_page(-1 or 1)` and mark the viewport event handled. Task 5 replaces this focus-derived ownership check with the explicit `TREE` depth check.

- [ ] **Step 6: Add controller-only page glyphs beside the page buttons**

In `skill_tree_panel.tscn`, add `PreviousPageGlyph` before `Tier1` and `NextPageGlyph` after `Tier5` inside `Tabs/Container`. Each is a 48×48 controller-only `DynamicGlyph` using `hub_page_previous` or `hub_page_next`. Replace child-index iteration with an explicit `page_buttons: Array[Button]` containing Tier1–Tier5 so glyph nodes never enter page-index logic.

Show the glyph nodes only when the active role supports more than one page; `DynamicGlyph` retains their layout space while fading for keyboard/mouse ownership.

- [ ] **Step 7: Run focused tests and commit**

Run `input_manager`, `dynamic_glyph`, `hub_progression`, and `hub_responsive_layout`. Commit:

```bash
git add project.godot src/singletons/input_map.gd src/hub/party_menu.gd src/hub/skill_tree_panel.gd src/hub/skill_tree_panel.tscn test/unit/test_input_manager.gd test/unit/test_dynamic_glyph.gd test/integration/test_hub_progression.gd test/integration/test_hub_responsive_layout.gd
git commit -m "feat: remap hub tabs and rank pages"
```

---

### Task 5: Explicit Role Selection and Tree Navigation Depths

**Files:**
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/role_panel.tscn`
- Modify: `src/hub/party_menu.gd`
- Test: `test/integration/test_hub_progression.gd`
- Test: `test/integration/test_standard_focus_navigation.gd`
- Test: `test/integration/test_controller_playable_loop.gd`

**Interfaces:**
- Produces: `SkillTreePanel.NavigationDepth { ROLE_SELECT, TREE }` and `navigation_depth`.
- Produces: `enter_role_select() -> bool`, `enter_tree() -> bool`, and meaningful `cancel_navigation() -> bool`.
- Changes: `restore_focus() -> bool` restores remembered role at `ROLE_SELECT`; node restoration occurs only in `enter_tree()`.
- Consumes: Task 4 `hub_page_previous` / `hub_page_next` only while `TREE` owns focus.

- [ ] **Step 1: Write failing Hero → Role → Tree → Back tests**

Add an integration scenario:

```gdscript
func test_roles_unwind_hero_role_tree_one_depth_at_a_time() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	party._unhandled_input(_action_event(&"confirm"))
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.TREE)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view.get_focused_node())
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
```

Add tests for Down entering the tree, Left/Right selecting roles without wrapping, role memory per hero, top-tab round trips returning to role selection, no-role/tree-empty safe fallback, and L2/R2 doing nothing while `ROLE_SELECT` owns focus.

- [ ] **Step 2: Run `hub_progression` and confirm RED**

Expected: `NavigationDepth`, role-card focus, and tree-entry boundaries do not exist; Roles currently restores a node directly.

- [ ] **Step 3: Make `RolePanel` a selectable focus target**

Set the RolePanel root `focus_mode = Control.FOCUS_ALL`. Keep its outer panel as the cursor target; do not attach pulse metadata. Add:

```gdscript
func focus_for_selection() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	grab_focus()
	return true
```

Collapsed-role mouse/touch selection still emits `panel_selected`; role selection updates current role without entering a generated node.

- [ ] **Step 4: Implement `SkillTreePanel` sub-depth**

Add:

```gdscript
enum NavigationDepth { ROLE_SELECT, TREE }
var navigation_depth := NavigationDepth.ROLE_SELECT


func enter_role_select() -> bool:
	navigation_depth = NavigationDepth.ROLE_SELECT
	var panel := _current_role_panel()
	if panel == null:
		return false
	_publish_role_select_hints()
	return panel.focus_for_selection()


func enter_tree() -> bool:
	var panel := _current_role_panel()
	if panel == null or panel.generated_nodes.is_empty():
		return false
	navigation_depth = NavigationDepth.TREE
	return focus_node(_remembered_node_for_current_context())


func cancel_navigation() -> bool:
	if navigation_depth != NavigationDepth.TREE:
		return false
	return enter_role_select()
```

Change `restore_focus()` to `return enter_role_select()`. Add clamped role selection:

```gdscript
func select_adjacent_role(delta: int) -> bool:
	var next := current_role_idx + delta
	if next < 0 or next >= role_list_container.get_child_count():
		return false
	_store_focus_memory()
	current_role_idx = next
	var selected := role_list_container.get_child(current_role_idx) as RolePanel
	current_page = _closest_supported_page(selected, current_page)
	_on_role_panel_selected(selected)
	return selected.focus_for_selection()
```

At `ROLE_SELECT`, Left/Right calls this method and Confirm/Down calls `enter_tree()`. At `TREE`, node geometry and page-trigger behavior remain active. Disable or ignore role-card focus when tree depth owns input.

- [ ] **Step 5: Publish depth-specific hints**

Role selection publishes Confirm `Open Role` and Back; tree depth publishes Upgrade/Inspect, Back, and enabled previous/next Page hints only when multiple pages exist. Remove all Role shoulder hints.

- [ ] **Step 6: Integrate `PartyMenu` entry and Back delegation**

Keep `PartyMenu._handle_back()`'s existing `skill_view.cancel_navigation()` delegation. Ensure `_restore_roles_focus()` calls `skill_view.enter_role_select()`. Prevent the generic `nav_left` content-to-hero shortcut from bypassing role selection: while Roles is in `TREE`, Left belongs to node geometry; while Roles is in `ROLE_SELECT`, Back—not Left—returns to the hero rail.

Switching heroes/tabs stores role, page, and stable node context but re-enters Roles at `ROLE_SELECT`.

- [ ] **Step 7: Update playable-loop semantics**

Replace the old `hub_role_next`/`hub_role_previous` assertions in `test_controller_playable_loop.gd` with semantic `nav_right` role selection, Confirm tree entry, node navigation/purchase, Back to role selection, and Back to hero rail. Assert role IDs rather than indices.

- [ ] **Step 8: Run focused integration suites and commit**

Run `hub_progression`, `standard_focus_navigation`, `navigation_ux_layer`, and `controller_playable_loop`. Commit:

```bash
git add src/hub/skill_tree_panel.gd src/hub/role_panel.gd src/hub/role_panel.tscn src/hub/party_menu.gd test/integration/test_hub_progression.gd test/integration/test_standard_focus_navigation.gd test/integration/test_controller_playable_loop.gd
git commit -m "feat: add explicit hub role navigation depth"
```

---

### Task 6: Manual Checklist, Cross-Cutting Verification, and Final Review

**Files:**
- Modify: `docs/testing/controller-manual-checklist.md`
- Verify: every file changed by Tasks 1–5

**Interfaces:**
- Consumes: all prior tasks.
- Produces: an accurate manual acceptance checklist and a reviewed, parser-clean, test-backed branch.

- [ ] **Step 1: Update obsolete hub checklist entries**

Replace the global claim that ordinary controller navigation never shows a cursor with a hub-specific exception. Replace the Title and Hub entries with explicit checks for:

- controller-only lower-right cursor and 70 ms movement;
- authored static button hover and no pulse/darkening;
- mouse-click handoff to the independent physical pointer;
- L1/R1 top tabs and L2/R2 rank pages;
- Hero → Role → Tree Back unwinding;
- mutually exclusive abbreviated/full role names; and
- compact hero XP plus exact `AVAILABLE XP` refresh after purchase.

Keep battle, dungeon, terminal, scan, and result-screen expectations unchanged.

- [ ] **Step 2: Import and parse with isolated HOME**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: exit 0; the documented macOS CA warning is acceptable, but parser errors and crashes are not.

- [ ] **Step 3: Run focused suites**

Run these selectors independently and record exact totals:

```bash
navigation_cursor
navigation_focus
input_manager
dynamic_glyph
navigation_ux_layer
hub_progression
hub_responsive_layout
standard_focus_navigation
controller_playable_loop
skill_tree_responsive_layout
```

Every focused command must exit 0 with no unexpected failures.

- [ ] **Step 4: Run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

If the protected dirty `src/map/dungeon_map.tscn` still causes only the known dungeon responsive-layout failure, record that exact isolated failure and do not edit, restore, stage, or commit the user's scene. Any other failure blocks completion.

- [ ] **Step 5: Review the scoped diff**

Run `git diff --check`, confirm `rg -n "hub_role_previous|hub_role_next|navigation_focus_pulse|HubChrome" project.godot src test` has no obsolete hub references, and verify every staged path belongs to this plan. Request independent code review and fix every Critical or Important finding before proceeding.

- [ ] **Step 6: Commit checklist and final corrections**

```bash
git add docs/testing/controller-manual-checklist.md
git commit -m "docs: update hub controller acceptance"
```

- [ ] **Step 7: Report remaining manual acceptance**

Report automated totals separately from pending physical checks. Do not claim the 70 ms cursor feel, lower-right visual clearance, glyph placement, or mouse/controller handoff is accepted until tested with a physical controller at `1280x800` and `1920x1080`.
