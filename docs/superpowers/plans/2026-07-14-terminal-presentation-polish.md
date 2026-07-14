# Terminal Presentation Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the redesigned dungeon terminal so it uses a compact content-sized panel, readable orange protocol titles, correctly proportioned and complete glyphs, explicit Exit Terminal guidance, and sequential keyboard/controller shortcut ordering.

**Architecture:** Keep the existing `Terminal`, `TerminalProtocolRow`, `InputManager`, and `InputIconMap` responsibilities intact. Reorder the terminal's structured protocol definitions and semantic bindings together, make row visuals scene-owned, and let `Terminal` calculate a centered panel height from its authored content minimum size with a viewport clamp. No new framework, save format, protocol effect, or navigation abstraction is introduced.

**Tech Stack:** Godot 4.6.3, GDScript, Godot `.tscn` resources, SVG glyph assets, GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3; Godot 4.7 remains deferred.
- Work in the primary checkout on `codex/terminal-ui-redesign`; do not create a Git worktree.
- Preserve the existing terminal choice IDs and gameplay effects.
- The minimum acceptance viewport is 1200×800, with manual checks at 1280×800 and 1920×1080.
- Security, Medical, Finance, and Scan execute immediately; only Extraction requires confirmation.
- The header X stays clickable, while Escape/Circle/B is visibly labeled `EXIT TERMINAL` in the footer.
- Preserve and commit any required `.import` sidecar update produced for `keyboard_5.svg`.

---

### Task 1: Sequential Protocol Semantics and Legible Keyboard 5 Glyph

**Files:**
- Modify: `src/map/terminal.gd`
- Modify: `src/singletons/input_map.gd`
- Modify: `src/singletons/input_manager.gd`
- Modify: `project.godot`
- Modify: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg`
- Possibly modify after Godot import: `assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg.import`
- Test: `test/unit/test_terminal.gd`
- Test: `test/unit/test_input_icon_map.gd`
- Test: `test/unit/test_input_manager.gd`
- Test: `test/unit/test_glyph_assets.gd`

**Interfaces:**
- Consumes: `Terminal._protocol_definitions(data: Dictionary) -> Array[Dictionary]`, `InputIconMap.GLYPH_FILES`, `InputManager` family-specific terminal bindings, and the semantic actions declared in `project.godot`.
- Produces: row order Security, Medical, Finance, Scan, Extraction; keyboard bindings 1–5 in row order; controller bindings A/Cross, X/Square, Y/Triangle, L1/LB, R1/RB in row order; a keyboard 5 SVG containing visible dark numeral pixels.

- [ ] **Step 1: Write failing ordering, mapping, and glyph-legibility tests**

Update `test/unit/test_terminal.gd` so setup asserts the stable row actions and choice IDs:

```gdscript
func test_setup_orders_protocols_by_keyboard_and_controller_shortcuts() -> void:
	var terminal := await _terminal()
	var expected_actions: Array[StringName] = [
		&"terminal_security",
		&"terminal_medical",
		&"terminal_finance",
		&"terminal_scan",
		&"terminal_extract",
	]
	var expected_ids: Array[StringName] = [&"opt_sec", &"opt_med", &"opt_fin", &"opt_scan", &"opt_extract"]
	for index in expected_actions.size():
		assert_eq(terminal.get_protocol_row(index).get_action(), expected_actions[index])
		assert_eq(terminal.get_protocol_row(index).get_choice_id(), expected_ids[index])
	terminal.free()
```

Update `test/unit/test_input_icon_map.gd` to expect keyboard glyphs and PlayStation glyphs in the same semantic order:

```gdscript
func test_terminal_actions_resolve_keyboard_and_every_controller_family() -> void:
	var actions: Array[StringName] = [&"terminal_security", &"terminal_medical", &"terminal_finance", &"terminal_scan", &"terminal_extract"]
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
```

Change `test_terminal_controller_glyphs_match_behavior_groups()` so PlayStation expects Security Cross, Medical Square, Finance Triangle, Scan L1, and Extraction R1. Update `test/unit/test_input_manager.gd` so `test_terminal_actions_use_numbers_shoulders_and_non_cancel_face_buttons()` expects:

```gdscript
var expected := {
	&"terminal_security": [KEY_1, JOY_BUTTON_A],
	&"terminal_medical": [KEY_2, JOY_BUTTON_X],
	&"terminal_finance": [KEY_3, JOY_BUTTON_Y],
	&"terminal_scan": [KEY_4, JOY_BUTTON_LEFT_SHOULDER],
	&"terminal_extract": [KEY_5, JOY_BUTTON_RIGHT_SHOULDER],
}
```

Add a rendering-boundary regression to `test/unit/test_glyph_assets.gd`:

```gdscript
func test_keyboard_five_glyph_contains_visible_dark_numeral_pixels() -> void:
	var texture := load("res://assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg") as Texture2D
	assert_not_null(texture)
	var image := texture.get_image()
	var dark_opaque_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and pixel.get_luminance() < 0.25:
				dark_opaque_pixels += 1
	assert_gt(dark_opaque_pixels, 0, "keyboard 5 must render a visible numeral")
