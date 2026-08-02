extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


class TestBattleManager extends BattleManager:
	var particle_requests: Array[Dictionary] = []

	func _ready() -> void:
		pass

	func _on_spawn_particles(pos: Vector2, type: String) -> void:
		particle_requests.append({"position": pos, "type": type})


class SpawnFailureBattleManager extends TestBattleManager:
	var fade_calls := 0
	var passive_calls := 0
	var turn_calls := 0

	func _fade_in(_duration: float = 0.5) -> void:
		fade_calls += 1

	func wait(_duration: float = 0.01) -> void:
		pass

	func _flush_all_health_animations() -> void:
		pass

	func _apply_starting_passives() -> void:
		passive_calls += 1

	func find_and_start_next_turn() -> void:
		turn_calls += 1


class TrackingCombatantPresentation extends CombatantPresentation:
	func setup_view(value: BattleCombatant) -> bool:
		value.set_meta(&"tracking_presentation_bound", true)
		return super.setup_view(value)


class NoOpSetupPresentation extends CombatantPresentation:
	func setup_view(_value: BattleCombatant) -> bool:
		return true


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


func _non_card_view_scene(nested: bool) -> PackedScene:
	var scene := PackedScene.new()
	var presentation := CombatantPresentation.new()
	presentation.name = "FloatingStatus"
	var view_root: Node = presentation
	if nested:
		view_root = Node3D.new()
		view_root.name = "EnemyModel"
		view_root.add_child(presentation)
		presentation.owner = view_root
	assert_eq(scene.pack(view_root), OK)
	view_root.free()
	return scene


func _view_scene_with_presentation_count(count: int) -> PackedScene:
	var scene := PackedScene.new()
	var view_root := Node3D.new()
	view_root.name = "InvalidEnemyView"
	for index in count:
		var presentation := TrackingCombatantPresentation.new()
		presentation.name = "FloatingStatus%d" % index
		view_root.add_child(presentation)
		presentation.owner = view_root
	assert_eq(scene.pack(view_root), OK)
	view_root.free()
	return scene


func _no_op_view_scene() -> PackedScene:
	var scene := PackedScene.new()
	var presentation := NoOpSetupPresentation.new()
	presentation.name = "NoOpPresentation"
	assert_eq(scene.pack(presentation), OK)
	presentation.free()
	return scene


func _assert_invalid_view_is_rejected(presentation_count: int) -> void:
	var manager := TestBattleManager.new()
	var view_parent := Node3D.new()
	manager.add_child(view_parent)
	add_child_autofree(manager)
	var model := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	var initial_child_count := view_parent.get_child_count()

	var presentation := manager._spawn_presentation_view(
		_view_scene_with_presentation_count(presentation_count),
		view_parent,
		model,
	)

	assert_push_error("found %d" % presentation_count)
	assert_null(presentation)
	assert_eq(view_parent.get_child_count(), initial_child_count)
	assert_null(manager.presentation_for(model))
	assert_false(model.has_meta(&"tracking_presentation_bound"))
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_exit_callbacks.is_empty())


func test_manager_rejects_view_scene_without_a_presentation_before_adoption() -> void:
	_assert_invalid_view_is_rejected(0)


func test_manager_rejects_view_scene_with_multiple_presentations_before_adoption() -> void:
	_assert_invalid_view_is_rejected(2)


func test_manager_rejects_missing_view_inputs_with_runtime_errors() -> void:
	var manager := TestBattleManager.new()
	var view_parent := Node3D.new()
	manager.add_child(view_parent)
	add_child_autofree(manager)
	var model := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	var view_scene := _non_card_view_scene(false)

	assert_null(manager._spawn_presentation_view(null, view_parent, model))
	assert_push_error("null scene")
	assert_null(manager._spawn_presentation_view(view_scene, null, model))
	assert_push_error("without a valid parent")
	assert_null(manager._spawn_presentation_view(view_scene, view_parent, null))
	assert_push_error("for an invalid combatant")
	assert_eq(view_parent.get_child_count(), 0)
	assert_true(manager._presentations.is_empty())


func test_manager_rejects_no_op_setup_and_removes_partial_view() -> void:
	var manager := TestBattleManager.new()
	var view_parent := Node3D.new()
	manager.add_child(view_parent)
	add_child_autofree(manager)
	var model := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	var presentation := manager._spawn_presentation_view(
		_no_op_view_scene(), view_parent, model,
	)

	assert_push_error("did not bind the requested combatant")
	assert_null(presentation)
	assert_eq(view_parent.get_child_count(), 0)
	assert_null(manager.presentation_for(model))
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_exit_callbacks.is_empty())


