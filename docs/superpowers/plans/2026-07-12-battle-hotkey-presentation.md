# Battle Hotkeys and World-Cursor Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace temporary battle hotkey text with five official Kenney textures and stop the global cursor from snapping to dungeon or combat world objects.

**Architecture:** `InputIconMap` and texture-only `DynamicGlyph` handle both keyboard and controller prompts. `DungeonMap` and `BattleScene` retain logical selection/reticle/highlight state but always clear the global cursor target, letting existing free/snapped behavior show the cursor only after meaningful mouse motion.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, Kenney Input Prompts 1.5 (CC0).

## Global Constraints

- Keyboard battle prompts use official `keyboard_1.svg`, `keyboard_2.svg`, `keyboard_3.svg`, `keyboard_4.svg`, and `keyboard_shift.svg` textures.
- Restore only those five Kenney source SVGs; do not restore the full pack or commit `.import` sidecars.
- `DynamicGlyph` is texture-only in both keyboard/mouse and controller modes; remove the temporary text-label implementation.
- All controller-family action and shift mappings remain unchanged.
- Dungeon reticles/previews and combat actor highlights remain authoritative world-selection feedback.
- Dungeon and combat never assign map nodes or actor cards to `NavigationCursor`.
- Meaningful mouse motion shows the free cursor; subsequent keyboard/controller navigation hides it because no world target exists.
- Cursor snapping on title, hub, terminal, result, and other real UI controls remains unchanged.
- Do not change bindings, movement, targeting, combat execution, map interactions, click behavior, or modal ownership.
- Keep the staged 1,000-XP hero resources staged and untouched; keep the generated GUT theme normalization unstaged.
- Every commit must use `git commit --only` with explicit task paths.

---

### Task 1: Restore Kenney Hotkey Textures

**Files:**
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_1.svg`
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_2.svg`
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_3.svg`
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_4.svg`
- Create: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_shift.svg`
- Modify: `src/singletons/input_map.gd`
- Modify: `src/battle/dynamic_glyph.gd`
- Modify: `test/unit/test_glyph_assets.gd`
- Modify: `test/unit/test_input_icon_map.gd`
- Modify: `test/unit/test_dynamic_glyph.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Preserves: `InputIconMap.get_glyph_path(type, action) -> String` and `get_glyph(type, action) -> Texture2D`.
- Preserves: `DynamicGlyph.refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType)`; `false` resolves keyboard textures, `true` resolves the supplied controller family.
- Removes: `InputIconMap.KEYBOARD_LABELS`, `get_keyboard_label()`, and `DynamicGlyph.keyboard_label`.

- [ ] **Step 1: Replace text-label expectations with failing texture expectations**

In `test/unit/test_input_icon_map.gd`, delete `test_battle_keyboard_labels_match_live_bindings`. Extend the family test so every non-keyboard controller resolves `confirm`, `cancel`, `action_1`–`action_4`, and `shift_action`. Add:

```gdscript
func test_keyboard_battle_actions_resolve_kenney_textures() -> void:
	var expected := {
		&"action_1": "keyboard_1.svg",
		&"action_2": "keyboard_2.svg",
		&"action_3": "keyboard_3.svg",
		&"action_4": "keyboard_4.svg",
		&"shift_action": "keyboard_shift.svg",
	}
	for action: StringName in expected:
		var path := InputIconMap.get_glyph_path(InputIconMap.ControllerType.KEYBOARD_MOUSE, action)
		assert_true(path.ends_with(expected[action]), str(action))
		assert_true(ResourceLoader.exists(path), path)
```

In `test/unit/test_glyph_assets.gd`, add:

```gdscript
const BATTLE_KEYBOARD_GLYPHS := [
	"keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg", "keyboard_shift.svg",
]


func test_battle_keyboard_glyph_sources_are_curated() -> void:
	for file_name: String in BATTLE_KEYBOARD_GLYPHS:
		assert_true(
			FileAccess.file_exists("res://assets/graphics/glyphs/keyboard_mouse/vector/%s" % file_name),
			file_name,
		)
```

- [ ] **Step 2: Rewrite DynamicGlyph tests for texture-only presentation**

Remove every `keyboard_label` assertion from `test/unit/test_dynamic_glyph.gd`. Add/retain these behaviors:

```gdscript
func test_keyboard_mouse_mode_shows_keyboard_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_true(glyph.visible)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "keyboard_2.svg")
	assert_null(glyph.get_node_or_null("KeyboardLabel"))


func test_controller_mode_shows_controller_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(true, InputIconMap.ControllerType.XBOX)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "xbox_button_b.svg")
	assert_null(glyph.get_node_or_null("KeyboardLabel"))


func test_shift_keyboard_mode_uses_kenney_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"shift_action")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "keyboard_shift.svg")
```

