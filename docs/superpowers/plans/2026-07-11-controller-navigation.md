# Controller and Steam Deck Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the entire title → hub → dungeon → terminal → battle → result loop playable with controller or Steam Deck while preserving seamless mouse and keyboard use.

**Architecture:** A semantic input/glyph foundation owns device detection, action names, glyph lookup, and repeat/deadzone behavior. One global `NavigationUXLayer` above screen content owns cursor presentation, focus scaling, hints, modal focus, and focus restoration for standard controls; thin skill-tree, dungeon, battle, and inventory adapters provide only the gameplay semantics the shared layer cannot infer.

**Tech Stack:** Godot project metadata 4.6, Godot 4.7 test runtime, GDScript, Godot Input Map, Control focus, SVG assets, and vendored GUT 9.7.1.

## Global Constraints

- Use semantic Input Map actions; gameplay screens must not depend on physical joypad button indexes.
- Unknown controllers use Steam Deck glyphs and Xbox-compatible A/B/X/Y semantics.
- Nintendo uses A/right for confirm and B/bottom for cancel; Xbox/Steam use A/B; PlayStation uses Cross/Circle.
- The custom cursor remains visible, never warps the OS pointer, follows mouse motion, and snaps/tweens to controller or keyboard focus.
- L1/R1 change skill pages; L2/R2 change role trees and remain active at every skill-screen focus depth.
- Dungeon left stick/D-pad previews angularly selected neighbors; A confirms, B cancels, right stick pans, L2/R2 zoom, and right-stick press recenters.
- Battle actions map directly to four face buttons; the cursor is reserved for hero/target selection.
- No rebinding UI, Steam Input API integration, multiplayer controller assignment, purchase draft mode, or progression refund implementation in this milestone.
- Keep test saves isolated under the existing GUT save root.

---

### Task 1: Normalize and Validate Runtime Glyph and Cursor Assets

**Files:**
- Delete: `assets/graphics/glyphs/ps/`
- Retain: `assets/graphics/glyphs/{keyboard_mouse,nintendo_switch,nintendo_switch_2,playstation,steam_controller,steam_deck,xbox}/vector/*.svg`
- Create: `assets/graphics/glyphs/cursors/outline/` with the nine approved SVGs
- Modify: `.gitignore`
- Create: `test/unit/test_glyph_assets.gd`

**Interfaces:**
- Consumes: the curated Kenney imports already present in the worktree.
- Produces: lowercase paths used by `InputIconMap`, including `cursors/outline/{pointer_c,hand_point,hand_open,hand_closed,tool_hammer,cursor_disabled,busy_circle,cross_small,cursor_cogs}.svg`.

- [ ] **Step 1: Write the failing asset-contract test**

Create `test/unit/test_glyph_assets.gd`:

```gdscript
extends GutTest

const FAMILIES := ["keyboard_mouse", "nintendo_switch", "nintendo_switch_2", "playstation", "steam_controller", "steam_deck", "xbox"]
const CURSORS := ["pointer_c", "hand_point", "hand_open", "hand_closed", "tool_hammer", "cursor_disabled", "busy_circle", "cross_small", "cursor_cogs"]

func test_runtime_glyph_folders_are_lowercase_svg_only() -> void:
	for family in FAMILIES:
		var dir := DirAccess.open("res://assets/graphics/glyphs/%s/vector" % family)
		assert_not_null(dir, family)
		for file_name in dir.get_files():
			if file_name.ends_with(".import"):
				continue
			assert_eq(file_name, file_name.to_lower(), file_name)
			assert_true(file_name.ends_with(".svg"), file_name)

func test_approved_cursor_set_is_complete() -> void:
	for cursor_name in CURSORS:
		assert_true(ResourceLoader.exists("res://assets/graphics/glyphs/cursors/outline/%s.svg" % cursor_name), cursor_name)
```

- [ ] **Step 2: Run the test and verify the capitalized/unfiltered cursor layout fails**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_glyph_assets.gd -gexit
```

Expected: FAIL because `cursors/outline` does not exist.

- [ ] **Step 3: Curate the cursor directory and repository noise**

Move only the nine approved `Outline` SVGs into lowercase `cursors/outline`, delete the remaining Basic/Outline cursor imports, remove `.DS_Store` files from tracking, and add this line to `.gitignore`:

```gitignore
.DS_Store
```

Do not hand-edit `.import` sidecars; let Godot regenerate them after paths stabilize.

- [ ] **Step 4: Import and verify assets**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_glyph_assets.gd -gexit
```

