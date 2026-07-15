# CTB Scrollable Rail and Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the split CTB queue with one readable, uniformly sized, fully scrollable rail whose entries and gauges animate through previews and committed timeline changes.

**Architecture:** `TurnQueue` owns one `ScrollContainer` and reuses `ActorQueue` controls by actor occurrence. `BattleManager` publishes an explicit update kind so the presentation can distinguish refresh, preview, commit, and turn advancement without guessing from actor identity. `ActorQueue` owns position/fade animation while `CTBGauge` owns deterministic tick interpolation.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` resources, GUT 9.6.1.

## Global Constraints

- Preserve normalized CT, deterministic tie ordering, signed CT, action recovery, and all combat rules unchanged.
- Use one 120 by 764 pixel rounded black rail and uniform 72 by 72 pixel entries.
- The rail background is black at 90% opacity.
- Non-current gauges keep the dark-gray track and paint light, medium, then dark faction bands as fully opaque same-width six-pixel strokes; later bands cover earlier bands without nested widths.
- The battlefield current actor keeps a `#FFC94A` acting outline beneath independent target outline and pulse layers for the full turn.
- The current occurrence scrolls with the rest and is identified only by its gold perimeter.
- Hover previews preserve scroll; commits and turn advances reset it to zero.
- On committed turn advancement, the consumed current entry slides left beyond the rail and fades over 0.3 seconds above the simultaneously promoted entries; preview removals remain fade-only.
- Use `HOME=/tmp/mars-godot-home` for every automated Godot import and test run.
- Preserve unrelated dirty files and commit only task-scoped files plus required Godot sidecars.
- Manual visual, controller, mouse-wheel, and touch acceptance remains required after automation.

---

### Task 1: Unified Rail Structure and Authored Colors

**Files:**
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/battle/actor_queue.tscn`
- Modify: `src/battle/turn_queue.gd`
- Modify: `src/battle/turn_queue.tscn`
- Modify: `src/battle/battle_scene.tscn`
- Modify: `test/unit/test_actor_queue.gd`
- Modify: `test/integration/test_turn_queue.gd`

**Interfaces:**
- Produces: `ActorQueue.ITEM_SIZE := Vector2(72, 72)`.
- Produces: `TurnQueue.queue_scroll: ScrollContainer`, `queue_content: Control`, and `queue_items: Array[ActorQueue]`.
- Preserves temporarily: the existing boolean second argument to `_on_turn_order_updated()`; Task 2 replaces it with `BattleManager.TurnOrderUpdate`.

- [ ] **Step 1: Write failing uniform-entry, color, background, and scrollbar tests**

Replace the split active/future assertions in `test/integration/test_turn_queue.gd` with tests that use the real queue scene:

```gdscript
const ARCHIVO := preload("res://data/theme/fonts/archivo.tres")


func _hero(actor_name: String, icon: Texture2D = null, color := Color.WHITE) -> HeroCard:
	var actor := HeroCard.new()
	actor.actor_name = actor_name
	var definition := RoleDefinition.new()
	definition.icon = icon
	definition.color = color
	var role := RoleData.new()
	role.source_definition = definition
	actor.loaded_roles = [role]
	actor.current_role_index = 0
	actors.append(actor)
	return actor


func test_real_queue_uses_one_uniform_scrollable_list() -> void:
	var icon := GradientTexture2D.new()
	var hero := _hero("Asher", icon, Color("56e5ff"))
	var enemy := _enemy("Scout Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 31},
		{"actor": hero, "ticks_needed": 50},
	], false)
	await get_tree().process_frame

	assert_false(queue.has_node("ActiveName"))
	assert_false(queue.has_node("ActiveSlot"))
	assert_eq(queue.queue_items.size(), 3)
	for item: ActorQueue in queue.queue_items:
		assert_same(item.get_parent(), queue.queue_content)
		assert_eq(item.size, Vector2(72, 72))
	assert_true(queue.queue_items[0].gauge._is_current)
	assert_false(queue.queue_items[1].gauge._is_current)
	assert_eq(queue.queue_items[2].occurrence_index, 1)


func test_queue_uses_role_color_archivo_and_enemy_gauge_magenta() -> void:
	var icon := GradientTexture2D.new()
	var hero := _hero("Echo", icon, Color("4f6fff"))
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 40},
	], false)
	await get_tree().process_frame

	assert_same(queue.queue_items[0].role_icon.texture, icon)
	assert_eq(queue.queue_items[0].role_icon.self_modulate, Color("4f6fff"))
	assert_eq(queue.queue_items[1].enemy_label.text, "AD A")
	assert_same(queue.queue_items[1].enemy_label.get_theme_font("font"), ARCHIVO)
	assert_eq(
		queue.queue_items[1].enemy_label.get_theme_color("font_color"),
		CTBGauge.ENEMY_COLORS[0],
	)