The unknown-action test asserts hidden plus all textures null in both keyboard and controller modes. The mode-signal test starts controller, asserts a controller texture, sends a keyboard event, asserts `keyboard_1.svg`, then sends controller input and asserts the controller texture returns.

- [ ] **Step 3: Update real battle presentation tests**

In `test/integration/test_battle_controller_navigation.gd`, change the four action-button keyboard assertions to exact `keyboard_1.svg`–`keyboard_4.svg` texture filenames and assert no `KeyboardLabel` child. Change both shift keyboard assertions to `keyboard_shift.svg`. Keep exact controller texture/trigger assertions and disabled opacity; disabled keyboard mode now asserts `texture_normal.resource_path.get_file() == "keyboard_1.svg"`.

- [ ] **Step 4: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dynamic_glyph -gexit
```

Expected: the five sources and keyboard mappings are missing, and `DynamicGlyph` still creates the temporary label.

- [ ] **Step 5: Retrieve and verify the official archive**

```bash
curl -L https://www.kenney.nl/media/pages/assets/input-prompts/8de120163f-1777890371/kenney_input-prompts_1.5.zip -o /tmp/kenney_input-prompts_1.5.zip
shasum -a 256 /tmp/kenney_input-prompts_1.5.zip
```

Expected SHA-256:

```text
ac2fcf599080b0f3ba2d174c9474db6df1a0e96ff0662580e2da79a122ab78a1
```

- [ ] **Step 6: Extract only five source SVGs**

```bash
rm -rf /tmp/kenney-battle-hotkeys
mkdir -p /tmp/kenney-battle-hotkeys
unzip -j /tmp/kenney_input-prompts_1.5.zip \
  'Keyboard & Mouse/Vector/keyboard_1.svg' \
  'Keyboard & Mouse/Vector/keyboard_2.svg' \
  'Keyboard & Mouse/Vector/keyboard_3.svg' \
  'Keyboard & Mouse/Vector/keyboard_4.svg' \
  'Keyboard & Mouse/Vector/keyboard_shift.svg' \
  -d /tmp/kenney-battle-hotkeys