Expected: import exits 0; the asset test passes with no missing resources.

- [ ] **Step 5: Commit**

```bash
git add .gitignore assets/graphics/glyphs test/unit/test_glyph_assets.gd
git commit -m "chore: curate controller glyph assets"
```

### Task 2: Replace the Crash-Prone Glyph Map with Semantic Resolution

**Files:**
- Modify: `src/singletons/input_map.gd`
- Modify: `src/battle/dynamic_glyph.gd`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/action_button.tscn`
- Modify: `src/battle/action_bar.tscn`
- Create: `test/unit/test_input_icon_map.gd`
- Create: `test/unit/test_dynamic_glyph.gd`

**Interfaces:**
- Produces: `InputIconMap.ControllerType`, `InputIconMap.get_controller_type_from_name(name: String) -> ControllerType`, `InputIconMap.get_glyph_path(type: ControllerType, action: StringName) -> String`, and `DynamicGlyph.set_action(action: StringName) -> void`.
- Consumes: semantic action names defined in Task 3; string names are accepted before Input Map entries exist.

- [ ] **Step 1: Write failing resolver tests**

Test exact detection and safety:

```gdscript
extends GutTest

func test_controller_detection_and_fallback() -> void:
	assert_eq(InputIconMap.get_controller_type_from_name("DualSense Wireless Controller"), InputIconMap.ControllerType.PLAYSTATION)
	assert_eq(InputIconMap.get_controller_type_from_name("Nintendo Switch Pro Controller"), InputIconMap.ControllerType.NINTENDO_SWITCH)
	assert_eq(InputIconMap.get_controller_type_from_name("Steam Deck"), InputIconMap.ControllerType.STEAM_DECK)
	assert_eq(InputIconMap.get_controller_type_from_name("mystery pad"), InputIconMap.ControllerType.STEAM_DECK)

func test_each_family_resolves_confirm_cancel_and_actions() -> void:
	for family in InputIconMap.runtime_controller_types():
		for action in [&"confirm", &"cancel", &"action_1", &"action_2", &"action_3", &"action_4"]:
			var path := InputIconMap.get_glyph_path(family, action)
			assert_ne(path, "", "%s %s" % [family, action])
			assert_true(ResourceLoader.exists(path), path)

func test_missing_action_returns_empty_path() -> void:
	assert_eq(InputIconMap.get_glyph_path(InputIconMap.ControllerType.XBOX, &"not_real"), "")
```

Add a `DynamicGlyph` test that calls `set_action(&"not_real")`, updates it, and asserts it hides without an error.

- [ ] **Step 2: Run both tests and verify failure**

Run GUT with `-gtest=res://test/unit/test_input_icon_map.gd,res://test/unit/test_dynamic_glyph.gd -gexit`.

Expected: FAIL because the old enum and deleted PS PNG preloads are still referenced.

- [ ] **Step 3: Implement path-based semantic glyph lookup**

Replace texture preloads with a family/action filename table and safe lookup:

```gdscript
enum ControllerType { KEYBOARD_MOUSE, XBOX, PLAYSTATION, NINTENDO_SWITCH, NINTENDO_SWITCH_2, STEAM_CONTROLLER, STEAM_DECK }

func get_glyph_path(type: ControllerType, action: StringName) -> String:
	var family: Dictionary = GLYPH_FILES.get(type, GLYPH_FILES[ControllerType.STEAM_DECK])
	var file_name: String = family.get(action, "")
	if file_name.is_empty():
		return ""
	return "res://assets/graphics/glyphs/%s/vector/%s" % [FAMILY_FOLDERS.get(type, "steam_deck"), file_name]

func get_glyph(type: ControllerType, action: StringName) -> Texture2D:
	var path := get_glyph_path(type, action)
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
```

Map Nintendo confirm/cancel to right/bottom and map unknown names to `STEAM_DECK`.

- [ ] **Step 4: Make DynamicGlyph action-driven and failure-safe**

Use `@export var action: StringName = &"action_1"`; expose `refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType)` and hide if `get_glyph()` returns null. Task 3 will connect the device-mode signals after it introduces them. Remove all references to the old integer `associated_action` API from action scenes.

- [ ] **Step 5: Run tests, import smoke test, and commit**

Expected: both focused tests pass and `Godot --headless --editor --quit` exits 0 without the line-20 preload crash.

