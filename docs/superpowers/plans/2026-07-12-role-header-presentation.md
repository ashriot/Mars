# Role Header Presentation Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the cramped role description and sticky clicked-node highlight, while making party-menu teardown and action-hint configuration lifecycle-safe.

**Architecture:** Progression nodes remain ordinary focusable buttons but stop using Godot toggle state; persistent presentation continues to come from progression ownership/availability and global scale-only focus. Modal teardown gains a non-restoring removal path, while `ActionHint` stores configuration until its child controls are ready so lifecycle ordering cannot produce null dereferences.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` scenes, GUT 9.7.1.

## Global Constraints

- Do not change progression ownership, pricing, purchase, or controller-navigation behavior.
- Owned nodes retain their existing owned highlight.
- Mouse focus continues to synchronize stable node IDs for seamless controller handoff.
- No global focus border or persistent selection state is introduced.
- Normal modal close restores hub focus; scene teardown removes the modal without restoring focus or publishing stale hints.
- Preserve the unrelated local `project.godot` modification and never stage it.

---

### Task 1: Make Role Header and Skill Click Presentation Non-Sticky

**Files:**
- Modify: `src/hub/role_anchor_node.gd`
- Modify: `src/hub/role_anchor_node.tscn`
- Modify: `src/hub/skill_tree_node.tscn`
- Modify: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Keeps: `RoleAnchorNode.setup(role: RoleDefinition, tree: RoleTreeDefinition) -> void`.
- Keeps: `SkillTreeNode.node_clicked(node_ui)` and all stable-ID focus signals.
- Produces no new runtime API.

- [ ] **Step 1: Write failing presentation regressions**

Extend the existing rendered-header tests to assert:

```gdscript
var anchor := role_panel.generated_nodes["gun.anchor"] as RoleAnchorNode
assert_null(anchor.get_node_or_null("Description"))
assert_eq(anchor.custom_minimum_size, Vector2(250, 50))
assert_eq(anchor.label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)

var paid := role_panel.generated_nodes["gun.atk_1"] as SkillTreeNode
var starting := role_panel.generated_nodes["gun.root"] as SkillTreeNode
assert_false(paid.toggle_mode)
assert_false(starting.toggle_mode)
paid._pressed()
starting._pressed()
assert_false(paid.button_pressed)
assert_false(starting.button_pressed)
assert_eq(get_signal_emit_count(role_panel, "purchase_requested"), 1)
assert_true(starting.owned_highlight.visible)
```

Retain the existing assertions that anchor/starting activation emits no purchase request, paid activation emits once, and real focus events update stable-ID memory.

- [ ] **Step 2: Run the focused hub test and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
```

Expected: the description node still exists and skill buttons remain in toggle mode or stay pressed after activation.

- [ ] **Step 3: Remove the description and toggle state**

In `role_anchor_node.gd`, remove the `description_label` reference and assignment. In `role_anchor_node.tscn`, delete the `Description` node and make the role-name label fill the full anchor height after the 50-pixel icon column:

```text
[node name="Label" type="Label" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 50.0
grow_horizontal = 2
grow_vertical = 2
horizontal_alignment = 1
vertical_alignment = 1
```

Keep the icon panel at `50 × 50`, the overall anchor at `250 × 50`, and all three arrows unchanged. In `skill_tree_node.tscn`, remove `toggle_mode = true` from the root `SkillTreeNode` button (or set it explicitly to `false`). Do not clear `button_pressed` imperatively in `_pressed()`.