func test_rail_background_and_scrollbar_stay_inside_queue() -> void:
	var style := queue.rail_background.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, Color(0, 0, 0, 0.70))
	assert_eq(style.corner_radius_top_left, 18)
	assert_eq(style.corner_radius_top_right, 18)
	assert_eq(style.corner_radius_bottom_left, 18)
	assert_eq(style.corner_radius_bottom_right, 18)

	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), false)
	await get_tree().process_frame
	var bar := queue.queue_scroll.get_v_scroll_bar()
	assert_lte(bar.global_position.x + bar.size.x, queue.global_position.x + queue.size.x - 6.0)
	assert_eq(bar.modulate.a, 0.0)
	queue.queue_scroll.scroll_vertical = 80
	assert_eq(bar.modulate.a, 1.0)
	queue.queue_scroll.scroll_vertical = 0
	assert_eq(bar.modulate.a, 0.0)
```

Extend `test/unit/test_actor_queue.gd`:

```gdscript
func test_all_queue_entries_use_one_square_size() -> void:
	assert_eq(ActorQueue.ITEM_SIZE, Vector2(72, 72))
```

Delete the obsolete active-name and split active/future tests. In every retained test in this file, replace `queue.future_scroll` with `queue.queue_scroll`, `queue.future_content` with `queue.queue_content`, and `queue.future_items` with `queue.queue_items`. Remove `queue.active_item` and `queue.active_slot` assertions because entry zero now covers current-state behavior.

- [ ] **Step 2: Run the focused tests and confirm the structural failures**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: `ActorQueue.ITEM_SIZE`, `queue_scroll`, `queue_content`, `queue_items`, and `rail_background` are missing; the old split-queue scene still contains `ActiveName` and `ActiveSlot`.

- [ ] **Step 3: Make ActorQueue uniformly square and apply authored colors**

In `src/battle/actor_queue.gd`, replace both size constants with:

```gdscript
const ITEM_SIZE := Vector2(72, 72)
```

Change `setup()` so every item uses the same size and color source:

```gdscript
func setup(
	actor: ActorCard,
	ticks: int,
	is_current: bool,
	occurrence: int,
	animate_gauge := false,
) -> void:
	actor_ref = actor
	occurrence_index = occurrence
	custom_minimum_size = ITEM_SIZE
	size = ITEM_SIZE
	role_icon.visible = actor is HeroCard
	enemy_label.visible = actor is EnemyCard
	if actor is HeroCard:
		var role := (actor as HeroCard).get_current_role()
		role_icon.texture = role.icon if role else null
		role_icon.self_modulate = role.color if role else Color.WHITE
	else:
		enemy_label.text = enemy_abbreviation(actor.actor_name)
	gauge.configure(
		ticks,
		CTBGauge.Faction.HERO if actor is HeroCard else CTBGauge.Faction.ENEMY,
		is_current,
		animate_gauge,
	)
```

Task 3 adds the fourth `CTBGauge.configure()` argument. Until then, add it to `ctb_gauge.gd` as an unused defaulted parameter so Task 1 stays green:

```gdscript
func configure(
	ticks: int,
	faction: Faction,
	is_current: bool,
	_animate := false,
) -> void:
	_ticks = maxi(ticks, 0)
	_faction = faction
	_is_current = is_current
	queue_redraw()
```

In `src/battle/actor_queue.tscn`, add the Archivo resource and exact enemy styling:

```text
[ext_resource type="FontVariation" uid="uid://da34kbi1ndel7" path="res://data/theme/fonts/archivo.tres" id="3_archivo"]