```bash
git add src/singletons/input_map.gd src/battle/dynamic_glyph.gd src/battle/action_button.gd src/battle/action_button.tscn src/battle/action_bar.tscn test/unit/test_input_icon_map.gd test/unit/test_dynamic_glyph.gd
git commit -m "fix: resolve controller glyphs semantically"
```

### Task 3: Add Semantic Input Actions and Device-Mode Detection

**Files:**
- Modify: `project.godot`
- Modify: `src/singletons/input_manager.gd`
- Modify: `src/battle/dynamic_glyph.gd`
- Create: `test/unit/test_input_manager.gd`

**Interfaces:**
- Produces: `InputManager.InputMode { MOUSE, KEYBOARD, CONTROLLER }`, signals `input_mode_changed(mode)` and `controller_type_changed(type)`, `get_active_mode()`, `get_active_controller_type()`, and `is_meaningful_event(event) -> bool`.
- Produces Input Map actions: `nav_*`, `confirm`, `cancel`, `page_*`, `section_*`, `action_1..4`, `shift_action`, `camera_pan_*`, `zoom_in`, `zoom_out`, `recenter`, and reserved `refund_progression`.

- [ ] **Step 1: Write failing pure event-classification tests**

Cover key press → keyboard, mouse button/motion above 3 px → mouse, mouse motion at or below 3 px → ignored, joy button → controller, joy axis magnitude below 0.25 → ignored, and joy axis magnitude at or above 0.25 → controller. Test disconnect fallback by injecting connected device names rather than calling hardware APIs.

- [ ] **Step 2: Run the test and verify missing mode APIs fail**

Run the focused GUT test. Expected: FAIL because `InputMode` and classification helpers do not exist.

- [ ] **Step 3: Add exact Input Map bindings**

In `project.godot`, define keyboard plus joypad mappings using semantic actions. Use physical conventions per family in glyph presentation; Godot's standard face-button indexes remain semantic south/east/west/north. Use L1/R1 for `page_previous/page_next`, L2/R2 for `section_previous/section_next`, right-stick axes for camera pan, and right-stick press for `recenter`.

- [ ] **Step 4: Implement stable mode detection**

Refactor `_input(event)` to classify meaningful events, update the keyboard/mouse or controller mode immediately, update controller family only for controller events, and emit signals only on actual changes. On startup with no controller input, retain keyboard/mouse mode but keep `STEAM_DECK` as the controller-family fallback. Re-check remaining connected joypads on disconnect. Connect `DynamicGlyph` to both signals and call `refresh(active_mode == InputMode.CONTROLLER, active_controller_type)`.