```

- [ ] **Step 2: Run the focused tests and verify the new expectations fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_icon_map -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect glyph_assets -gexit
```

Expected: terminal order and semantic mapping assertions fail against the old Security/Scan/Medical/Finance order, and the keyboard 5 image test reports zero dark opaque pixels.

- [ ] **Step 3: Reorder protocol definitions and semantic glyph mappings**

In `src/map/terminal.gd`, order `_protocol_definitions()` as Security, Medical, Finance, Scan, Extraction without changing any choice IDs, upgrade rules, titles, or outcomes:

```gdscript
return [
	{id = &"opt_sec_up" if upgrade_key == "security" else &"opt_sec", action = &"terminal_security", title = "REBOOT SECURITY" if upgrade_key == "security" else "SCRAMBLE CAMERAS", outcome = "ALERT -%d%%" % int(data.alert), upgraded = upgrade_key == "security"},
	{id = &"opt_med_up" if upgrade_key == "medical" else &"opt_med", action = &"terminal_medical", title = "DISPENSE ADRENALINE" if upgrade_key == "medical" else "DISPENSE PAINKILLERS", outcome = "HEAL + BOOST" if upgrade_key == "medical" else "HEAL INJURY", upgraded = upgrade_key == "medical"},
	{id = &"opt_fin_up" if upgrade_key == "finance" else &"opt_fin", action = &"terminal_finance", title = "INTERCEPT PAYMENT" if upgrade_key == "finance" else "BIT MINE", outcome = "+%.1f BITS" % (float(data.bits) / 10.0), upgraded = upgrade_key == "finance"},
	{id = &"opt_scan_up" if upgrade_key == "scan" else &"opt_scan", action = &"terminal_scan", title = "HIJACK CAMERA NETWORK" if upgrade_key == "scan" else "HIJACK LOCAL FEED", outcome = "WIDE SCAN" if upgrade_key == "scan" else "SECTOR SCAN", upgraded = upgrade_key == "scan"},
	{id = EXTRACTION_ID, action = EXTRACTION_ACTION, title = "SIGNAL EXTRACTION", outcome = "TACTICAL RETREAT", upgraded = false},
]
```

Keep `PROTOCOL_ACTIONS` in the same order. Update the keyboard entries in `src/singletons/input_map.gd` to Medical 2, Finance 3, and Scan 4. Preserve each controller's semantic face/shoulder glyph, so only dictionary presentation order changes for controller families.

Update `project.godot` key events and `src/singletons/input_manager.gd` default controller bindings so the semantic actions use:

```text
terminal_security = keyboard 1 + confirm-position face button
terminal_medical  = keyboard 2 + left face button
terminal_finance  = keyboard 3 + top face button
terminal_scan     = keyboard 4 + left shoulder
terminal_extract  = keyboard 5 + right shoulder
```

Retain the existing Nintendo runtime rebinding that makes Security use Nintendo A and Cancel use Nintendo B.

- [ ] **Step 4: Repair `keyboard_5.svg` and reimport it**

Replace the compound all-white numeral path with separate white keycap and black numeral paths:

```svg
<svg width="64" height="64" xmlns="http://www.w3.org/2000/svg">
  <g>
    <path stroke="none" fill="#FFFFFF" d="M16 8 L48 8 Q56 8 56 16 L56 48 Q56 56 48 56 L16 56 Q8 56 8 48 L8 16 Q8 8 16 8 Z"/>
    <path stroke="none" fill="#000000" d="M27 23 L39 23 L39 27 L31 27 L31 31 L35 31 Q40 31 40 36 Q40 41 35 41 L27 41 L27 37 L34 37 Q36 37 36 35 Q36 33 34 33 L27 33 Z"/>
  </g>
</svg>
```

Run the isolated import:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: import exits 0 and any changed `.import` sidecar remains included with this task.

- [ ] **Step 5: Run focused tests and verify Task 1 passes**

Run the four focused commands from Step 2.

Expected: all selected terminal, input-icon-map, input-manager, and glyph-asset tests pass with no parser errors or crashes.

- [ ] **Step 6: Commit Task 1**

```bash
git add project.godot src/map/terminal.gd src/singletons/input_map.gd src/singletons/input_manager.gd assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg.import test/unit/test_terminal.gd test/unit/test_input_icon_map.gd test/unit/test_input_manager.gd test/unit/test_glyph_assets.gd
git commit -m "fix: align terminal protocol shortcuts"
```