cp /tmp/kenney-battle-hotkeys/*.svg assets/graphics/glyphs/keyboard_mouse/vector/
```

Confirm exactly five new source files with `git status --short assets/graphics/glyphs/keyboard_mouse/vector`.

- [ ] **Step 7: Restore keyboard texture mappings and remove temporary label data**

In `InputIconMap.GLYPH_FILES[ControllerType.KEYBOARD_MOUSE]`, keep confirm/cancel and add:

```gdscript
&"action_1": "keyboard_1.svg", &"action_2": "keyboard_2.svg",
&"action_3": "keyboard_3.svg", &"action_4": "keyboard_4.svg",
&"shift_action": "keyboard_shift.svg",
```

Delete `KEYBOARD_LABELS` and `get_keyboard_label()`.

- [ ] **Step 8: Return DynamicGlyph to texture-only mode selection**

Delete `keyboard_label`, `_ensure_keyboard_label()`, and all label branches. Implement:

```gdscript
func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	var resolved_family := family if show_controller_glyph else InputIconMap.ControllerType.KEYBOARD_MOUSE
	var glyph := InputIconMap.get_glyph(resolved_family, action)
	if glyph == null:
		_clear_texture()
		return
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph
	show()


func _clear_texture() -> void:
	texture_normal = null
	texture_pressed = null
	texture_disabled = null
	hide()
```

Keep all existing mode/family signal connections and `set_action()` refresh behavior.

- [ ] **Step 9: Run focused hotkey verification and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dynamic_glyph -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
git diff --check
```

Stage only the five SVGs and six named source/test files. Do not stage generated `.import` files. Commit with `git commit --only <the eleven explicit paths> -m "fix: use Kenney battle hotkey glyphs"` so staged hero resources remain excluded.

---

### Task 2: Remove Dungeon World-Cursor Targets

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Preserves: `_controller_preview_node`, current node, reticle animation, hints, terminal modal cursor ownership, and `navigation_focus_restored()`.
- Changes: the live map adapter always leaves `NavigationCursor._target == null`.

- [ ] **Step 1: Rewrite map cursor regressions before production changes**

Update the map adapter test to assert that selecting a preview preserves `_controller_preview_node` and reticle state but leaves `navigation.cursor._target` null and hidden in snapped mode. Update cancel/scan restore assertions to expect null cursor target while current node/preview remain correct.

Update the terminal test:

```gdscript
assert_null(navigation.cursor._target, "map preview uses its reticle, not the global cursor")
# terminal opens
assert_same(navigation.cursor._target, terminal.close_button)
# terminal closes
assert_same(navigation._adapter, dungeon_map)
assert_null(navigation.cursor._target)
assert_same(dungeon_map._controller_preview_node, preview)
```

Rename the specialized-appearance test to `test_map_adapter_restore_clears_world_cursor_target` and assert `cursor._target == null`, cursor state DEFAULT, and hidden after `navigation_focus_restored()`.

- [ ] **Step 2: Add free-mouse/snapped-navigation visibility coverage**

Using the real navigation layer and map fixture:

```gdscript
InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
dungeon_map.select_direction(Vector2.RIGHT)
navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
assert_false(navigation.cursor.visible)
var preview := dungeon_map._controller_preview_node

var motion := InputEventMouseMotion.new()
motion.position = Vector2(240, 180)
motion.relative = Vector2(10, 0)
InputManager._input(motion)
navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, motion.position, true)
assert_true(navigation.cursor.visible)
assert_eq(navigation.cursor.position, motion.position)

var navigation_key := InputEventKey.new()
navigation_key.physical_keycode = KEY_D
navigation_key.pressed = true
InputManager._input(navigation_key)
navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, motion.position, true)
assert_false(navigation.cursor.visible)
assert_same(dungeon_map._controller_preview_node, preview)
```

- [ ] **Step 3: Run focused map test and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: map preview/restore still assigns world cursor targets.

- [ ] **Step 4: Clear instead of assigning map world targets**

In `select_direction()`, retain preview selection and reticle animation, then call `navigation.cursor.clear_target()` instead of `set_world_target()`.

Replace `_restore_controller_cursor()` with `_clear_navigation_cursor()`:

```gdscript
func _clear_navigation_cursor() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.cursor.clear_target()
```

Update `confirm_preview()`, `cancel_preview()`, and `navigation_focus_restored()` to call `_clear_navigation_cursor()`. `navigation_focus_restored()` must not branch on preview/current node; it clears the cursor and republishes hints.

- [ ] **Step 5: Run focused map verification and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
git diff --check
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit --only src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd -m "fix: keep cursor off dungeon world targets"
```

---

### Task 3: Remove Combat World-Cursor Targets and Verify Everything

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`

**Interfaces:**
- Preserves: `_controller_target`, hover/highlight calls, geometry navigation, confirm/cancel, hints, modal cursor ownership, and adapter restoration.
- Changes: the live battle adapter always leaves `NavigationCursor._target == null`.

- [ ] **Step 1: Rewrite battle cursor expectations before production changes**

Rename `test_battle_target_change_keeps_default_cursor_appearance` to `test_battle_target_change_uses_highlight_without_world_cursor`. After `_set_controller_target(enemy)`, assert logical target and hover count remain correct, but `ux.cursor._target == null` and snapped cursor is hidden.

Update modal restore and phase restore tests so the modal button owns the cursor while open, then closing/restoring battle leaves cursor target null and DEFAULT. Preserve assertions that `_controller_target` returns to the correct actor/enemy and hints restore.

In the playable-loop test, add assertions after battle begins and after target navigation that the battle manager/scene logical selection changes while the global cursor target stays null.

- [ ] **Step 2: Add combat mouse-show/navigation-hide coverage**

Using `_navigation_fixture()`:

```gdscript
InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
scene._set_controller_target(fixture.enemy)
ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
assert_false(ux.cursor.visible)

var motion := InputEventMouseMotion.new()
motion.position = Vector2(300, 220)
motion.relative = Vector2(12, 0)
InputManager._input(motion)
ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, motion.position, true)
assert_true(ux.cursor.visible)

var key := InputEventKey.new()
key.physical_keycode = KEY_D
key.pressed = true
InputManager._input(key)
ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, motion.position, true)
assert_false(ux.cursor.visible)
assert_same(scene._controller_target, fixture.enemy)
```

- [ ] **Step 3: Run focused battle tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
```

Expected: battle target/restore still assigns actor cards to the global cursor.

- [ ] **Step 4: Clear combat world targets without changing logical selection**

Replace `BattleScene._update_cursor()` with:

```gdscript
func _update_cursor() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.cursor.clear_target()
```

Do not change `_controller_target`, `_set_controller_target()`, `_restore_controller_target()`, hover/highlight calls, confirm/cancel, or hints.

- [ ] **Step 5: Run focused and full verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
git status --short
```

Expected: focused and full suites pass with zero failures; UI cursor tests remain green; editor exits 0; no parser errors/crashes; hero resources remain staged and GUT theme remains unstaged.

- [ ] **Step 6: Commit only combat cursor files**

```bash
git add src/battle/battle_scene.gd test/integration/test_battle_controller_navigation.gd test/integration/test_controller_playable_loop.gd
git commit --only src/battle/battle_scene.gd test/integration/test_battle_controller_navigation.gd test/integration/test_controller_playable_loop.gd -m "fix: keep cursor off combat world targets"
```