- [ ] **Step 5: Run focused/full tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_input_manager.gd -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git add project.godot src/singletons/input_manager.gd src/battle/dynamic_glyph.gd test/unit/test_input_manager.gd
git commit -m "feat: add semantic controller input layer"
```

### Task 4: Add the Global Navigation UX Layer

**Files:**
- Create: `src/ui/navigation/navigation_cursor.gd`
- Create: `src/ui/navigation/navigation_cursor.tscn`
- Create: `src/ui/navigation/navigation_focus.gd`
- Create: `src/ui/navigation/action_hint.gd`
- Create: `src/ui/navigation/action_hint.tscn`
- Create: `src/ui/navigation/action_hint_bar.gd`
- Create: `src/ui/navigation/action_hint_bar.tscn`
- Create: `src/ui/navigation/navigation_ux_layer.gd`
- Create: `src/ui/navigation/navigation_ux_layer.tscn`
- Modify: `src/core/main.tscn`
- Create: `test/unit/test_navigation_cursor.gd`
- Create: `test/unit/test_action_hint_bar.gd`
- Create: `test/integration/test_navigation_ux_layer.gd`

**Interfaces:**
- Produces: `NavigationCursor.CursorState`, `set_focus_target(control: Control, state := DEFAULT)`, `set_world_target(canvas_item: CanvasItem, state := TARGET)`, `clear_target()`, and `set_cursor_state(state)`.
- Produces: `ActionHintBar.set_hints(hints: Array[Dictionary])`, where each dictionary is `{action: StringName, label: String, enabled: bool}`.
- Produces: `NavigationFocus.apply(control)` and `NavigationFocus.clear(control)`.
- Produces: `NavigationUXLayer.register_screen(root: Control, default_focus: Control = null)`, `unregister_screen(root: Control)`, `set_adapter(adapter: Object)`, `publish_hints(hints)`, `push_modal(root: Control, default_focus: Control)`, and `pop_modal(root: Control)`.

- [ ] **Step 1: Write failing cursor and hint tests**

Assert keyboard/mouse mode follows injected viewport coordinates; controller mode resolves a control's center or `cursor_anchor` metadata; cursor states resolve all nine approved textures; disabled/hidden targets clear safely; hint bars show controller glyphs in controller mode and hide entirely in keyboard/mouse mode without hiding actual clickable UI controls. The integration test registers two ordinary screens and a modal, then verifies automatic focus tracking, modal trapping, and restoration without screen-specific cursor or hint nodes.

- [ ] **Step 2: Run tests and verify missing classes fail**

Run both focused files. Expected: parse/load failure for the new classes.

- [ ] **Step 3: Implement the cursor as a top-level CanvasLayer**

Use `mouse_filter = Control.MOUSE_FILTER_IGNORE`, process after layout, and tween snapped targets for 0.08 seconds. Mouse targets update directly. World targets use `get_global_transform_with_canvas()`; never call `warp_mouse()`.

- [ ] **Step 4: Implement focus scaling and semantic hints**

Focus presentation uses only a subtle scale tween and preserves all authored theme overrides and owned/affordable/disabled colors. Each hint resolves its texture through `InputIconMap`; missing textures leave a text label rather than crashing.

- [ ] **Step 5: Attach global UI, test, and commit**

Add the cursor and hint bar beneath a high-layer CanvasLayer in `main.tscn`. Run focused tests, full GUT, and headless import.

```bash
git add src/ui/navigation src/core/main.tscn test/unit/test_navigation_cursor.gd test/unit/test_action_hint_bar.gd
git commit -m "feat: add controller cursor and action hints"
```

### Task 5: Register Ordinary Menus, Terminals, and Modals with the UX Layer

**Files:**
- Modify: `src/core/title_screen.gd`
- Modify: `src/core/title_screen.tscn`
- Modify: `src/map/terminal.gd`
- Modify: `src/map/terminal.tscn`
- Modify: `src/map/dungeon_end_screen.gd`
- Modify: `src/map/dungeon_end_screen.tscn`
- Modify: `src/hub/hub.gd`
- Modify: `src/hub/hub.tscn`
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/party_menu.tscn`
- Create: `test/integration/test_standard_focus_navigation.gd`

**Interfaces:**
- Consumes: the Task 4 `NavigationUXLayer`; ordinary screens register roots/default focus and do not instantiate cursor, glow, or hint presentation themselves.
- Produces: deterministic default focus and one-layer-at-a-time cancel behavior for standard screens.

- [ ] **Step 1: Write failing integration tests**

Instantiate title, terminal, and result scenes; assert opening focuses an enabled visible default, focus never lands on a disabled/hidden choice, a modal retains focus inside itself, and cancel dismisses only the top layer. Assert focus restoration returns to the prior valid control.

- [ ] **Step 2: Run and verify current scenes fail deterministic focus assertions**

- [ ] **Step 3: Configure focus and hints**

Set `focus_mode = Control.FOCUS_ALL`, explicit neighbor paths where scene order is ambiguous, `mouse_filter` correctly, and call `grab_focus()` deferred after visibility/layout changes. Publish `confirm` and `cancel` hints based on current availability.

- [ ] **Step 4: Run focused/full tests and commit**

```bash
git add src/core/title_screen.gd src/core/title_screen.tscn src/map/terminal.gd src/map/terminal.tscn src/map/dungeon_end_screen.gd src/map/dungeon_end_screen.tscn src/hub test/integration/test_standard_focus_navigation.gd
git commit -m "feat: add controller focus to standard screens"
```

Review the staged diff before committing so unrelated hub asset serialization is not included.

### Task 6: Implement Hub Hierarchy and Geometric Skill Navigation