[node name="EnemyLabel" type="Label" parent="Interior"]
theme_override_colors/font_color = Color(1, 0.35686275, 0.78431374, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_fonts/font = ExtResource("3_archivo")
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 19
```

- [ ] **Step 4: Replace the split scene with one inset scroll rail**

In `src/battle/turn_queue.tscn`:

- add a `StyleBoxFlat` with `bg_color = Color(0, 0, 0, 0.70)` and all four corner radii `18`;
- add a full-rect mouse-ignoring `Panel` named `RailBackground` behind every other child;
- remove `ActiveName`, `ActiveSlot`, and `FutureScroll`;
- add `QueueScroll` anchored full rect with offsets `6, 6, -6, -6`, horizontal scrolling disabled, and `scroll_deadzone = 12`;
- add `QueueContent` as the sole child of `QueueScroll` with minimum width `108`;
- keep `OverflowFade` above the scroll content and inset it by 6 pixels horizontally.

Use these node fields in `src/battle/turn_queue.gd`:

```gdscript
@onready var rail_background: Panel = $RailBackground
@onready var queue_scroll: ScrollContainer = $QueueScroll
@onready var queue_content: Control = $QueueScroll/QueueContent
@onready var overflow_fade: TextureRect = $OverflowFade

var queue_items: Array[ActorQueue] = []
```

Replace split layout construction with one loop. This is the non-animated Task 1 form; Task 3 adds reuse and transitions:

```gdscript
func _on_turn_order_updated(projected_queue: Array, animate: bool = true) -> void:
	var saved_scroll := queue_scroll.scroll_vertical
	for item: ActorQueue in queue_items:
		item.queue_free()
	queue_items.clear()
	if projected_queue.is_empty():
		_clear_queue()
		return

	var occurrences: Dictionary = {}
	for index in projected_queue.size():
		var turn_data: Dictionary = projected_queue[index]
		var actor: ActorCard = turn_data.actor
		var occurrence := int(occurrences.get(actor, 0))
		occurrences[actor] = occurrence + 1
		var item := actor_queue_scene.instantiate() as ActorQueue
		queue_content.add_child(item)
		item.setup(actor, int(turn_data.ticks_needed), index == 0, occurrence, false)
		item.position = _target_position(index)
		queue_items.append(item)

	queue_content.custom_minimum_size = Vector2(
		queue_scroll.size.x,
		queue_items.size() * int(ActorQueue.ITEM_SIZE.y + ITEM_SPACING) - ITEM_SPACING,
	)
	call_deferred("_restore_scroll", saved_scroll)


func _target_position(index: int) -> Vector2:
	var usable_width := queue_scroll.size.x - 10.0
	return Vector2(
		(usable_width - ActorQueue.ITEM_SIZE.x) * 0.5,
		index * (ActorQueue.ITEM_SIZE.y + ITEM_SPACING),
	)
```

Update scroll helpers to use `queue_scroll`. In `_ready()`, configure the internal scrollbar and connect it:

```gdscript
var bar := queue_scroll.get_v_scroll_bar()
bar.value_changed.connect(_on_scroll_changed)
bar.custom_minimum_size.x = 6.0
_on_scroll_changed(queue_scroll.scroll_vertical)


func _on_scroll_changed(value: float) -> void:
	var bar := queue_scroll.get_v_scroll_bar()
	bar.modulate.a = 0.0 if is_zero_approx(value) else 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_zero_approx(value) \
		else Control.MOUSE_FILTER_STOP
	_update_overflow_fade(value)
```

Update `_clear_queue()` to free `queue_items`, set content height and scroll to zero, hide the bar, and clear overflow state. Remove all active-name and active-slot handling.

In `src/battle/battle_scene.tscn`, restore `UI/CurrentAction.offset_right = -152.0`, its pre-name value. Because `UI/TurnQueue.offset_left = -136.0`, this leaves a 16-pixel gap. Delete the obsolete active-name collision test and assert instead that the action panel's global right edge is less than the queue rail's global left edge.

- [ ] **Step 5: Import and run Task 1 tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: import and both focused suites exit zero; all entries are 72-pixel squares inside one scroll content node.

- [ ] **Step 6: Commit Task 1**

```bash
git add src/battle/actor_queue.gd src/battle/actor_queue.tscn src/battle/ctb_gauge.gd src/battle/turn_queue.gd src/battle/turn_queue.tscn src/battle/battle_scene.tscn test/unit/test_actor_queue.gd test/integration/test_turn_queue.gd
git commit -m "feat: unify CTB queue rail"
```

---

### Task 2: Explicit Update Kinds and Scroll Policy

**Files:**
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/turn_queue.gd`
- Modify: `test/unit/test_ctb_simulator.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_turn_queue.gd`

**Interfaces:**
- Produces: `BattleManager.TurnOrderUpdate { REFRESH, PREVIEW, COMMIT, ADVANCE }`.
- Produces: `turn_order_updated(projected_queue: Array, update_kind: TurnOrderUpdate)`.
- Consumes: Task 1's `TurnQueue.queue_scroll` and unified queue list.

- [ ] **Step 1: Write failing update-kind and scroll-policy regressions**

Add to `test/unit/test_ctb_simulator.gd`:

```gdscript
func test_manager_publishes_explicit_preview_refresh_and_advance_kinds() -> void:
	var actor := _actor(100, 0, true, 0)
	manager.actor_list = [actor]
	manager.current_actor = actor
	var kinds: Array[int] = []
	manager.turn_order_updated.connect(
		func(_queue: Array, kind: BattleManager.TurnOrderUpdate) -> void: kinds.append(kind)
	)

	manager.update_turn_order()
	manager.preview_action_turn_order(actor, Action.new())
	manager._publish_turn_order(BattleManager.TurnOrderUpdate.COMMIT)

	assert_eq(kinds, [
		BattleManager.TurnOrderUpdate.REFRESH,
		BattleManager.TurnOrderUpdate.PREVIEW,
		BattleManager.TurnOrderUpdate.COMMIT,
	])
```

Extend `test/integration/test_turn_queue.gd`:

```gdscript
func test_preview_and_refresh_preserve_scroll_but_commit_and_advance_reset() -> void:
	var hero := _hero("Asher")
	var projection := _projection(hero, 21)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	queue.queue_scroll.scroll_vertical = 160

	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.PREVIEW)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 160)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 160)

	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.COMMIT)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	queue.queue_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.ADVANCE)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
```

Update navigation integration callbacks to accept `BattleManager.TurnOrderUpdate` instead of a boolean, while retaining their existing assertions.

- [ ] **Step 2: Run focused tests and verify enum failures**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_simulator -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: `TurnOrderUpdate` and `_publish_turn_order()` do not exist and the signal still emits booleans.

- [ ] **Step 3: Publish explicit update kinds from BattleManager**

Near the state enum in `src/battle/battle_manager.gd`, add:

```gdscript
enum TurnOrderUpdate { REFRESH, PREVIEW, COMMIT, ADVANCE }

signal turn_order_updated(projected_queue: Array, update_kind: TurnOrderUpdate)
```

Replace direct emissions with one boundary:

```gdscript
func _publish_turn_order(update_kind: TurnOrderUpdate) -> void:
	turn_order_updated.emit(_display_projection(), update_kind)


func update_turn_order() -> void:
	_publish_turn_order(TurnOrderUpdate.REFRESH)
```

In `find_and_start_next_turn()`, publish `ADVANCE` after assigning `current_actor`:

```gdscript
winner.current_ct = 0
current_actor = winner
_publish_turn_order(TurnOrderUpdate.ADVANCE)
```

In `preview_action_turn_order()`, retain adjustment calculation and emit:

```gdscript
turn_order_updated.emit(_display_projection(adjustments), TurnOrderUpdate.PREVIEW)
```

At the start of `execute_action()`, after capturing recovery fields but before effects mutate CT, clear the preview and signal a committed interaction only for visible chosen/enemy actions:

```gdscript
if display_name:
	_publish_turn_order(TurnOrderUpdate.COMMIT)
```

Starting passives use `display_name == false` and therefore do not manufacture a commit transition.

- [ ] **Step 4: Apply update kinds to TurnQueue scroll restoration**

Change the queue handler signature:

```gdscript
func _on_turn_order_updated(
	projected_queue: Array,
	update_kind: BattleManager.TurnOrderUpdate = BattleManager.TurnOrderUpdate.REFRESH,
) -> void:
	var resets_scroll := update_kind in [
		BattleManager.TurnOrderUpdate.COMMIT,
		BattleManager.TurnOrderUpdate.ADVANCE,
	]
	var saved_scroll := 0 if resets_scroll else queue_scroll.scroll_vertical
	if resets_scroll:
		queue_scroll.scroll_vertical = 0
	# Build or update content, then defer a clamped restoration of saved_scroll.
```

Preserve the generation-safe deferred restoration used by the current queue: increment `_projection_generation` for each update, pass it to `_restore_scroll`, and return without writing if the generation is stale. This prevents a deferred preview restoration from undoing a later commit reset.

- [ ] **Step 5: Run focused manager, navigation, and queue suites**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_simulator -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: all focused tests pass; preview/refresh retain displaced scroll and commit/advance cannot be overwritten by stale deferred work.

- [ ] **Step 6: Commit Task 2**

```bash
git add src/battle/battle_manager.gd src/battle/turn_queue.gd test/unit/test_ctb_simulator.gd test/integration/test_battle_controller_navigation.gd test/integration/test_turn_queue.gd
git commit -m "refactor: classify CTB queue updates"
```

---

### Task 3: Stable Reordering, Fade, and Gauge Interpolation

**Files:**
- Modify: `src/battle/ctb_gauge.gd`
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/battle/turn_queue.gd`
- Modify: `test/unit/test_ctb_gauge.gd`
- Modify: `test/integration/test_turn_queue.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Consumes: Task 2's `BattleManager.TurnOrderUpdate`.
- Produces: `CTBGauge.ANIMATION_DURATION`, `displayed_ticks: float`, and deterministic `_advance_animation(delta)`.
- Produces: occurrence-preserving `TurnQueue.queue_items` reuse and committed outgoing fade.

- [ ] **Step 1: Write failing deterministic gauge animation tests**

Add to `test/unit/test_ctb_gauge.gd`:

```gdscript
func test_gauge_interpolates_ticks_without_mutating_target() -> void:
	var gauge := CTBGauge.new()
	add_child_autofree(gauge)
	gauge.configure(20, CTBGauge.Faction.HERO, false, false)
	gauge.configure(40, CTBGauge.Faction.HERO, false, true)

	assert_eq(gauge.displayed_ticks, 20.0)
	assert_eq(gauge._target_ticks, 40.0)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	assert_eq(gauge.displayed_ticks, 30.0)
	assert_eq(CTBGauge.band_fills(gauge.displayed_ticks), [1.0, 0.5, 0.0])
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	assert_eq(gauge.displayed_ticks, 40.0)
	assert_false(gauge._is_animating)


func test_new_target_replaces_in_flight_gauge_animation() -> void:
	var gauge := CTBGauge.new()
	add_child_autofree(gauge)
	gauge.configure(20, CTBGauge.Faction.ENEMY, false, false)
	gauge.configure(60, CTBGauge.Faction.ENEMY, false, true)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	gauge.configure(10, CTBGauge.Faction.ENEMY, false, true)
	assert_eq(gauge._start_ticks, 40.0)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION)
	assert_eq(gauge.displayed_ticks, 10.0)
```

Change `band_fills()`'s parameter type from `int` to `float` while preserving all existing exact results.

- [ ] **Step 2: Write failing stable-reuse and outgoing-transition tests**

Add helpers and tests to `test/integration/test_turn_queue.gd`:

```gdscript
func _positions_by_item(items: Array[ActorQueue]) -> Dictionary:
	var result := {}
	for item: ActorQueue in items:
		result[item] = item.position
	return result


func test_preview_reuses_occurrences_and_visually_swaps_positions() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
		{"actor": hero, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var old_items := queue.queue_items.duplicate()
	var enemy_item := old_items[1] as ActorQueue
	var future_hero_item := old_items[2] as ActorQueue

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 20},
		{"actor": enemy, "ticks_needed": 35},
	], BattleManager.TurnOrderUpdate.PREVIEW)

	assert_same(queue.queue_items[1], future_hero_item)
	assert_same(queue.queue_items[2], enemy_item)
	assert_true(future_hero_item._move_tween != null)
	assert_true(enemy_item._move_tween != null)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout
	assert_eq(future_hero_item.position, queue._target_position(1))
	assert_eq(enemy_item.position, queue._target_position(2))


func test_advance_fades_consumed_occurrence_and_promotes_existing_future_item() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 20},
		{"actor": enemy, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var outgoing := queue.queue_items[0]
	var promoted := queue.queue_items[1]

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 20},
	], BattleManager.TurnOrderUpdate.ADVANCE)

	assert_true(outgoing._exit_tween != null)
	assert_same(queue.queue_items[0], promoted)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout
	assert_false(is_instance_valid(outgoing))
	assert_eq(promoted.position, queue._target_position(0))
	assert_true(promoted.gauge._is_current)


func test_rapid_preview_replaces_position_and_gauge_targets() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated(_projection(hero, 8, enemy), BattleManager.TurnOrderUpdate.REFRESH)
	queue._on_turn_order_updated(_projection(enemy, 8, hero), BattleManager.TurnOrderUpdate.PREVIEW)
	queue._on_turn_order_updated(_projection(hero, 8, enemy), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout

	for index in queue.queue_items.size():
		var item := queue.queue_items[index]
		assert_eq(item.position, queue._target_position(index))
		assert_eq(item.gauge.displayed_ticks, float(index * 5))
```

- [ ] **Step 3: Run gauge and queue suites and confirm interpolation/reuse failures**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: gauge animation fields and occurrence reuse are absent; Task 1 still rebuilds every item.

- [ ] **Step 4: Implement deterministic gauge interpolation**

In `src/battle/ctb_gauge.gd` add:

```gdscript
const ANIMATION_DURATION := 0.30

var displayed_ticks := 0.0
var _start_ticks := 0.0
var _target_ticks := 0.0
var _animation_elapsed := 0.0
var _is_animating := false
```

Replace `configure()` and add deterministic advancement:

```gdscript
func configure(
	ticks: int,
	faction: Faction,
	is_current: bool,
	animate := false,
) -> void:
	_faction = faction
	_is_current = is_current
	_target_ticks = float(maxi(ticks, 0))
	if animate and not is_equal_approx(displayed_ticks, _target_ticks):
		_start_ticks = displayed_ticks
		_animation_elapsed = 0.0
		_is_animating = true
		set_process(true)
	else:
		displayed_ticks = _target_ticks
		_start_ticks = displayed_ticks
		_animation_elapsed = ANIMATION_DURATION
		_is_animating = false
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_advance_animation(delta)


func _advance_animation(delta: float) -> void:
	if not _is_animating:
		return
	_animation_elapsed = minf(_animation_elapsed + maxf(delta, 0.0), ANIMATION_DURATION)
	var weight := _animation_elapsed / ANIMATION_DURATION
	displayed_ticks = lerpf(_start_ticks, _target_ticks, weight)
	queue_redraw()
	if is_equal_approx(_animation_elapsed, ANIMATION_DURATION):
		displayed_ticks = _target_ticks
		_is_animating = false
		set_process(false)
```

Use `band_fills(displayed_ticks)` in `_draw()`. Current gold rendering remains full perimeter and unchanged.

- [ ] **Step 5: Reuse occurrence controls and animate the latest projection**

In `src/battle/actor_queue.gd`, keep independent position and exit tweens:

```gdscript
var _move_tween: Tween
var _exit_tween: Tween


func animate_to(target_position: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_property(self, "position", target_position, ANIMATION_DURATION)


func animate_exit() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	_exit_tween.tween_callback(queue_free)
```

In `src/battle/turn_queue.gd`, replace Task 1's rebuild with FIFO actor-occurrence reuse:

```gdscript
func _take_actor_item(actor: ActorCard, pool: Array[ActorQueue]) -> ActorQueue:
	for index in pool.size():
		if pool[index].actor_ref == actor:
			return pool.pop_at(index)
	return null
```

At the start of an `ADVANCE` update, remove the old first item from the reuse pool and call `animate_exit()` on it. This ensures a repeated future turn from the same actor, rather than the consumed current occurrence, is promoted. For all other update kinds, keep every old item eligible.

For each new projection entry in order:

```gdscript
var item := _take_actor_item(actor, reusable)
var reused := item != null
if not reused:
	item = actor_queue_scene.instantiate() as ActorQueue
	queue_content.add_child(item)
	item.position = _target_position(index)
	item.modulate.a = 1.0
item.setup(actor, int(turn_data.ticks_needed), index == 0, occurrence, reused)
item.z_index = index
if reused:
	item.animate_to(_target_position(index))
queue_items.append(item)
```

Animate every unused pooled item out. Reassign each reused item's `occurrence_index` through `setup()` so repeated actor occurrences remain distinct in the latest projection. Use actor FIFO order rather than exact old occurrence number so consuming occurrence zero correctly promotes the actor's next visible occurrence.

On an empty projection, kill active item tweens before freeing, reset content/scroll/scrollbar/overflow synchronously, and increment the projection generation so deferred callbacks cannot restore stale state.

- [ ] **Step 6: Update manual acceptance**

In `docs/testing/ctb-combat-checklist.md`, remove the obsolete active-name and oversized-active checks. Add unchecked checks for:

- one rounded semi-transparent black rail containing the entire queue;
- uniform 72 by 72 squares and gold-only current distinction;
- authored role-color hero icons and Archivo magenta enemy abbreviations;
- inset scrollbar hidden at top and persistent while displaced;
- full-list mouse wheel, touch, and right-stick scrolling;
- preview reorder and preview-clear animations that preserve scroll;
- commit/advance snap-to-top behavior;
- outgoing fade, upward slide, visible Fast/Slow crossing swaps, and simultaneous gauge interpolation;
- rapid hover changes settling on the latest projection without flashes or stale movement.

- [ ] **Step 7: Import, run focused suites, then run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: import and all focused/full suites exit zero, with no parser errors, crashes, or unexpected runtime errors. Record exact test and assertion totals; the documented CA and engine-shutdown diagnostics remain acceptable.

- [ ] **Step 8: Commit Task 3**

```bash
git add src/battle/ctb_gauge.gd src/battle/actor_queue.gd src/battle/turn_queue.gd test/unit/test_ctb_gauge.gd test/integration/test_turn_queue.gd docs/testing/ctb-combat-checklist.md
git commit -m "feat: animate CTB timeline changes"
```

---

### Task 4: Gauge Readability and Acting-Unit Correspondence

**Files:**
- Modify: `src/battle/ctb_gauge.gd`
- Modify: `src/battle/turn_queue.tscn`
- Modify: `src/battle/hero_card.tscn`
- Modify: `src/battle/enemy_card.tscn`
- Modify: `test/unit/test_ctb_gauge.gd`
- Modify: `test/unit/test_actor_card_target_presentation.gd`
- Modify: `test/integration/test_turn_queue.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Consumes: `CTBGauge.GAUGE_WIDTH`, `HERO_COLORS`, `ENEMY_COLORS`, `TRACK_COLOR`, and `CURRENT_COLOR`.
- Produces: `CTBGauge.faction_strokes(ticks: float, faction: Faction) -> Array[Dictionary]`, the single source used by `_draw()` for faction layer order, fill, color, and width.
- Preserves: existing 20-tick band calculations, gauge interpolation, current gold perimeter, target presentation, CT rules, scroll behavior, and queue animation.

- [ ] **Step 1: Write failing same-width gauge-layer tests**

Add to `test/unit/test_ctb_gauge.gd`:

```gdscript
func test_faction_strokes_overlay_light_medium_dark_at_one_width() -> void:
	var hero := CTBGauge.faction_strokes(50.0, CTBGauge.Faction.HERO)
	assert_eq(hero.size(), 3)
	assert_eq(hero[0], {
		"color": CTBGauge.HERO_COLORS[0],
		"fraction": 1.0,
		"width": CTBGauge.GAUGE_WIDTH,
	})
	assert_eq(hero[1], {
		"color": CTBGauge.HERO_COLORS[1],
		"fraction": 1.0,
		"width": CTBGauge.GAUGE_WIDTH,
	})
	assert_eq(hero[2], {
		"color": CTBGauge.HERO_COLORS[2],
		"fraction": 0.5,
		"width": CTBGauge.GAUGE_WIDTH,
	})

	var enemy := CTBGauge.faction_strokes(30.0, CTBGauge.Faction.ENEMY)
	assert_eq(enemy.size(), 2)
	assert_eq(enemy[0].color, CTBGauge.ENEMY_COLORS[0])
	assert_eq(enemy[0].width, CTBGauge.GAUGE_WIDTH)
	assert_eq(enemy[1].color, CTBGauge.ENEMY_COLORS[1])
	assert_eq(enemy[1].fraction, 0.5)
	assert_eq(enemy[1].width, CTBGauge.GAUGE_WIDTH)
```

This test fixes the draw order as light, medium, dark and prevents a future return to `GAUGE_WIDTH - band * 2.0` nested strokes.

- [ ] **Step 2: Write failing rail-opacity and acting-outline tests**

In the existing `test_rail_background_and_scrollbar_stay_inside_queue()` in `test/integration/test_turn_queue.gd`, change only the background assertion to the approved value and retain its existing radius, inset-scrollbar, and top/displaced visibility assertions:

```gdscript
assert_eq(style.bg_color, Color(0, 0, 0, 0.90))
```

Add to `test/unit/test_actor_card_target_presentation.gd`:

```gdscript
func test_acting_outline_matches_queue_gold_and_stays_independent_of_targeting() -> void:
	for card in _cards():
		var acting_outline := card.get_node("Panel/Highlight") as Panel
		var acting_style := acting_outline.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(acting_style.border_color, CTBGauge.CURRENT_COLOR)
		assert_false(acting_outline.visible)

		card.highlight(true)
		card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		assert_true(acting_outline.visible)
		assert_eq(acting_style.border_color, Color("ffc94a"))
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)

		card.highlight(false)
		assert_false(acting_outline.visible)
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)
```

- [ ] **Step 3: Run focused suites and verify the expected RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: the gauge suite fails because `faction_strokes()` does not exist; actor-card tests report white acting borders; the queue test reports rail alpha `0.7` instead of `0.9`.

- [ ] **Step 4: Make the rail background 90% opaque**

In `src/battle/turn_queue.tscn`, change only the rail backing color:

```text
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_rail"]
bg_color = Color(0, 0, 0, 0.9)
```

Retain the four 18-pixel radii, node geometry, scroll insets, and mouse filtering unchanged.

- [ ] **Step 5: Replace nested gauge widths with one layered-stroke description**

In `src/battle/ctb_gauge.gd`, add:

```gdscript
static func faction_strokes(ticks: float, faction: Faction) -> Array[Dictionary]:
	var colors := HERO_COLORS if faction == Faction.HERO else ENEMY_COLORS
	var fills := band_fills(ticks)
	var strokes: Array[Dictionary] = []
	for band in 3:
		if fills[band] <= 0.0:
			continue
		strokes.append({
			"color": colors[band],
			"fraction": fills[band],
			"width": GAUGE_WIDTH,
		})
	return strokes
