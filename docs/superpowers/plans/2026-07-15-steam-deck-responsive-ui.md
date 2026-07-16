# Steam Deck Responsive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every playable Redshift screen natively usable at Steam Deck's `1280x800` display while preserving the established `1920x1080` desktop presentation.

**Architecture:** Keep the `1920x1080` authoring reference and Godot's `canvas_items` plus `expand` stretch policy. Add one autoloaded display-profile service for physical-window classification, startup sizing, logical viewport metrics, and the centered world safe rectangle; scenes retain ownership of their compact dimensions and scrolling behavior. Tests simulate Godot's expanded logical viewport and convert control bounds back to physical output pixels.

**Tech Stack:** Godot 4.6.3, typed GDScript, `.tscn` scenes, GUT 9.6.1, existing controller-navigation layer.

## Global Constraints

- Support and manually accept native handheld `1280x800` and desktop `1920x1080`.
- Keep `1920x1080` as the authoring reference with `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"`.
- Activate the compact profile when the physical width is `1366` pixels or less or the physical height is `800` pixels or less.
- Ignore resize samples with a zero dimension and emit profile changes only for meaningful metric changes.
- Use one scene set; do not add Steam Deck-specific copies or platform-name detection.
- Preserve approximately `20` physical pixels for primary text, `16` for secondary metadata, and `48x48` for important icons and actionable controls.
- Reflow, tighten nonessential space, or scroll before shrinking essential content below those thresholds.
- Preserve controller focus, visible focus decoration, and access to all content without hover.
- Keep world subjects inside a centered `1920x1080` safe composition while backgrounds, cameras, and responsive overlays cover the expanded viewport.
- Do not add a graphics settings menu, Steam API integration, exhaustive docked/ultrawide certification, gameplay-rule changes, or general rendering-performance work.
- Use the mandatory isolated `HOME=/tmp/mars-godot-home` for every automated Godot command.
- Preserve unrelated work and required Godot `.uid`/`.import` sidecars.

---

### Task 1: Display profile policy and responsive test fixture

**Files:**
- Create: `src/ui/display/display_profile_service.gd`
- Create: `test/fixtures/responsive_viewport_fixture.gd`
- Create: `test/unit/test_display_profile_service.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces: autoload `DisplayProfile` backed by `DisplayProfileService`.
- Produces: `DisplayProfileService.Profile { DESKTOP, COMPACT }`.
- Produces: `profile_for(Vector2i) -> int`, `startup_policy_for(Vector2i) -> Dictionary`, `expanded_logical_size_for(Vector2i) -> Vector2`, `safe_rect_for(Vector2) -> Rect2`, `update_metrics(Vector2i, Vector2) -> bool`, and `bind(Callable) -> void`.
- Produces: `ResponsiveViewportFixture.output_scale_for()`, `logical_size_for()`, `physical_rect()`, and `fits_output()` for later integration tests.

- [ ] **Step 1: Write the failing policy tests**

Create `test/unit/test_display_profile_service.gd` with direct public-boundary assertions:

```gdscript
extends GutTest

const DisplayProfileServiceScript = preload("res://src/ui/display/display_profile_service.gd")
const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")


func test_profile_boundaries_include_deck_and_small_desktop_windows() -> void:
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1280, 800)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1366, 900)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1920, 800)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1920, 1080)), DisplayProfileServiceScript.Profile.DESKTOP)