- [ ] **Step 4: Run focused hub/navigation tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect skill_tree_navigation -gexit
git diff --check
git add src/hub/role_anchor_node.gd src/hub/role_anchor_node.tscn src/hub/skill_tree_node.tscn test/integration/test_hub_progression.gd
git commit -m "fix: simplify role header interaction"
```

Expected: focused tests pass; owned highlight and stable focus-memory regressions remain green.

### Task 2: Make Modal Teardown and Action Hints Lifecycle-Safe

**Files:**
- Modify: `src/ui/navigation/action_hint.gd`
- Modify: `src/ui/navigation/navigation_ux_layer.gd`
- Modify: `src/hub/party_menu.gd`
- Modify: `test/unit/test_action_hint_bar.gd`
- Modify: `test/integration/test_navigation_ux_layer.gd`

**Interfaces:**
- Produces: `NavigationUXLayer.remove_modal(root: Control) -> void`.
- Keeps: `NavigationUXLayer.pop_modal(root: Control) -> void` as the normal close-and-restore path.
- Keeps: `ActionHint.configure(data: Dictionary) -> void`, now valid both before and after `_ready()`.

- [ ] **Step 1: Write the pre-ready ActionHint regression**

Instantiate `action_hint.tscn` without adding it to the scene tree, call `configure()`, then add it and await readiness:

```gdscript
var hint := preload("res://src/ui/navigation/action_hint.tscn").instantiate() as ActionHint
hint.configure({action = &"confirm", label = "Select", enabled = false})
add_child_autofree(hint)
await get_tree().process_frame
assert_eq(hint.action, &"confirm")
assert_eq(hint.label.text, "Select")
assert_almost_eq(hint.modulate.a, 0.45, 0.001)
```

- [ ] **Step 2: Write modal removal/teardown regressions**

In the navigation integration test, register a screen, push a modal, then call `remove_modal(modal)` and assert:

```gdscript
assert_false(ux.is_top_modal(modal))
assert_ne(ux.get_focus_target(), prior_screen_focus)
assert_eq(ux.hint_bar.get_hint_count(), 0)
ux.remove_modal(modal) # idempotent
ux.pop_modal(modal) # no-op after removal
```

Add a PartyMenu teardown case that frees/removes the visible menu while the hub is registered and asserts no `ActionHint.configure` error, no restored hub focus, and no new hub hint publication. Keep the existing normal `_close()` test proving `pop_modal()` restores hub focus/hints.

- [ ] **Step 3: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_hint_bar -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
```

Expected: pre-ready `configure()` dereferences a null label and `remove_modal()` does not exist.

- [ ] **Step 4: Buffer ActionHint configuration until ready**

Store a defensive copy and apply only when child nodes are ready:

```gdscript
var _configuration: Dictionary = {}

func _ready() -> void:
	_apply_configuration()

func configure(data: Dictionary) -> void:
	_configuration = data.duplicate(true)
	action = _configuration.get("action", &"")
	enabled = _configuration.get("enabled", true)
	if is_node_ready():
		_apply_configuration()

func _apply_configuration() -> void:
	if not is_instance_valid(label):
		return
	label.text = _configuration.get("label", "")
	modulate.a = 1.0 if enabled else 0.45
```

`refresh()` continues to run after the hint enters the tree through `ActionHintBar.set_hints()`.

- [ ] **Step 5: Add non-restoring modal removal**

Implement `remove_modal(root)` in `NavigationUXLayer` by pruning state, finding the matching modal entry from the top down, erasing it without `_restore_from_entry()`, and clearing focus/cursor presentation plus the hint bar only when `_focus_target` belongs to that modal. It must not grab fallback focus or publish replacement hints.

Change `PartyMenu._exit_tree()` to call `navigation.remove_modal(self)`. Leave `_close()` calling `navigation.pop_modal(self)` before hiding, preserving normal restoration.

- [ ] **Step 6: Run focused/full verification and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_hint_bar -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
git add src/ui/navigation/action_hint.gd src/ui/navigation/navigation_ux_layer.gd src/hub/party_menu.gd test/unit/test_action_hint_bar.gd test/integration/test_navigation_ux_layer.gd
git commit -m "fix: avoid hint publication during modal teardown"
```

Expected: editor import exits 0, the full suite passes, and the `ActionHint.configure` null-assignment error is absent.