```

Replace the non-current portion of `_draw()` with:

```gdscript
	for stroke: Dictionary in faction_strokes(displayed_ticks, _faction):
		var partial := partial_polyline(path, float(stroke.fraction))
		if partial.size() >= 2:
			var stroke_color: Color = stroke.color
			var stroke_width: float = stroke.width
			draw_polyline(
				partial,
				stroke_color,
				stroke_width,
				true,
			)
```

Keep the dark-gray track draw first and the current gold early return unchanged. Array order ensures later medium/dark same-width strokes cover earlier light/medium portions.

- [ ] **Step 6: Recolor the existing acting layers to queue gold**

In both `src/battle/hero_card.tscn` and `src/battle/enemy_card.tscn`, change only the eight-pixel `Highlight` style's border color:

```text
border_color = Color(1, 0.7882353, 0.2901961, 1)
```

This is `#FFC94A`, matching `CTBGauge.CURRENT_COLOR`. Do not change `TargetOutline` or `TargetPulse`; their independent visibility, white border, pulse tween, and sibling layering remain intact. `ActorCard.on_turn_started()` and `on_turn_ended()` already call `highlight(true)` and `highlight(false)`, so no new lifecycle state is required.

- [ ] **Step 7: Update the manual CTB checklist**

In `docs/testing/ctb-combat-checklist.md`, replace the generic semi-transparent-rail check with these unchecked acceptance items:

- the unified rounded rail is black at 90% opacity and keeps icons/text readable over bright combat backgrounds;
- non-current gauges show a subtle dark-gray track with same-width opaque light, medium, and dark faction strokes covering one another, with no nested colored outlines;
- the acting battlefield card uses the exact queue gold for the full hero or enemy turn;
- target availability, selection outline, and pulse remain independently visible while the acting gold outline persists beneath them.

- [ ] **Step 8: Import, run focused suites, then run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: import and all focused/full suites exit zero with no parser errors, crashes, or unexpected runtime errors. Record exact totals; the documented CA, expected-error, and shutdown diagnostics remain acceptable.

- [ ] **Step 9: Commit Task 4**

```bash
git add src/battle/ctb_gauge.gd src/battle/turn_queue.tscn src/battle/hero_card.tscn src/battle/enemy_card.tscn test/unit/test_ctb_gauge.gd test/unit/test_actor_card_target_presentation.gd test/integration/test_turn_queue.gd docs/testing/ctb-combat-checklist.md
git commit -m "fix: clarify CTB gauge layers"
```

### Task 5: Clear the Consumed Turn Laterally

**Files:**
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/battle/turn_queue.gd`
- Modify: `src/battle/turn_queue.tscn`
- Modify: `test/integration/test_turn_queue.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Produces: `ActorQueue.COMMITTED_EXIT_DISTANCE := 96.0` and `animate_committed_exit() -> void`.
- Produces: `TurnQueue.exit_layer: Control`, an unclipped, mouse-ignoring overlay above the queue scroll.
- Preserves: `animate_exit() -> void` as the fade-only exit for preview removals and other non-committed disappearances.

