extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


class TestBattleManager extends BattleManager:
	func _ready() -> void:
		pass


func _gdscript_paths(root: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(root)
	assert_not_null(directory, "source directory exists: %s" % root)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			paths.append_array(_gdscript_paths(path))
		elif entry.ends_with(".gd"):
			paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return paths


func _combatant(
	max_hp: int = 100,
	faction: BattleCombatant.Faction = BattleCombatant.Faction.HERO,
	manager: BattleManager = null,
) -> BattleCombatant:
	var combatant: BattleCombatant = HeroCombatant.new() \
		if faction == BattleCombatant.Faction.HERO else EnemyCombatant.new()
	add_child_autofree(combatant)
	var stats := ActorStats.new()
	stats.actor_name = "Sands"
	stats.max_hp = max_hp
	combatant.setup_base(stats, faction, manager)
	return combatant


func _damage_result(amount: int) -> DamageResult:
	var request := DamageRequest.new(
		amount, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 0,
	)
	return DamageResult.new(
		request, amount, 0, 1.0, 1.0, 1.0, amount, amount,
	)


func test_preview_only_card_binding_is_reserved_for_damage_preview_snapshots() -> void:
	assert_false(
		FileAccess.file_exists("res://test/helpers/" + "card_test_factory.gd"),
		"ordinary test fixtures must not default cards into preview-only binding",
	)
	var preview_binding := RegEx.new()
	assert_eq(
		preview_binding.compile("bind_combatant\\([^\\)]*,[^\\)]*\\)"),
		OK,
	)
	var allowed_paths := {
		"res://src/battle/actor_card.gd": true,
		"res://src/battle/damage/damage_preview.gd": true,
		"res://test/unit/test_damage_preview.gd": true,
	}
	var unexpected_paths := PackedStringArray()
	for root in ["res://src", "res://test"]:
		for path in _gdscript_paths(root):
			var source := FileAccess.get_file_as_string(path)
			if preview_binding.search(source) != null and not allowed_paths.has(path):
				unexpected_paths.append(path)
	assert_eq(
		unexpected_paths,
		PackedStringArray(),
		"preview-only card bindings are limited to detached DamagePreview snapshots",
	)


func test_card_mirrors_combatant_without_owning_duplicate_hp() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()

	card.bind_combatant(combatant)
	combatant.current_hp = 40
	combatant.hp_changed.emit(combatant, 40, 100)
	await get_tree().process_frame

	assert_same(card.combatant, combatant)
	assert_eq(card.hp_bar_actual.value, 100.0)
	assert_eq(card.current_hp, 40)
	card.current_hp = 55
	assert_eq(combatant.current_hp, 55)


func test_bound_hero_forwards_one_model_focus_change_once() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var model := _combatant() as HeroCombatant
	model.hero_data = HeroData.new()
	model.hero_data.stats = model.current_stats
	model.current_focus = 5
	watch_signals(card)

	await card.setup_from_combatant(model)
	await model.modify_focus(-2, {"paid_focus_cost": 2})

	assert_eq(card.current_focus, 3)
	assert_signal_emit_count(card, "focus_updated", 1)


func test_card_adapter_reports_live_screen_geometry() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.position = Vector2(90, 40)
	card.size = Vector2(200, 100)
	await get_tree().process_frame

	assert_eq(
		card.presentation.get_target_screen_position(),
		card.get_global_rect().get_center(),
	)


func test_damage_stages_actual_hp_then_animates_ghost_without_hit_shake() -> void:
	var manager := TestBattleManager.new()
	add_child_autofree(manager)
	manager.battle_speed = 5.0
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.battle_manager = manager
	var combatant := _combatant(100, BattleCombatant.Faction.HERO, manager)
	card.bind_combatant(combatant)

	await combatant.take_one_hit(
		_damage_result(40), Effect_Damage.new(), combatant,
		Action.DamageType.KINETIC,
	)

	assert_eq(card.hp_bar_actual.value, 60.0)
	assert_eq(card.hp_bar_ghost.value, 100.0)
	assert_null(card.shake_tween, "ordinary hits do not shake the actor card")
	var tween := card.sync_visual_health()
	assert_not_null(tween)
	if tween != null:
		await tween.finished
	assert_eq(card.hp_bar_ghost.value, 60.0)


func test_healing_stages_ghost_hp_then_animates_actual_bar() -> void:
	var manager := TestBattleManager.new()
	add_child_autofree(manager)
	manager.battle_speed = 5.0
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.battle_manager = manager
	var combatant := _combatant(100, BattleCombatant.Faction.HERO, manager)
	combatant.current_hp = 40
	card.bind_combatant(combatant)

	await combatant.take_healing(20)

	assert_eq(card.hp_bar_actual.value, 40.0)
	assert_eq(card.hp_bar_ghost.value, 60.0)
	var tween := card.sync_visual_health()
	assert_not_null(tween)
	if tween != null:
		await tween.finished
	assert_eq(card.hp_bar_actual.value, 60.0)


func test_binding_already_breached_combatant_renders_steady_breach_state() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()
	combatant.is_breached = true
	var breach_signal_count := 0
	card.actor_breached.connect(func(_actor): breach_signal_count += 1)

	card.bind_combatant(combatant)

	assert_eq(card.breached_label.text, "BREACHED")
	assert_eq(card.guard_bar.modulate.a, 0.25)
	assert_null(card.shake_tween)
	assert_eq(breach_signal_count, 0)


func test_binding_already_defeated_hero_renders_final_state_without_signal() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()
	combatant.is_breached = true
	combatant.is_defeated = true
	var defeat_signal_count := 0
	card.actor_defeated.connect(func(_actor): defeat_signal_count += 1)

	card.bind_combatant(combatant)

	assert_eq(card.self_modulate.a, 0.25)
	assert_null(card.pulse_tween)
	assert_false(card.breached_label.visible)
	assert_eq(defeat_signal_count, 0)


func test_binding_defeated_combatant_with_retained_danger_skips_transients() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()
	combatant.is_in_danger = true
	combatant.is_defeated = true
	var defeat_signal_count := 0
	card.actor_defeated.connect(func(_actor): defeat_signal_count += 1)

	card.bind_combatant(combatant)

	assert_eq(card.self_modulate.a, 0.25)
	assert_null(card.pulse_tween)
	assert_false(card.breached_label.visible)
	assert_eq(defeat_signal_count, 0)


func test_binding_already_defeated_enemy_renders_final_state_immediately() -> void:
	var card := EnemyCardScene.instantiate() as EnemyCard
	add_child_autofree(card)
	var combatant := _combatant(
		100, BattleCombatant.Faction.ENEMY,
	)
	combatant.is_defeated = true

	card.bind_combatant(combatant)

	assert_eq(card.modulate.a, 0.0)