func test_manager_rejects_hero_card_for_enemy_and_removes_partial_view() -> void:
	var manager := TestBattleManager.new()
	var view_parent := Control.new()
	manager.add_child(view_parent)
	add_child_autofree(manager)
	var enemy := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	var presentation := manager._spawn_presentation_view(
		HeroCardScene, view_parent, enemy,
	)

	assert_push_error("HeroCard requires a HeroCombatant")
	assert_null(presentation)
	assert_eq(view_parent.get_child_count(), 0)
	assert_null(manager.presentation_for(enemy))
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_exit_callbacks.is_empty())


func test_registry_rejects_one_presentation_for_two_combatants() -> void:
	var manager := TestBattleManager.new()
	var presentation := CombatantPresentation.new()
	manager.add_child(presentation)
	add_child_autofree(manager)
	var first := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var second := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	presentation.bind(first)

	assert_true(manager.register_presentation(first, presentation))
	assert_false(manager.register_presentation(second, presentation))

	assert_push_error("already registered to another combatant")
	assert_same(manager.presentation_for(first), presentation)
	assert_null(manager.presentation_for(second))
	assert_same(presentation.combatant, first)
	assert_eq(manager._presentations.size(), 1)
	assert_eq(manager._presentation_exit_callbacks.size(), 1)


func test_setup_rejects_rebinding_a_registered_presentation() -> void:
	var manager := TestBattleManager.new()
	var presentation := CombatantPresentation.new()
	manager.add_child(presentation)
	add_child_autofree(manager)
	var first := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var second := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	assert_true(presentation.setup_view(first))
	assert_true(manager.register_presentation(first, presentation))
	assert_false(presentation.setup_view(second))

	assert_push_error("cannot be rebound")
	assert_same(presentation.combatant, first)
	assert_same(manager.presentation_for(first), presentation)
	assert_null(manager.presentation_for(second))
	assert_eq(manager._presentations.size(), 1)


func test_spawn_encounter_aborts_and_discards_model_when_view_is_invalid() -> void:
	var manager := SpawnFailureBattleManager.new()
	manager.combatant_root = Node.new()
	manager.hero_area = Node3D.new()
	manager.enemy_area = Node3D.new()
	manager.add_child(manager.combatant_root)
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.hero_card_scene = _non_card_view_scene(false)
	manager.enemy_card_scene = _view_scene_with_presentation_count(0)
	manager.current_encounter = Encounter.new()
	manager.current_encounter.enemies = [EnemyData.new()]
	add_child_autofree(manager)
	var hero_data := HeroData.new()
	hero_data.hero_name = "Failed Hero"
	hero_data.derived_state_is_prebuilt = true
	hero_data.stats = ActorStats.new()
	hero_data.stats.actor_name = hero_data.hero_name
	hero_data.stats.max_hp = 100
	hero_data.stats.speed = 10

	await manager.spawn_encounter([hero_data], 1, 77, false)

	assert_push_error("found 0")
	assert_true(manager.actor_list.is_empty())
	assert_eq(manager.combatant_root.get_child_count(), 0)
	assert_eq(manager.hero_area.get_child_count(), 0)
	assert_eq(manager.enemy_area.get_child_count(), 0)
	assert_true(manager._combatant_exit_callbacks.is_empty())
	assert_true(manager._presentations.is_empty())
	assert_eq(manager.fade_calls, 0)
	assert_eq(manager.passive_calls, 0)
	assert_eq(manager.turn_calls, 0)


func test_manager_spawns_root_and_nested_non_card_views_through_presentation_contract() -> void:
	var manager := TestBattleManager.new()
	var view_parent := Node3D.new()
	manager.add_child(view_parent)
	add_child_autofree(manager)
	var root_model := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var nested_model := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	var root_presentation := manager._spawn_presentation_view(
		_non_card_view_scene(false),
		view_parent,
		root_model,
	)
	var nested_presentation := manager._spawn_presentation_view(
		_non_card_view_scene(true),
		view_parent,
		nested_model,
	)

	assert_not_null(root_presentation)
	assert_not_null(nested_presentation)
	assert_same(root_presentation.combatant, root_model)
	assert_same(nested_presentation.combatant, nested_model)
	assert_same(manager.presentation_for(root_model), root_presentation)
	assert_same(manager.presentation_for(nested_model), nested_presentation)
	assert_same(root_presentation.get_parent(), view_parent)
	assert_true(nested_presentation.get_parent().get_parent() == view_parent)
	assert_true(nested_presentation.get_parent() is Node3D)
	assert_false(nested_presentation.get_parent().has_method(&"setup_from_combatant"))
	assert_false(nested_presentation.get_parent().has_signal(&"spawn_particles"))

	root_presentation.queue_free()
	nested_presentation.get_parent().queue_free()
	await get_tree().process_frame
	assert_null(manager.presentation_for(root_model))
	assert_null(manager.presentation_for(nested_model))
	assert_true(manager._presentation_exit_callbacks.is_empty())