- [ ] **Step 1: Write failing committed-exit and preview-removal tests**

Replace `test_advance_fades_consumed_occurrence_and_promotes_existing_future_item()` in `test/integration/test_turn_queue.gd` with:

```gdscript
func test_advance_slides_consumed_occurrence_left_above_promoted_item() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 20},
		{"actor": enemy, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var outgoing := queue.queue_items[0]
	var promoted := queue.queue_items[1]
	var outgoing_start_x := outgoing.global_position.x

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 20},
	], BattleManager.TurnOrderUpdate.ADVANCE)

	assert_true(outgoing._exit_tween != null)
	assert_same(outgoing.get_parent(), queue.exit_layer)
	assert_gt(queue.exit_layer.z_index, queue.queue_scroll.z_index)
	assert_same(queue.queue_items[0], promoted)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5).timeout
	assert_lt(outgoing.global_position.x, outgoing_start_x)
	assert_lt(outgoing.modulate.a, 1.0)
	assert_gt(promoted.position.y, queue._target_position(0).y)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5 + 0.05).timeout
	assert_false(is_instance_valid(outgoing))
	assert_eq(promoted.position, queue._target_position(0))
	assert_true(promoted.gauge._is_current)
```

Add a focused boundary test showing previews keep the existing fade-only path:

```gdscript
func test_preview_removal_fades_in_place_inside_queue_content() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var removed := queue.queue_items[1]
	var start_position := removed.position

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
	], BattleManager.TurnOrderUpdate.PREVIEW)

	assert_same(removed.get_parent(), queue.queue_content)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5).timeout
	assert_eq(removed.position, start_position)
	assert_lt(removed.modulate.a, 1.0)
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: the suite fails because `TurnQueue.exit_layer` does not exist and committed exits remain at their original horizontal position in `queue_content`. The new preview-removal test passes, confirming the existing fade-only boundary before production changes.

- [ ] **Step 3: Add an unclipped exit overlay above the scroll container**

In `src/battle/turn_queue.tscn`, add this sibling after `QueueScroll` so a consumed entry can leave the rail without changing the scroll container's clipping behavior:

```text
[node name="ExitLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
z_index = 10
```

In `src/battle/turn_queue.gd`, expose the layer with the other scene references:

```gdscript
@onready var exit_layer: Control = $ExitLayer
```

The layer must retain the default `clip_contents = false`; do not disable clipping on `QueueScroll`, because that would allow ordinary future entries to spill outside the rail while scrolling.

- [ ] **Step 4: Add the committed leftward fade animation**

In `src/battle/actor_queue.gd`, add the distance beside the existing animation constants:

```gdscript
const COMMITTED_EXIT_DISTANCE := 96.0
```

Add a separate committed exit method, leaving `animate_exit()` unchanged:

```gdscript
func animate_committed_exit() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.set_parallel(true)
	_exit_tween.tween_property(
		self,
		"position",
		position + Vector2.LEFT * COMMITTED_EXIT_DISTANCE,
		ANIMATION_DURATION,
	)
	_exit_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	_exit_tween.chain().tween_callback(queue_free)
```

The position and alpha properties animate in parallel with cubic ease-out for the same 0.3-second duration, clearing the promoted entry's lane early. The existing `cancel_animations()` and instance-validity pruning continue to own interrupted-tween cleanup.

- [ ] **Step 5: Reparent only the committed current exit and clear both containers safely**

In the `ADVANCE` branch of `TurnQueue._on_turn_order_updated()`, preserve the global transform while moving the outgoing entry above the clipped scroll content, then start the committed exit:

```gdscript
		var outgoing := current_items[0]
		reusable.erase(outgoing)
		outgoing.reparent(exit_layer, true)
		outgoing.animate_committed_exit()
		_committed_exits.append(outgoing)
```

In `_clear_queue()`, replace the single-container child loop with:

```gdscript
	for container: Node in [queue_content, exit_layer]:
		for child in container.get_children():
			if child is ActorQueue:
				var item := child as ActorQueue
				item.cancel_animations()
				item.free()
```

This keeps empty projections synchronous even if a committed exit is currently outside `QueueContent`. Do not add committed exits to the recoverable pool; consumed occurrences must never be revived by a subsequent preview refresh.

- [ ] **Step 6: Run the focused suite and verify GREEN**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: all turn-queue tests pass. At the midpoint, the consumed entry has moved left and partially faded in the higher exit layer while the promoted entry is still moving upward; preview-only removal remains stationary and fade-only.

- [ ] **Step 7: Update manual acceptance**

In `docs/testing/ctb-combat-checklist.md`, replace the committed outgoing-fade wording with unchecked checks that:

- the consumed top entry slides left beyond the black rail while fading, visibly above the simultaneously promoted entry;
- the promoted entry and remaining queue slide upward without covering the consumed entry;
- hover-preview removals fade in place and never use the committed leftward exit;
- the leftward exit remains visible outside the rail rather than being clipped at its edge.

- [ ] **Step 8: Import, run focused tests, then run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: import and all focused/full suites exit zero with no parser errors, crashes, or unexpected runtime errors. Record exact totals; the documented CA and engine-shutdown diagnostics remain acceptable. Complete the new visual checks manually at the 1920 by 1080 reference viewport.

- [ ] **Step 9: Commit Task 5**

```bash
git add src/battle/actor_queue.gd src/battle/turn_queue.gd src/battle/turn_queue.tscn test/integration/test_turn_queue.gd docs/testing/ctb-combat-checklist.md
git commit -m "fix: slide consumed CTB turn left"
```