### Task 2: Aspect-Preserving Orange Protocol Rows

**Files:**
- Modify: `src/map/terminal_protocol_row.tscn`
- Test: `test/unit/test_terminal_protocol_row.gd`

**Interfaces:**
- Consumes: the existing `TerminalProtocolRow` named children `%DynamicGlyph`, `%Title`, `%Upgraded`, and `%Outcome`.
- Produces: a 48×48 aspect-preserving centered glyph slot, orange protocol-title text, yellow upgrade text, white outcome text, and font sizes increased by 2 points.

- [ ] **Step 1: Write failing row-presentation tests**

Add to `test/unit/test_terminal_protocol_row.gd`:

```gdscript
func test_row_presentation_preserves_glyph_shape_and_terminal_color_hierarchy() -> void:
	var row := _row()
	assert_eq(row.glyph.custom_minimum_size, Vector2(48, 48))
	assert_eq(row.glyph.stretch_mode, TextureButton.STRETCH_KEEP_ASPECT_CENTERED)
	var title_color := row.title_label.get_theme_color(&"font_color")
	var outcome_color := row.outcome_label.get_theme_color(&"font_color")
	assert_gt(title_color.r, title_color.g)
	assert_gt(title_color.g, title_color.b)
	assert_almost_eq(outcome_color.r, 1.0, 0.01)
	assert_almost_eq(outcome_color.g, 1.0, 0.01)
	assert_almost_eq(outcome_color.b, 1.0, 0.01)
	assert_eq(row.title_label.get_theme_font_size(&"font_size"), 36)
	assert_eq(row.outcome_label.get_theme_font_size(&"font_size"), 28)
```

- [ ] **Step 2: Run the row test and verify it fails**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
```

Expected: the stretch-mode, title-color, and font-size assertions fail against the current row scene.

- [ ] **Step 3: Update the authored row presentation**

In `src/map/terminal_protocol_row.tscn`:

```text
DynamicGlyph.stretch_mode = 5  # STRETCH_KEEP_ASPECT_CENTERED
Title.theme_override_colors/font_color = Color(1, 0.55, 0.25, 1)
Title.theme_override_font_sizes/font_size = 36
Upgraded.theme_override_font_sizes/font_size = 24
Outcome.theme_override_colors/font_color = Color(1, 1, 1, 1)
Outcome.theme_override_font_sizes/font_size = 28
Caret.theme_override_font_sizes/font_size = 36
```

Keep the 48×48 glyph minimum and existing focus caret/outline behavior. Do not tint the outcome or upgrade annotation orange.

- [ ] **Step 4: Run the focused row test and verify it passes**

Run the command from Step 2.

Expected: all `test_terminal_protocol_row.gd` tests pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add src/map/terminal_protocol_row.tscn test/unit/test_terminal_protocol_row.gd
git commit -m "style: clarify terminal protocol rows"
```

### Task 3: Content-Sized Panel and Exit Terminal Footer Guidance

**Files:**
- Modify: `src/map/terminal.gd`
- Modify: `src/map/terminal.tscn`
- Test: `test/unit/test_terminal.gd`
- Test: `test/integration/test_standard_focus_navigation.gd`
- Update: `docs/testing/controller-manual-checklist.md`

**Interfaces:**
- Consumes: terminal setup lifecycle, the existing `%Protocols` rows, global `InputManager` mode/family signals through `DynamicGlyph`, the semantic `cancel` action, and the clickable `%CloseButton`.
- Produces: `_fit_panel_to_content() -> void`, a centered content-driven panel clamped to 90% of viewport height, and a footer Cancel glyph plus `EXIT TERMINAL` label that updates with active input mode.

- [ ] **Step 1: Write failing layout and exit-guidance tests**

Extend `test_terminal_panel_and_protocols_fit_minimum_and_desktop_viewports()` in `test/unit/test_terminal.gd`:

```gdscript
var panel: Control = terminal.get_node("Panel")
assert_true(panel.size.y < size.y * 0.85, "%s panel should fit content instead of filling the viewport" % size)
assert_almost_eq(panel.position.y + panel.size.y * 0.5, size.y * 0.5, 2.0)
assert_true(panel.get_global_rect().encloses(terminal.get_node("Panel/Footer").get_global_rect()))
```

Add a dedicated footer test:

```gdscript
func test_footer_labels_cancel_as_exit_terminal_and_keeps_header_close_available() -> void:
	var terminal := await _terminal()
	var exit_glyph := terminal.get_node("Panel/Footer/ExitHint/DynamicGlyph") as DynamicGlyph
	var exit_label := terminal.get_node("Panel/Footer/ExitHint/Label") as Label
	assert_eq(exit_glyph.action, &"cancel")
	assert_eq(exit_glyph.stretch_mode, TextureButton.STRETCH_KEEP_ASPECT_CENTERED)
	assert_eq(exit_label.text, "EXIT TERMINAL")
	assert_false(terminal.close_button.disabled)
	terminal.free()
```