**Files:**
- Create: `src/hub/skill_tree_navigation.gd`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/skill_tree_node.gd`
- Modify: `src/hub/hero_management_scene.gd`
- Modify: `src/hub/skill_tree_panel.tscn`
- Modify: `src/hub/role_panel.tscn`
- Modify: `src/hub/skill_tree_node.tscn`
- Modify: `src/hub/hero_management_scene.tscn`
- Modify: `src/hub/inventory_panel.gd`
- Modify: `src/hub/inventory_panel.tscn`
- Modify: `src/hub/equipment_panel.gd`
- Modify: `src/hub/equipment_panel.tscn`
- Modify: `src/hub/item_button.gd`
- Modify: `src/hub/item_button.tscn`
- Modify: `src/hub/mod_slot.gd`
- Modify: `src/hub/mod_slot.tscn`
- Create: `test/unit/test_skill_tree_navigation.gd`
- Modify: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Produces: `SkillTreeNavigation.find_directional_candidate(current_id: String, direction: Vector2, positions: Dictionary) -> String`.
- Produces: `SkillTreePanel.focus_node(node_id)`, `change_page(delta)`, `change_role(delta)`, `move_focus(direction)`, and focus memory keyed by hero ID + role ID + page.

- [ ] **Step 1: Write failing geometry tests**

Use fixed node positions to assert candidates must lie in the requested half-plane, smallest angular error wins, distance breaks ties, and no candidate returns the current/empty ID safely. Add integration assertions that L1/R1 change pages, L2/R2 always change roles, purchases remain single-click/confirm, returning restores a stable node ID, inventory grids traverse every enabled slot, and equipment pickup/drop exposes valid and invalid targets.

- [ ] **Step 2: Run focused tests and verify failure**

- [ ] **Step 3: Implement the pure geometric selector**

For each candidate, compute `offset.normalized().dot(direction.normalized())`; reject scores `<= 0`. Sort by descending dot product, then ascending distance, then node ID for deterministic ties.

- [ ] **Step 4: Connect panel hierarchy without bypassing progression authority**

Set focus on generated `SkillTreeNode` controls, call the existing `purchase_requested(hero, role_id, node_id)` signal on confirm, and let the existing service refresh every visible tree. L2/R2 handling lives at the skill-panel boundary so child focus cannot consume it. Cancel moves node → role/page layer → hero list → close.

- [ ] **Step 5: Add cursor states and hints**

Use `UPGRADE` for affordable purchasable nodes, `INTERACT` for inspection, and `DISABLED` for unavailable purchase; publish confirm/cancel/page/section actions. Do not implement refund behavior—only keep the reserved semantic action unused.

Inventory/equipment controls use `INTERACT`, `CAN_GRAB`, `DRAGGING`, and `DISABLED` cursor states without adding button focus borders. Confirm calls the existing item/slot click handlers so equipment authority remains unchanged, and cancel returns a held item before moving outward in the focus hierarchy.

- [ ] **Step 6: Run hub tests/full suite and commit**

```bash
git add src/hub test/unit/test_skill_tree_navigation.gd test/integration/test_hub_progression.gd
git commit -m "feat: add controller skill tree navigation"
```

### Task 7: Implement Dungeon Angular Selection and Camera Controls

**Files:**
- Create: `src/map/dungeon_navigation.gd`
- Modify: `src/map/dungeon_map.gd`
- Modify: `src/map/dungeon_map.tscn`
- Modify: `src/map/map_node.gd`
- Create: `test/unit/test_dungeon_navigation.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Produces: `DungeonNavigation.closest_by_angle(origin: Vector2, direction: Vector2, candidates: Array[MapNode]) -> MapNode`.
- Dungeon adapter stores `_controller_preview_node: MapNode`, with `select_direction(direction)`, `confirm_preview()`, `cancel_preview()`, and `recenter_camera()`.

- [ ] **Step 1: Write failing selector and integration tests**

Assert closest-angle selection, deterministic distance tie-break, ineligible-node exclusion, preview retention after neutral input, confirm delegation to `_on_node_clicked`, cancel clearing, scan candidate filtering, lock-state suppression, frame-rate-independent pan, clamped zoom, and recenter on current node.

- [ ] **Step 2: Run focused tests and verify missing adapter failure**

- [ ] **Step 3: Implement pure angular selection**

Score candidates by the dot product between normalized `(candidate.position - origin)` and normalized input, then by distance and coordinates. Return null for zero input or no eligible candidates.

- [ ] **Step 4: Wire preview into existing validated movement**

Build candidates from the same neighbor/visibility/reachability rules used by mouse clicks. Stick/D-pad changes only `_controller_preview_node` and reticle position; `confirm_preview()` calls `_on_node_clicked(_controller_preview_node)`. Do not move `player_cursor` until existing movement succeeds.

- [ ] **Step 5: Add camera actions and hints**

Process right-stick pan using `delta`, L2/R2 zoom through `_zoom_camera`, and recenter through the existing clamped camera helper. Ignore all navigation while `current_map_state == MapState.LOCKED`.

- [ ] **Step 6: Run dungeon/full tests and commit**