func test_startup_policy_uses_native_fullscreen_only_for_compact_displays() -> void:
	var deck := DisplayProfileServiceScript.startup_policy_for(Vector2i(1280, 800))
	assert_eq(deck.size, Vector2i(1280, 800))
	assert_eq(deck.mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	var desktop := DisplayProfileServiceScript.startup_policy_for(Vector2i(2560, 1440))
	assert_eq(desktop.size, Vector2i(1920, 1080))
	assert_eq(desktop.mode, DisplayServer.WINDOW_MODE_WINDOWED)


func test_expanded_deck_canvas_and_centered_world_safe_rect() -> void:
	var logical := DisplayProfileServiceScript.expanded_logical_size_for(Vector2i(1280, 800))
	assert_eq(logical, Vector2(1920, 1200))
	assert_eq(DisplayProfileServiceScript.safe_rect_for(logical), Rect2(0, 60, 1920, 1080))
	assert_eq(ResponsiveFixture.output_scale_for(Vector2i(1280, 800)), 2.0 / 3.0)


func test_zero_metrics_are_ignored_and_duplicate_metrics_do_not_emit() -> void:
	var service := DisplayProfileServiceScript.new()
	add_child_autofree(service)
	watch_signals(service)
	assert_false(service.update_metrics(Vector2i.ZERO, Vector2.ZERO))
	assert_true(service.update_metrics(Vector2i(1280, 800), Vector2(1920, 1200)))
	assert_false(service.update_metrics(Vector2i(1280, 800), Vector2(1920, 1200)))
	assert_signal_emit_count(service, "profile_changed", 1)
```

- [ ] **Step 2: Run the new test and confirm the missing preload failure**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect test_display_profile_service -gexit
```

Expected: non-zero exit because `display_profile_service.gd` and the fixture do not exist.

- [ ] **Step 3: Implement the pure policy and runtime signal boundary**

Create `src/ui/display/display_profile_service.gd`:

```gdscript
extends Node
class_name DisplayProfileService

signal profile_changed(profile: int, window_size: Vector2i, logical_size: Vector2)

enum Profile { DESKTOP, COMPACT }

const REFERENCE_SIZE := Vector2(1920, 1080)
const DESKTOP_WINDOW_SIZE := Vector2i(1920, 1080)
const COMPACT_MAX_WIDTH := 1366
const COMPACT_MAX_HEIGHT := 800

var current_profile: int = Profile.DESKTOP
var window_size := DESKTOP_WINDOW_SIZE
var logical_size := REFERENCE_SIZE


func _ready() -> void:
	get_tree().root.size_changed.connect(refresh_from_display)
	_configure_startup_window()
	refresh_from_display()


static func profile_for(size: Vector2i) -> int:
	return Profile.COMPACT if size.x <= COMPACT_MAX_WIDTH or size.y <= COMPACT_MAX_HEIGHT else Profile.DESKTOP


static func startup_policy_for(screen_size: Vector2i) -> Dictionary:
	if profile_for(screen_size) == Profile.COMPACT:
		return {size = screen_size, mode = DisplayServer.WINDOW_MODE_FULLSCREEN}
	return {size = DESKTOP_WINDOW_SIZE, mode = DisplayServer.WINDOW_MODE_WINDOWED}


static func output_scale_for(size: Vector2i) -> float:
	return minf(float(size.x) / REFERENCE_SIZE.x, float(size.y) / REFERENCE_SIZE.y)


static func expanded_logical_size_for(size: Vector2i) -> Vector2:
	var scale := output_scale_for(size)
	return REFERENCE_SIZE if scale <= 0.0 else Vector2(size) / scale


static func safe_rect_for(available_size: Vector2) -> Rect2:
	var scale := minf(1.0, minf(available_size.x / REFERENCE_SIZE.x, available_size.y / REFERENCE_SIZE.y))
	var safe_size := REFERENCE_SIZE * scale
	return Rect2((available_size - safe_size) * 0.5, safe_size)


func update_metrics(next_window_size: Vector2i, next_logical_size: Vector2) -> bool:
	if next_window_size.x <= 0 or next_window_size.y <= 0 or next_logical_size.x <= 0.0 or next_logical_size.y <= 0.0:
		return false
	var next_profile := profile_for(next_window_size)
	if next_profile == current_profile and next_window_size == window_size and next_logical_size.is_equal_approx(logical_size):
		return false
	current_profile = next_profile
	window_size = next_window_size
	logical_size = next_logical_size
	profile_changed.emit(current_profile, window_size, logical_size)
	return true


func refresh_from_display() -> void:
	update_metrics(DisplayServer.window_get_size(), get_tree().root.get_visible_rect().size)


func bind(callback: Callable) -> void:
	if not profile_changed.is_connected(callback):
		profile_changed.connect(callback)
	callback.call(current_profile, window_size, logical_size)


func _configure_startup_window() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		return
	var policy := startup_policy_for(DisplayServer.screen_get_size())
	DisplayServer.window_set_mode(policy.mode)
	if policy.mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(policy.size)
```

Create `test/fixtures/responsive_viewport_fixture.gd`:

```gdscript
class_name ResponsiveViewportFixture
extends RefCounted

const DisplayProfileServiceScript = preload("res://src/ui/display/display_profile_service.gd")


static func output_scale_for(window_size: Vector2i) -> float:
	return DisplayProfileServiceScript.output_scale_for(window_size)


static func logical_size_for(window_size: Vector2i) -> Vector2:
	return DisplayProfileServiceScript.expanded_logical_size_for(window_size)


static func physical_rect(control: Control, window_size: Vector2i) -> Rect2:
	var scale := output_scale_for(window_size)
	return Rect2(control.global_position * scale, control.size * scale)


static func fits_output(control: Control, window_size: Vector2i, tolerance := 1.0) -> bool:
	var rect := physical_rect(control, window_size)
	return rect.position.x >= -tolerance and rect.position.y >= -tolerance \
		and rect.end.x <= window_size.x + tolerance and rect.end.y <= window_size.y + tolerance
```

Add `DisplayProfile="*res://src/ui/display/display_profile_service.gd"` to `[autoload]` in `project.godot`. Do not remove the current window overrides until Task 2 protects startup and world placement together.

- [ ] **Step 4: Run the focused policy tests**

Run the command from Step 2.

Expected: all `test_display_profile_service.gd` tests pass with no parser errors.

- [ ] **Step 5: Commit the display policy**

```bash
git add project.godot src/ui/display/display_profile_service.gd test/fixtures/responsive_viewport_fixture.gd test/unit/test_display_profile_service.gd
git commit -m "feat: add responsive display profile"
```

---

### Task 2: Native startup sizing and centered world safe composition

**Files:**
- Modify: `src/core/main.gd`
- Modify: `src/core/main.tscn`
- Modify: `project.godot`
- Create: `test/unit/test_main_display_layout.gd`

**Interfaces:**
- Consumes: `DisplayProfile.bind(Callable)` and `DisplayProfileService.safe_rect_for(Vector2)` from Task 1.
- Produces: `Main.apply_display_layout(Vector2) -> void`, which positions and uniformly scales `WorldLayer` into the centered reference-safe rectangle.

- [ ] **Step 1: Write failing layout tests**

Create `test/unit/test_main_display_layout.gd`:

```gdscript
extends GutTest

class TestMain extends Main:
	func _ready() -> void:
		pass


func _main_fixture() -> Main:
	var main := TestMain.new()
	main.world_layer = Node2D.new()
	main.add_child(main.world_layer)
	autofree(main)
	return main


func test_deck_logical_viewport_centers_unscaled_world_in_safe_composition() -> void:
	var main := _main_fixture()
	main.apply_display_layout(Vector2(1920, 1200))
	assert_eq(main.world_layer.position, Vector2(0, 60))
	assert_eq(main.world_layer.scale, Vector2.ONE)


func test_small_direct_viewport_scales_world_uniformly_without_crop() -> void:
	var main := _main_fixture()
	main.apply_display_layout(Vector2(1280, 800))
	assert_eq(main.world_layer.position, Vector2(0, 40))
	assert_eq(main.world_layer.scale, Vector2(2.0 / 3.0, 2.0 / 3.0))
```

- [ ] **Step 2: Run the test and verify `apply_display_layout` is missing**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect test_main_display_layout -gexit
```

Expected: FAIL because `Main.apply_display_layout()` does not exist.

- [ ] **Step 3: Replace hard-coded resize math with the shared safe-rect policy**

In `src/core/main.gd`, replace `_on_viewport_resized()` and its direct root signal connection with:

```gdscript
func _ready() -> void:
	DisplayProfile.bind(_on_display_profile_changed)
	load_title_screen()


func _on_display_profile_changed(_profile: int, _window_size: Vector2i, viewport_size: Vector2) -> void:
	apply_display_layout(viewport_size)


func apply_display_layout(viewport_size: Vector2) -> void:
	if world_layer == null:
		return
	var safe_rect := DisplayProfileService.safe_rect_for(viewport_size)
	var scale_factor := safe_rect.size.x / DisplayProfileService.REFERENCE_SIZE.x
	world_layer.scale = Vector2.ONE * scale_factor
	world_layer.position = safe_rect.position
```

Set `WorldLayer.position = Vector2(0, 0)` in `src/core/main.tscn`; runtime placement now comes only from `apply_display_layout()`.

Remove these two lines from `project.godot`:

```ini
window/size/window_width_override=1920
window/size/window_height_override=1080
```

- [ ] **Step 4: Run Main, profile, routing, and import verification**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_main_display_layout|test_restore_failure_routing|test_controller_playable_loop" -gexit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: selected tests and import exit zero; the documented macOS CA diagnostic is acceptable.

- [ ] **Step 5: Commit native startup and world framing**

```bash
git add project.godot src/core/main.gd src/core/main.tscn test/unit/test_main_display_layout.gd
git commit -m "feat: adapt runtime framing to native displays"
```

---

### Task 3: Global shell, title, transitions, and modal bounds

**Files:**
- Modify: `src/core/title_screen.tscn`
- Modify: `src/core/loading_screen.tscn`
- Modify: `src/battle/game_manager.tscn`
- Modify: `src/core/tooltip_panel.gd`
- Modify: `src/core/tooltip_panel.tscn`
- Modify: `src/map/dungeon_end_screen.tscn`
- Create: `test/integration/test_responsive_global_ui.gd`

**Interfaces:**
- Consumes: `ResponsiveViewportFixture.logical_size_for()`, `physical_rect()`, and `fits_output()`.
- Produces: full-rect backgrounds/faders and centered global panels that fit both acceptance outputs.

- [ ] **Step 1: Add failing global-shell acceptance tests**

Create `test/integration/test_responsive_global_ui.gd`. Instantiate each scene under a `SubViewport` sized with `ResponsiveViewportFixture.logical_size_for(window_size)`, wait one process frame, and assert:

```gdscript
for window_size in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
	assert_true(ResponsiveViewportFixture.fits_output(title.get_node("MenuButtons"), window_size))
	assert_true(ResponsiveViewportFixture.fits_output(end_screen.get_node("Panel"), window_size))
	assert_true(ResponsiveViewportFixture.fits_output(tooltip, window_size))
	assert_eq(fader.get_global_rect(), Rect2(Vector2.ZERO, viewport.size))
	assert_gte(ResponsiveViewportFixture.physical_rect(end_screen.get_node("Panel/Button"), window_size).size.y, 48.0)
```

Use a local fixture function that returns `{viewport, instance}` and frees the `SubViewport` through `add_child_autofree()`.

- [ ] **Step 2: Run the test and capture the fixed-size failures**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect test_responsive_global_ui -gexit
```

Expected: FAIL on at least the fixed `GameManager/CanvasLayer/Fader` bounds before scene changes.

- [ ] **Step 3: Convert only global full-screen surfaces and constrained panels**

- In `src/battle/game_manager.tscn`, remove the Fader's `custom_minimum_size`, set full-rect anchors, zero offsets, and both grow directions.
- In `src/core/title_screen.tscn`, make the background `TextureRect` full rect with zero offsets, `expand_mode = TextureRect.EXPAND_IGNORE_SIZE`, and `stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED`; retain the centered title and menu controls.
- In `src/core/loading_screen.tscn`, make the root dimmer/background full rect and keep its progress content centered.
- In `src/core/tooltip_panel.tscn`, replace the fixed `600`-pixel minimum width with `min(600.0, get_viewport_rect().size.x - 96.0)` in its existing script and refit on viewport resize.
- In `src/map/dungeon_end_screen.tscn`, keep the `1100x801` desktop panel but give its Continue button a `72` authored-pixel minimum height so it remains `48` physical pixels at Deck scale.

- [ ] **Step 4: Run global UI, terminal, and import checks**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_responsive_global_ui|test_terminal" -gexit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: global UI and terminal tests pass; import exits zero.

- [ ] **Step 5: Commit global responsive surfaces**

```bash
git add src/core/title_screen.tscn src/core/loading_screen.tscn src/battle/game_manager.tscn src/core/tooltip_panel.tscn src/core/tooltip_panel.gd src/map/dungeon_end_screen.tscn test/integration/test_responsive_global_ui.gd
git commit -m "fix: keep global UI inside responsive bounds"
```

---

### Task 4: Hub shell, party controls, and scrollable inventory

**Files:**
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/party_menu.tscn`
- Modify: `src/hub/inventory_panel.gd`
- Modify: `src/hub/inventory_panel.tscn`
- Modify: `src/hub/item_button.gd`
- Modify: `src/hub/item_button.tscn`
- Modify: `src/hub/hero_panel.gd`
- Modify: `src/hub/hero_panel.tscn`
- Modify: `src/hub/equipment_panel.gd`
- Modify: `src/hub/equipment_panel.tscn`
- Modify: `src/hub/mod_slot.gd`
- Modify: `src/hub/mod_slot.tscn`
- Modify: `test/integration/test_hub_progression.gd`
- Create: `test/integration/test_hub_responsive_layout.gd`

**Interfaces:**
- Consumes: `DisplayProfile.bind()` and `DisplayProfileService.Profile`.
- Produces: `PartyMenu.apply_display_profile(int, Vector2i, Vector2)`, `InventoryPanel.apply_display_profile(...)`, and `ItemButton.apply_display_profile(...)`.
- Produces: `InventoryPanel/InventoryScroll/InventoryGrid`, a vertically scrollable replacement for the direct grid.

- [ ] **Step 1: Add failing hub bounds and inventory-scroll tests**

In `test/integration/test_hub_responsive_layout.gd`, instantiate `party_menu.tscn` in the expanded Deck logical viewport and assert:

```gdscript
assert_true(ResponsiveViewportFixture.fits_output(menu.get_node("HeroList"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(menu.get_node("Header"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(menu.get_node("BackBtn"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(menu.get_node("Content"), DECK_SIZE))
assert_gte(ResponsiveViewportFixture.physical_rect(menu.get_node("BackBtn"), DECK_SIZE).size.y, 48.0)
var scroll := menu.get_node("Content/InventoryPanel/InventoryScroll") as ScrollContainer
assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
assert_eq(menu.inventory_view.grid, scroll.get_node("InventoryGrid"))
```

Populate more item buttons than fit and assert `scroll.get_v_scroll_bar().max_value > scroll.size.y` and the first/last enabled buttons have reciprocal focus neighbors.

For the selected hero's weapon and armor panels, assert the compact `EquipBtn`, `TuneBtn`, and each enabled mod slot have physical width and height of at least `48` pixels while their labels, rank, gauge, stats, and mod-slot children remain inside the equipment panel.

- [ ] **Step 2: Run the hub test and verify missing scroll/profile behavior**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect test_hub_responsive_layout -gexit
```

Expected: FAIL because `InventoryScroll` and the compact 72-pixel Back button do not exist.

- [ ] **Step 3: Add compact party sizing and inventory scrolling**

In `party_menu.gd`, bind the profile in `_ready()` and apply these exact authored minimums:

```gdscript
func apply_display_profile(profile: int, _window_size: Vector2i, _logical_size: Vector2) -> void:
	var compact := profile == DisplayProfileService.Profile.COMPACT
	$Header.offset_top = 411.0
	$Header.offset_bottom = 483.0 if compact else 472.0
	$BackBtn.offset_top = 489.0 if compact else 477.0
	$BackBtn.offset_bottom = 561.0 if compact else 525.0
	mode_tabs.add_theme_constant_override(&"separation", 12 if compact else 8)
	inventory_view.apply_display_profile(profile, _window_size, _logical_size)
```

In `inventory_panel.tscn`, replace the direct `InventoryGrid` with a `ScrollContainer` named `InventoryScroll` using its current right-side anchors and offsets. Add `InventoryGrid` as a full-width `VBoxContainer` child and disable horizontal scrolling.

Update `inventory_panel.gd` to reference `$InventoryScroll/InventoryGrid`, retain focus-neighbor rebuilding, and call `ensure_control_visible()` on the scroll container whenever an item button gains focus. Pass the current display profile to every spawned `ItemButton`.

In `item_button.gd`, add:

```gdscript
func apply_display_profile(profile: int) -> void:
	custom_minimum_size.y = 72.0 if profile == DisplayProfileService.Profile.COMPACT else 42.0
```

Add the same scene-owned profile boundary to `HeroPanel`, `EquipmentPanel`, and `ModSlot`. In compact mode use a `72`-pixel equipment header/Equip button, a `72x72` XP row and Tune focus surface/button, and `72x72` mod slots; move the XP gauge's left edge to `76`. Desktop mode restores the authored `42`-pixel Equip button, `40`-pixel XP row, `44x44` Tune surface/button, and `64x64` mod slots. Increase the compact equipment panel's collapsed minimum height from `96` to `126` so the enlarged header does not cover its content. Reuse the existing expansion tween and recalculate its expanded height from the resized content; do not create a second size tween.

Do not change item, equipment, tuning, mod, or save behavior.

- [ ] **Step 4: Run hub progression and responsive tests**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_hub_responsive_layout|test_hub_progression" -gexit
```

Expected: all selected hub tests pass, including inventory mode switching and focus relationships.

- [ ] **Step 5: Commit responsive hub inventory**

```bash
git add src/hub/party_menu.gd src/hub/party_menu.tscn src/hub/inventory_panel.gd src/hub/inventory_panel.tscn src/hub/item_button.gd src/hub/item_button.tscn src/hub/hero_panel.gd src/hub/hero_panel.tscn src/hub/equipment_panel.gd src/hub/equipment_panel.tscn src/hub/mod_slot.gd src/hub/mod_slot.tscn test/integration/test_hub_progression.gd test/integration/test_hub_responsive_layout.gd
git commit -m "feat: adapt hub inventory for handheld play"
```

---

### Task 5: Scrollable and focus-aware skill trees

**Files:**
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/skill_tree_panel.tscn`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/skill_tree_node.gd`
- Modify: `src/hub/skill_tree_node.tscn`
- Modify: `test/integration/test_hub_progression.gd`
- Create: `test/integration/test_skill_tree_responsive_layout.gd`

**Interfaces:**
- Consumes: compact profile from `DisplayProfile`.
- Produces: `SkillTreePanel/RoleScroll/RoleList` horizontal scrolling and `SkillTreePanel.ensure_node_visible(Control)`.
- Produces: compact skill-tree node minimum `250x72` and vertical spacing `108` authored pixels.

- [ ] **Step 1: Add failing tree overflow and focus-visibility tests**

Create `test/integration/test_skill_tree_responsive_layout.gd` using the existing progression fixtures. At expanded Deck logical size, select each rendered role and tier, then assert:

```gdscript
var scroll := skill_panel.get_node("RoleScroll") as ScrollContainer
assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
for node: Control in selected_role.generated_nodes.values():
	var physical_size := ResponsiveViewportFixture.physical_rect(node, DECK_SIZE).size
	assert_gte(physical_size.x, 48.0)
	assert_gte(physical_size.y, 48.0)
	skill_panel.focus_node(selected_role.generated_nodes.find_key(node))
	await get_tree().process_frame
	assert_true(scroll.get_global_rect().intersects(node.get_global_rect()))
```

Also assert that changing roles/pages retains the existing remembered-node semantics.

- [ ] **Step 2: Run the test and verify `RoleScroll` is absent**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect test_skill_tree_responsive_layout -gexit
```

Expected: FAIL on missing `RoleScroll` and 50-pixel authored nodes scaling below 48 physical pixels.

- [ ] **Step 3: Wrap roles in a horizontal scroll region and reveal focused nodes**

In `skill_tree_panel.tscn`, replace the root `RoleList` placement with:

```text
SkillTreePanel
├── RoleScroll (ScrollContainer; full width; bottom offset -78; horizontal auto; vertical disabled)
│   └── RoleList (HBoxContainer; separation 20)
└── Tabs
```

Update `skill_tree_panel.gd` node paths. In `_on_role_node_focused()`, `_on_role_panel_selected()`, and `focus_node()`, defer:

```gdscript
func ensure_node_visible(node: Control) -> void:
	if is_instance_valid(node):
		$RoleScroll.ensure_control_visible(node)
```

When the compact profile is active, set generated `SkillTreeNode.custom_minimum_size = Vector2(250, 72)` and use `RolePanel.VERTICAL_SPACING_COMPACT = 108`; retain the existing `250x50` and spacing `90` on desktop. Re-render the current page after a profile transition so generated nodes receive the current dimensions.

Do not change node topology, costs, ownership rules, purchase rules, or navigation candidate selection.

- [ ] **Step 4: Run skill-tree, progression, and controller-navigation tests**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_skill_tree_responsive_layout|test_hub_progression|test_skill_tree_navigation|test_navigation_focus" -gexit
```

Expected: all selected tests pass and focus never lands on a clipped generated node.

- [ ] **Step 5: Commit responsive skill trees**

```bash
git add src/hub/skill_tree_panel.gd src/hub/skill_tree_panel.tscn src/hub/role_panel.gd src/hub/skill_tree_node.gd src/hub/skill_tree_node.tscn test/integration/test_hub_progression.gd test/integration/test_skill_tree_responsive_layout.gd
git commit -m "feat: keep skill trees usable on handheld"
```

---

### Task 6: Dungeon HUD, camera coverage, terminal regression, and end screen

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `src/map/dungeon_map.tscn`
- Modify: `src/map/dungeon_end_screen.gd`
- Modify: `src/map/dungeon_end_screen.tscn`
- Modify: `test/unit/test_dungeon_camera_controller.gd`
- Modify: `test/unit/test_terminal.gd`
- Create: `test/integration/test_dungeon_responsive_layout.gd`

**Interfaces:**
- Consumes: expanded logical viewport metrics and responsive fixture.
- Produces: corner-anchored Dungeon HUD groups and a centered end panel constrained to the available logical viewport.

- [ ] **Step 1: Add failing 16:10 dungeon acceptance tests**

Add camera-controller cases using `Vector2(1920, 1200)` and assert camera cover/clamping uses the complete expanded viewport. In `test_dungeon_responsive_layout.gd`, instantiate the map presentation without generating a run and assert the HUD, alert gauge, team status, bits, node gauge, warning, and end panel fit at both acceptance outputs.

Extend `test_terminal.gd`'s existing viewport loop to include `Vector2i(1280, 800)` explicitly.

- [ ] **Step 2: Run dungeon camera, terminal, and responsive tests**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_dungeon_camera_controller|test_dungeon_responsive_layout|test_terminal" -gexit
```

Expected: the new expanded-viewport or HUD-bound assertions fail before anchoring changes.

- [ ] **Step 3: Anchor HUD groups and constrain the result panel**

In `dungeon_map.tscn`, keep `CanvasLayer/HUD` full rect and anchor its groups by ownership: TeamStatus and BitsFound to top-left, AlertGauge to top-right, NodeGauge to bottom-left, and Warning to top-center. Preserve their current desktop pixel margins as anchor-relative offsets. Remove fixed positions derived from `1920x1080` center coordinates.

In `dungeon_map.gd`, pass `get_viewport_rect().size` to existing camera/background coverage code after every viewport resize; do not add a second coordinate conversion or change scanner semantics.

In `dungeon_end_screen.gd`, bind the display profile and constrain the panel:

```gdscript
func apply_display_profile(_profile: int, _window_size: Vector2i, logical_size: Vector2) -> void:
	var target := Vector2(minf(1100.0, logical_size.x - 96.0), minf(801.0, logical_size.y - 96.0))
	$Panel.offset_left = -target.x * 0.5
	$Panel.offset_right = target.x * 0.5
	$Panel.offset_top = -target.y * 0.5
	$Panel.offset_bottom = target.y * 0.5
```

- [ ] **Step 4: Run dungeon, restore, camera, terminal, and import checks**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_dungeon_responsive_layout|test_dungeon_camera_controller|test_dungeon_scan_controller|test_dungeon_restore|test_terminal" -gexit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: selected suites and import exit zero; scanner and camera coordinate behavior remains unchanged.

- [ ] **Step 5: Commit responsive dungeon presentation**

```bash
git add src/map/dungeon_map.gd src/map/dungeon_map.tscn src/map/dungeon_end_screen.gd src/map/dungeon_end_screen.tscn test/unit/test_dungeon_camera_controller.gd test/unit/test_terminal.gd test/integration/test_dungeon_responsive_layout.gd
git commit -m "feat: adapt dungeon presentation to 16 by 10"
```

---

### Task 7: Handheld combat layout and CTB rail acceptance

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/battle_scene.tscn`
- Modify: `src/battle/action_bar.gd`
- Modify: `src/battle/action_bar.tscn`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/battle/turn_queue.gd`
- Modify: `src/battle/turn_queue.tscn`
- Modify: `test/integration/test_turn_queue.gd`
- Create: `test/integration/test_battle_responsive_layout.gd`

**Interfaces:**
- Consumes: compact display profile and expanded logical viewport.
- Produces: compact presentation methods on `BattleScene`, `ActionBar`, and `TurnQueue`; CTB timing/order interfaces remain unchanged.

- [ ] **Step 1: Add failing Deck combat layout tests**

Instantiate the existing battle fixture at logical `1920x1200` representing `1280x800`. Assert physical output bounds and sizes:

```gdscript
assert_true(ResponsiveViewportFixture.fits_output(battle.get_node("UI/TurnQueue"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(battle.get_node("UI/ActionBar"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(battle.get_node("UI/Heroes"), DECK_SIZE))
assert_true(ResponsiveViewportFixture.fits_output(battle.get_node("UI/Enemies"), DECK_SIZE))
var queue_size := ResponsiveViewportFixture.physical_rect(queue.queue_items[0], DECK_SIZE).size
assert_gte(queue_size.x, 48.0)
assert_gte(queue_size.y, 48.0)
assert_gte(ResponsiveViewportFixture.physical_rect(action_button, DECK_SIZE).size.y, 48.0)
assert_lt(current_action.get_global_rect().end.x, turn_queue.get_global_rect().position.x)
```

Update the existing rail allocation test to run at both `1920x1080` and expanded Deck logical size. Retain the twenty-turn scroll, scrollbar containment, acting-card gold outline, gauge, and animation assertions.

- [ ] **Step 2: Run responsive battle and CTB tests**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_battle_responsive_layout|test_turn_queue" -gexit
```

Expected: FAIL on Deck-specific bounds or compact metadata readability before profile adjustments.

- [ ] **Step 3: Apply targeted compact dimensions without changing combat behavior**

Bind `BattleScene`, `ActionBar`, and `TurnQueue` to `DisplayProfile`. At compact profile:

- keep CTB queue cards at `72x72` authored pixels, which produces `48x48` physical pixels on Deck;
- keep action controls at least `86` authored pixels high;
- raise action-button header and CTB abbreviation metadata authored font sizes from `20` to `24`, producing `16` physical pixels;
- keep primary action and actor names at least `30` authored pixels, producing `20` physical pixels;
- use the extra logical height for the rail by retaining top `16` and bottom `300` margins against the full viewport;
- keep the action bar left of the rail and hero/enemy bands inside the centered safe composition;
- preserve tooltip clamping against the full logical viewport.

Store desktop and compact constants in their owning scripts. Do not touch `BattleManager` ordering, previews, CT recovery, action costs, target rules, or tween semantics.

- [ ] **Step 4: Run all combat, CTB, targeting, and import checks**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect "test_battle_responsive_layout|test_turn_queue|test_battle_controller_navigation|test_battle_condition_targets|test_action_ct_recovery|test_ctb_speed|test_ctb_simulator" -gexit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: selected suites and import exit zero, with no CTB order or prediction regressions.

- [ ] **Step 5: Commit handheld combat presentation**

```bash
git add src/battle/battle_scene.gd src/battle/battle_scene.tscn src/battle/action_bar.gd src/battle/action_bar.tscn src/battle/action_button.gd src/battle/actor_queue.gd src/battle/turn_queue.gd src/battle/turn_queue.tscn test/integration/test_turn_queue.gd test/integration/test_battle_responsive_layout.gd
git commit -m "feat: adapt combat UI for Steam Deck"
```

---

### Task 8: Project-wide documentation, full regression, and physical acceptance

**Files:**
- Modify: `docs/coordinate-spaces.md`
- Modify: `docs/testing/controller-manual-checklist.md`
- Modify: `docs/testing/dungeon-manual-checklist.md`
- Modify: `docs/testing/ctb-combat-checklist.md`
- Modify: `docs/testing/README.md`

**Interfaces:**
- Consumes: all responsive behavior from Tasks 1-7.
- Produces: authoritative automated and manual acceptance instructions for `1280x800` and `1920x1080`.

- [ ] **Step 1: Update authoritative documentation**

Document the reference canvas, physical-window profile, expanded logical canvas, centered world safe rectangle, and full-viewport UI distinction in `docs/coordinate-spaces.md`.

Add explicit `1280x800` controller-only steps to the manual checklists:

- title and hub landing;
- party selection, inventory/equipment, tuning/mods, and every available skill tree;
- dungeon HUD, scanner, map, terminal, overlays, and end screen;
- combat actions, targeting, tooltips, CTB rail scrolling, reorder/acting animation, and result transition;
- a shorter `1920x1080` regression path.

Add the exact isolated commands below to `docs/testing/README.md` as the responsive acceptance sequence.

- [ ] **Step 2: Run import and the complete automated suite**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: both commands exit zero; every test passes. Record exact test and assertion totals. The documented macOS CA and engine-shutdown diagnostics remain acceptable; parser errors, crashes, or unexpected failures do not.

- [ ] **Step 3: Complete desktop-proxy visual acceptance**

Run the project in a `1280x800` window and complete the full controller path in the design spec. Verify bounds, text/icon readability, focus, scroll reveal, cursor/reticle coordinates, background coverage, and animations. Repeat the shorter `1920x1080` path. Fix visual defects in the owning task's files, rerun that task's focused suites, then rerun the complete suite.

- [ ] **Step 4: Complete Steam Deck hardware acceptance when available**

On Steam Deck, verify the exported game launches borderless at native `1280x800`, then repeat the controller path. Record physical readability or control-size issues as focused follow-up changes; the desktop proxy does not replace this hardware check.

- [ ] **Step 5: Commit documentation and final acceptance updates**

```bash
git add docs/coordinate-spaces.md docs/testing/README.md docs/testing/controller-manual-checklist.md docs/testing/dungeon-manual-checklist.md docs/testing/ctb-combat-checklist.md
git commit -m "docs: add Steam Deck acceptance coverage"
```