Preserve the nested terminal Cancel coverage in `test/integration/test_standard_focus_navigation.gd`; add an assertion that the footer hint exists before sending Cancel so the visible guidance and actual modal behavior stay coupled.

- [ ] **Step 2: Run focused terminal and standard-focus tests and verify they fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
```

Expected: the panel remains 90% tall and the `ExitHint` nodes do not yet exist.

- [ ] **Step 3: Author the compact panel and footer hint**

In `src/map/terminal.tscn`:

- change `Panel` to use `anchor_top = 0.5`, `anchor_bottom = 0.5`, centered vertical growth, and authored fallback offsets around its content height;
- give `Panel` `unique_name_in_owner = true` so `%Panel` remains a stable script reference;
- remove the 720-pixel minimum height while retaining the 1080-pixel minimum width;
- reduce body vertical margins and protocol separation enough to keep five 64–72 pixel rows readable within the content height;
- remove `Protocols.size_flags_vertical = 3` so rows do not expand into unused body space;
- increase Status, Prompt, TraceWarning, and footer label font sizes by 2 points;
- replace `ContextText` with an `ExitHint` `HBoxContainer` containing a 32×32 non-focusable `DynamicGlyph` configured with `action = &"cancel"` and `stretch_mode = 5`, plus an orange monospace `Label` with `text = "EXIT TERMINAL"`.

Keep `CloseButton` wired to `cancel`; the footer hint is informational rather than a second mouse button.

- [ ] **Step 4: Fit the panel from its authored content minimum**

Add scene references and content fitting to `src/map/terminal.gd`:

```gdscript
const MAX_PANEL_HEIGHT_RATIO := 0.9

@onready var panel: Control = %Panel
@onready var panel_content: Control = %PanelContent

func _ready() -> void:
	# Existing connections and modal registration remain unchanged.
	get_viewport().size_changed.connect(_fit_panel_to_content)
	_fit_panel_to_content.call_deferred()

func _fit_panel_to_content() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(panel_content):
		return
	var viewport_height := float(get_viewport_rect().size.y)
	var desired_height := panel_content.get_combined_minimum_size().y
	var fitted_height := minf(desired_height, viewport_height * MAX_PANEL_HEIGHT_RATIO)
	panel.offset_top = -fitted_height * 0.5
	panel.offset_bottom = fitted_height * 0.5
```

Give the scene's internal header/body/footer wrapper the unique name `PanelContent`. Structure it so `get_combined_minimum_size().y` includes all three regions and their intended spacing. Call `_fit_panel_to_content.call_deferred()` after `setup()` configures labels and rows, ensuring upgraded text and facility metadata are included before measurement.

- [ ] **Step 5: Update the manual terminal checklist**

In `docs/testing/controller-manual-checklist.md`, replace the obsolete nearly-full-height terminal check and add terminal checks that explicitly verify:

```markdown
- At 1200×800 and 1280×800, the terminal is centered and only as tall as its header, five rows, and footer; there is no large blank region below Extraction.
- Protocol titles are orange, outcomes remain white, and every keyboard/controller glyph retains its natural proportions.
- The footer shows Escape/Circle/B as `EXIT TERMINAL`; using it closes the terminal, while the header X remains clickable.
- Row order and shortcuts are Security 1/A, Medical 2/X, Finance 3/Y, Scan 4/L1, and Extraction 5/R1.
```

- [ ] **Step 6: Run focused tests and verify Task 3 passes**

Run the two focused commands from Step 2.

Expected: terminal and standard-focus-navigation tests pass with the panel centered, shorter than 85% at both automated viewports, and Exit Terminal guidance present.

- [ ] **Step 7: Run complete verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: project import exits 0; all GUT tests pass; no parser errors, crashes, or unexpected failures appear. Documented certificate warnings and shutdown leak diagnostics remain acceptable when the process exits successfully.

- [ ] **Step 8: Commit Task 3**

```bash
git add src/map/terminal.gd src/map/terminal.tscn test/unit/test_terminal.gd test/integration/test_standard_focus_navigation.gd docs/testing/controller-manual-checklist.md
git commit -m "style: compact terminal presentation"
```

- [ ] **Step 9: Perform manual acceptance**

At 1200×800 or 1280×800 with keyboard/mouse and DualSense, verify the four checklist lines from Step 5 plus extraction confirmation, Cancel returning from confirmation to Ready, and ordinary Cancel closing the terminal. Record any purely visual adjustment separately rather than weakening automated semantic tests.