```bash
git add src/map/dungeon_navigation.gd src/map/dungeon_map.gd src/map/dungeon_map.tscn src/map/map_node.gd test/unit/test_dungeon_navigation.gd test/integration/test_dungeon_restore.gd
git commit -m "feat: add controller dungeon navigation"
```

### Task 8: Add Direct Battle Actions and Target Navigation

**Files:**
- Modify: `src/battle/action_bar.gd`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/battle/action_bar.tscn`
- Modify: `src/battle/action_button.tscn`
- Modify: `src/battle/battle_scene.tscn`
- Modify: `src/battle/hero_card.tscn`
- Modify: `src/battle/enemy_card.tscn`
- Create: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: Task 3 `action_1..4`, `shift_action`, `confirm`, `cancel`, and navigation actions.
- Produces: `ActionBar.activate_slot(index: int) -> bool` and battle target focus that delegates to existing card selection/action execution.

- [ ] **Step 1: Write failing battle-controller tests**

Assert each semantic face action activates exactly its matching visible enabled slot; disabled/unaffordable/missing slots do nothing; shift action follows current battle rules; target navigation cycles only valid targets; confirm uses the existing target selection; cancel exits targeting without executing; and controller action input never moves focus through action buttons.

- [ ] **Step 2: Run focused test and verify missing slot API failure**

- [ ] **Step 3: Implement direct action activation**

`activate_slot(index)` validates `0 <= index < 4`, visible `ActionButton`, and `not button.disabled`, then calls `_on_action_button_pressed(button)` and returns true. `_unhandled_input` maps `action_1..4` to indexes 0..3 only while the action bar accepts input.

- [ ] **Step 4: Implement target focus and cursor behavior**

Use the existing living/valid target arrays. Directional input chooses by screen geometry, calls existing hover/focus presentation, and sets the global cursor to the target card. Confirm invokes the same selection handler as mouse; cancel returns to action selection and leaves the cursor on the active hero/target region.

- [ ] **Step 5: Refresh glyph disabled state and hints**

Each action button displays its semantic glyph and dims it with the button. Publish direct action, shift, confirm, and cancel hints only when available.

- [ ] **Step 6: Run battle/full tests and commit**

```bash
git add src/battle test/integration/test_battle_controller_navigation.gd
git commit -m "feat: add controller battle actions and targeting"
```

### Task 9: Full-Loop Verification and Documentation

**Files:**
- Create: `test/integration/test_controller_playable_loop.gd`
- Create: `docs/testing/controller-manual-checklist.md`
- Modify: `docs/refactor.md`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: automated smoke coverage and a hardware checklist for Xbox, PlayStation, Nintendo, Steam Deck/Steam Input, and mouse/keyboard switching.

- [ ] **Step 1: Add a controller-only integration smoke test**

Drive semantic actions through title → hub panel → dungeon selection → terminal choice → battle action/target → result dismissal. Instantiate the real screen adapters; inject the existing test hero/catalog fixtures for hub state, a fixed three-node map fixture for dungeon state, and the existing minimal hero/enemy card fixtures for battle state. Assert that focus/cursor never becomes invalid at screen boundaries.

- [ ] **Step 2: Run the smoke test and fix only integration defects**

Run the focused test. Expected: PASS without writing outside the test save root.

- [ ] **Step 3: Write the manual checklist**

Include device hot-plug, unknown-controller Steam fallback, Nintendo confirm/cancel, mouse jitter, rapid mouse/controller switching, every hub depth, L1/R1 pages, always-active L2/R2 roles, dungeon preview/pan/zoom/recenter/scan, all four battle skills, shift, target cancel, modal focus trapping, and Steam Deck readability.

- [ ] **Step 4: Record deferred refactor notes**

Add only discoveries that are outside this milestone to `docs/refactor.md`; do not broaden implementation to rebinding UI, refund/reset, Steam Input API, or unrelated scene restructuring.

- [ ] **Step 5: Run final verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: import exits 0, full GUT suite passes, no parse/runtime errors appear, test saves remain isolated, and `git diff --check` is silent.

- [ ] **Step 6: Perform hardware verification and commit**

Check available physical devices and record pass/fail notes in the checklist. Unavailable hardware stays explicitly unchecked rather than being claimed as passing.

```bash
git add test/integration/test_controller_playable_loop.gd docs/testing/controller-manual-checklist.md docs/refactor.md
git commit -m "test: verify controller playable loop"
```