func test_presentation_events_follow_registry_replacement_and_teardown_once() -> void:
	var manager := TestBattleManager.new()
	var model := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	var first := CombatantPresentation.new()
	var replacement := CombatantPresentation.new()
	manager.add_child(first)
	manager.add_child(replacement)
	add_child_autofree(manager)
	first.bind(model)
	replacement.bind(model)

	manager.register_presentation(model, first)
	manager.register_presentation(model, first)
	first.particles_requested.emit(Vector2(10, 20), "first")
	manager.register_presentation(model, replacement)
	first.particles_requested.emit(Vector2(30, 40), "stale")
	replacement.particles_requested.emit(Vector2(50, 60), "replacement")
	manager.unregister_presentation(model)
	replacement.particles_requested.emit(Vector2(70, 80), "detached")

	assert_eq(manager.particle_requests, [
		{"position": Vector2(10, 20), "type": "first"},
		{"position": Vector2(50, 60), "type": "replacement"},
	])


func test_card_adapter_forwards_particles_through_presentation_contract() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var model := _combatant()
	card.bind_combatant(model)
	watch_signals(card.presentation)

	card.spawn_particles.emit(Vector2(12, 34), "gunshot")

	assert_signal_emitted_with_parameters(
		card.presentation,
		"particles_requested",
		[Vector2(12, 34), "gunshot"],
	)


func test_cards_expose_only_bound_identity_and_presentation_behavior() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var properties := card.get_property_list().map(
		func(property: Dictionary): return property.name,
	)
	for state_name: StringName in [
		&"actor_name", &"current_stats", &"current_hp", &"current_guard",
		&"current_ct", &"ct_speed_scale", &"battle_priority",
		&"is_valid_target", &"is_breached", &"is_in_danger",
		&"is_defeated", &"active_conditions", &"active_traits",
		&"hero_data", &"loaded_roles", &"current_role_index",
		&"current_focus", &"shifted_this_turn",
	]:
		assert_does_not_have(properties, state_name)
	for method_name: StringName in [
		&"take_one_hit", &"modify_guard", &"add_condition", &"shift_role",
		&"modify_focus", &"get_current_role", &"get_scaled_focus_cost",
	]:
		assert_false(card.has_method(method_name), str(method_name))
	assert_true(card.has_method(&"bind_combatant"))
	assert_true(card.has_method(&"set_target_presentation"))


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
	assert_eq(combatant.current_hp, 40)


func test_stat_modifier_dictionaries_belong_only_to_hero_combatant() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var model := _combatant() as HeroCombatant
	var card_properties := card.get_property_list().map(
		func(property: Dictionary): return property.name,
	)
	var model_properties := model.get_property_list().map(
		func(property: Dictionary): return property.name,
	)

	assert_does_not_have(card_properties, &"stat_mods")
	assert_does_not_have(card_properties, &"stat_scalars")
	assert_has(model_properties, &"stat_mods")
	assert_has(model_properties, &"stat_scalars")


func test_bound_hero_renders_one_model_focus_change() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var model := _combatant() as HeroCombatant
	model.hero_data = HeroData.new()
	model.hero_data.stats = model.current_stats
	model.current_focus = 5
	await card.setup_from_combatant(model)
	await model.modify_focus(-2, {"paid_focus_cost": 2})
	await get_tree().create_timer(0.25).timeout

	assert_eq(model.current_focus, 3)
	assert_eq(card.focus_bar.get_children().filter(
		func(pip: Control): return pip.visible
	).size(), 3)


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
	card.bind_combatant(combatant)

	assert_eq(card.breached_label.text, "BREACHED")
	assert_eq(card.guard_bar.modulate.a, 0.25)
	assert_null(card.shake_tween)


func test_binding_already_defeated_hero_renders_final_state_without_signal() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()
	combatant.is_breached = true
	combatant.is_defeated = true
	card.bind_combatant(combatant)

	assert_eq(card.self_modulate.a, 0.25)
	assert_null(card.pulse_tween)
	assert_false(card.breached_label.visible)


func test_binding_defeated_combatant_with_retained_danger_skips_transients() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := _combatant()
	combatant.is_in_danger = true
	combatant.is_defeated = true
	card.bind_combatant(combatant)

	assert_eq(card.self_modulate.a, 0.25)
	assert_null(card.pulse_tween)
	assert_false(card.breached_label.visible)


func test_binding_already_defeated_enemy_renders_final_state_immediately() -> void:
	var card := EnemyCardScene.instantiate() as EnemyCard
	add_child_autofree(card)
	var combatant := _combatant(
		100, BattleCombatant.Faction.ENEMY,
	)
	combatant.is_defeated = true

	card.bind_combatant(combatant)

	assert_eq(card.modulate.a, 0.0)
