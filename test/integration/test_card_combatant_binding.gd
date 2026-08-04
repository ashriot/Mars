extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")
const BattleWorldScene := preload("res://src/battle/presentation/battle_world_3d.tscn")
const BattleSceneScene := preload("res://src/battle/battle_scene.tscn")


class TestBattleManager extends BattleManager:
	var particle_requests: Array[Dictionary] = []
	var projectile_requests: Array[Dictionary] = []

	func _ready() -> void:
		pass

	func _on_spawn_particles(pos: Vector2, type: String) -> void:
		particle_requests.append({"position": pos, "type": type})

	func _on_projectile_requested(
		from_screen: Vector2,
		to_screen: Vector2,
		effect_type: StringName,
	) -> void:
		projectile_requests.append({
			"from": from_screen,
			"to": to_screen,
			"effect": effect_type,
		})


class PassiveBattleManager extends BattleManager:
	func _ready() -> void:
		pass


class TrackingFXManager extends FXManager:
	var shake_requests: Array[float] = []

	func trigger_shake(intensity: float) -> void:
		shake_requests.append(intensity)
		super.trigger_shake(intensity)


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

	func _finalize_initial_ai_timing(_head_start_rolls: Array = []) -> void:
		pass

	func find_and_start_next_turn() -> void:
		turn_calls += 1


class TrackingCombatantPresentation extends CombatantPresentation:
	func setup_view(value: BattleCombatant) -> bool:
		value.set_meta(&"tracking_presentation_bound", true)
		return super.setup_view(value)


class NoOpSetupPresentation extends CombatantPresentation:
	func setup_view(_value: BattleCombatant) -> bool:
		return true


class ProjectedNode3DPresentation extends CombatantPresentation:
	func begin_pending_operation() -> PresentationOperation:
		return _begin_operation()

	func get_target_screen_position() -> Vector2:
		var root := get_parent() as Node3D
		return Vector2(root.position.x, root.position.z) \
			if is_instance_valid(root) else Vector2.ZERO

	func is_target_visible() -> bool:
		return true


class FailAfterFirstNode3DPresentation extends ProjectedNode3DPresentation:
	static var setup_calls := 0

	func setup_view(value: BattleCombatant) -> bool:
		setup_calls += 1
		if setup_calls > 1:
			return false
		return super.setup_view(value)


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


func _projected_node_3d_view_scene(fail_after_first := false) -> PackedScene:
	var scene := PackedScene.new()
	var view_root := Node3D.new()
	view_root.name = "ProjectedEnemyView"
	var presentation: CombatantPresentation = FailAfterFirstNode3DPresentation.new() \
		if fail_after_first else ProjectedNode3DPresentation.new()
	presentation.name = "CombatantPresentation"
	view_root.add_child(presentation)
	presentation.owner = view_root
	assert_eq(scene.pack(view_root), OK)
	view_root.free()
	return scene


func _spawn_manager_with_world(
	enemy_view_scene: PackedScene,
	layout := BattleFormationLayout.Layout.W,
) -> Dictionary:
	var manager := SpawnFailureBattleManager.new()
	manager.combatant_root = Node.new()
	manager.hero_area = Control.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	manager.add_child(manager.combatant_root)
	manager.add_child(manager.hero_area)
	manager.add_child(world)
	manager.battle_world = world
	manager.hero_view_scene = _non_card_view_scene(false)
	manager.enemy_view_scene = enemy_view_scene
	manager.current_encounter = Encounter.new()
	manager.current_encounter.enemy_formation = layout
	add_child_autofree(manager)
	return {manager = manager, world = world}


func _five_unique_enemies() -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	for index in 5:
		var enemy := EnemyData.new()
		enemy.enemy_id = "projected_enemy_%d" % index
		enemy.enemy_name = "Projected Enemy %d" % index
		enemies.append(enemy)
	return enemies


func _assert_world_spawn(
	layout: BattleFormationLayout.Layout,
	expected_positions: Array[Vector3],
	encounter_is_boss := false,
) -> void:
	var fixture := _spawn_manager_with_world(_projected_node_3d_view_scene(), layout)
	var manager := fixture.manager as SpawnFailureBattleManager
	var world := fixture.world as BattleWorld3D
	manager.current_encounter.enemies = _five_unique_enemies()
	manager.current_encounter.is_boss = encounter_is_boss

	await manager.spawn_encounter([], 3, 41, false)

	assert_eq(manager.actor_list.size(), 5)
	assert_eq(world.enemy_views.get_child_count(), 5)
	for index in 5:
		var enemy := manager.actor_list[index] as EnemyCombatant
		var presentation := manager.presentation_for(enemy) \
			as ProjectedNode3DPresentation
		var view_root := manager.presentation_view_root_for(enemy)
		assert_not_null(presentation)
		assert_not_null(view_root)
		assert_same(view_root.get_parent(), world.enemy_views)
		assert_eq((view_root as Node3D).position, expected_positions[index])
		assert_same(presentation.combatant, enemy)
		assert_eq(
			presentation.get_target_screen_position(),
			Vector2(expected_positions[index].x, expected_positions[index].z),
		)


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


func test_nested_presentation_registry_preserves_exact_view_root() -> void:
	var manager := TestBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	manager.add_child(world)
	add_child_autofree(manager)
	var enemy := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	var presentation := manager._spawn_presentation_view(
		_projected_node_3d_view_scene(),
		world.enemy_views,
		enemy,
	)
	var view_root := manager.presentation_view_root_for(enemy)

	assert_not_null(presentation)
	assert_not_null(view_root)
	assert_same(view_root.get_parent(), world.enemy_views)
	assert_same(presentation.get_parent(), view_root)
	manager.unregister_presentation(enemy)
	assert_null(manager.presentation_view_root_for(enemy))
	assert_true(
		is_instance_valid(view_root),
		"unregister detaches registry but caller owns free",
	)
	assert_same(world.enemy_views.get_parent(), world)
	view_root.free()


func test_spawned_presentation_replacement_tracks_only_the_new_exact_root() -> void:
	var manager := TestBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	manager.add_child(world)
	add_child_autofree(manager)
	var enemy := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	var scene := _projected_node_3d_view_scene()

	var first := manager._spawn_presentation_view(scene, world.enemy_views, enemy)
	var first_root := manager.presentation_view_root_for(enemy)
	var replacement := manager._spawn_presentation_view(scene, world.enemy_views, enemy)
	var replacement_root := manager.presentation_view_root_for(enemy)

	assert_not_null(first)
	assert_not_null(replacement)
	assert_ne(first, replacement)
	assert_ne(first_root, replacement_root)
	assert_same(replacement_root.get_parent(), world.enemy_views)
	assert_true(is_instance_valid(first_root), "replaced roots remain caller-owned")
	manager.unregister_presentation(enemy)
	assert_null(manager.presentation_view_root_for(enemy))
	assert_true(is_instance_valid(first_root))
	assert_true(is_instance_valid(replacement_root))
	first_root.free()
	replacement_root.free()


func test_spawned_replacement_publishes_presentation_and_root_before_cancellation() -> void:
	var manager := TestBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	manager.add_child(world)
	add_child_autofree(manager)
	var enemy := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	var scene := _projected_node_3d_view_scene()
	var first := manager._spawn_presentation_view(
		scene, world.enemy_views, enemy,
	) as ProjectedNode3DPresentation
	var operation := first.begin_pending_operation()
	var observed_presentation: Array[CombatantPresentation] = []
	var observed_root: Array[Node] = []
	operation.completed.connect(
		func() -> void:
			observed_presentation.append(manager.presentation_for(enemy))
			observed_root.append(manager.presentation_view_root_for(enemy))
	)

	var replacement := manager._spawn_presentation_view(
		scene, world.enemy_views, enemy,
	)
	var replacement_root := manager.presentation_view_root_for(enemy)

	assert_true(operation.is_completed)
	assert_eq(observed_presentation.size(), 1)
	assert_eq(observed_root.size(), 1)
	assert_same(observed_presentation[0], replacement)
	assert_same(observed_root[0], replacement_root)
	assert_ne(observed_root[0], first.get_parent())


func test_failed_later_enemy_view_rolls_back_only_exact_spawn_roots() -> void:
	FailAfterFirstNode3DPresentation.setup_calls = 0
	var fixture := _spawn_manager_with_world(
		_projected_node_3d_view_scene(true),
	)
	var manager := fixture.manager as SpawnFailureBattleManager
	var world := fixture.world as BattleWorld3D
	var formation_anchor := Marker3D.new()
	formation_anchor.name = "FormationAnchor"
	world.enemy_views.add_child(formation_anchor)
	manager.current_encounter.enemies = _five_unique_enemies().slice(0, 2)

	await manager.spawn_encounter([], 2, 19, false)

	assert_true(manager.actor_list.is_empty())
	assert_eq(manager.combatant_root.get_child_count(), 0)
	assert_true(is_instance_valid(world))
	assert_same(world.enemy_views.get_parent(), world)
	assert_true(is_instance_valid(formation_anchor))
	assert_same(formation_anchor.get_parent(), world.enemy_views)
	assert_eq(world.enemy_views.get_children(), [formation_anchor])
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_view_roots.is_empty())
	assert_eq(manager.fade_calls, 0)


func test_spawn_encounter_places_five_enemy_view_roots_in_w_layout() -> void:
	await _assert_world_spawn(BattleFormationLayout.Layout.W, [
		Vector3(-5.00, 0.0, -0.21),
		Vector3(0.0, 0.0, -0.61),
		Vector3(5.00, 0.0, -0.21),
		Vector3(-1.44, 0.0, 3.80),
		Vector3(1.44, 0.0, 3.80),
	])


func test_boss_flagged_encounter_still_places_five_enemy_roots_in_ordinary_m_layout() -> void:
	await _assert_world_spawn(BattleFormationLayout.Layout.M, [
		Vector3(-2.70, 0.0, -0.71),
		Vector3(2.70, 0.0, -0.71),
		Vector3(-3.17, 0.0, 3.30),
		Vector3(0.0, 0.0, 3.70),
		Vector3(3.17, 0.0, 3.30),
	], true)


func test_spawn_encounter_rejects_a_runtime_hidden_battle_world() -> void:
	var fixture := _spawn_manager_with_world(_projected_node_3d_view_scene())
	var manager := fixture.manager as SpawnFailureBattleManager
	var world := fixture.world as BattleWorld3D
	manager.current_encounter.enemies = _five_unique_enemies().slice(0, 1)
	world.hide()

	await manager.spawn_encounter([], 3, 41, false)

	assert_push_error("active BattleWorld3D")
	assert_true(manager.actor_list.is_empty())
	assert_eq(manager.combatant_root.get_child_count(), 0)
	assert_eq(world.enemy_views.get_child_count(), 0)
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_view_roots.is_empty())
	assert_eq(manager.fade_calls, 0)


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


func test_direct_presentation_rebind_preserves_first_identity_and_registry() -> void:
	var manager := TestBattleManager.new()
	var presentation := CombatantPresentation.new()
	manager.add_child(presentation)
	add_child_autofree(manager)
	var first := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var second := _combatant(100, BattleCombatant.Faction.ENEMY, manager)

	assert_true(presentation.bind(first))
	assert_true(manager.register_presentation(first, presentation))
	assert_false(presentation.bind(second))

	assert_push_error("cannot be rebound")
	assert_same(presentation.combatant, first)
	assert_same(manager.presentation_for(first), presentation)
	assert_null(manager.presentation_for(second))
	assert_eq(manager._presentations.size(), 1)


func test_direct_presentation_bind_rejects_invalid_identity() -> void:
	var presentation := CombatantPresentation.new()
	autofree(presentation)

	assert_false(presentation.bind(null))

	assert_push_error("requires a valid BattleCombatant")
	assert_null(presentation.combatant)


func test_failed_card_bind_preserves_registered_presentation_identity() -> void:
	var manager := TestBattleManager.new()
	var card := HeroCardScene.instantiate() as HeroCard
	card.battle_manager = manager
	manager.add_child(card)
	add_child_autofree(manager)
	await get_tree().process_frame
	var first := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var second := _combatant(100, BattleCombatant.Faction.HERO, manager)

	assert_true(card.presentation.bind(first))
	assert_true(manager.register_presentation(first, card.presentation))
	assert_false(card.bind_combatant(second))
	assert_push_error("cannot be rebound")
	assert_false(manager.register_presentation(second, card.presentation))
	assert_push_error("already registered to another combatant")

	assert_null(card.combatant, "failed presentation binding cannot partially bind the card")
	assert_same(card.presentation.combatant, first)
	assert_same(manager.presentation_for(first), card.presentation)
	assert_null(manager.presentation_for(second))
	assert_false(
		second.hp_changed.is_connected(card._on_combatant_hp_changed),
		"failed card binding cannot wire model signals",
	)


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


func test_card_setup_rejects_second_same_model_without_duplicate_wiring() -> void:
	var manager := TestBattleManager.new()
	var card := HeroCardScene.instantiate() as HeroCard
	card.battle_manager = manager
	manager.add_child(card)
	add_child_autofree(manager)
	await get_tree().process_frame
	var model := _combatant(100, BattleCombatant.Faction.HERO, manager) \
		as HeroCombatant
	model.hero_data = HeroData.new()
	model.hero_data.stats = model.current_stats

	assert_true(card.presentation.setup_view(model))
	await get_tree().process_frame
	await get_tree().process_frame
	var hp_connection_count := model.hp_changed.get_connections().size()
	var focus_connection_count := model.focus_changed.get_connections().size()

	assert_false(card.presentation.setup_view(model))

	assert_push_error("already bound")
	assert_same(card.combatant, model)
	assert_same(card.presentation.combatant, model)
	assert_eq(model.hp_changed.get_connections().size(), hp_connection_count)
	assert_eq(model.focus_changed.get_connections().size(), focus_connection_count)


func test_spawn_encounter_aborts_and_discards_model_when_view_is_invalid() -> void:
	var manager := SpawnFailureBattleManager.new()
	manager.combatant_root = Node.new()
	manager.hero_area = Node3D.new()
	manager.enemy_area = Node3D.new()
	manager.battle_world = BattleWorldScene.instantiate() as BattleWorld3D
	manager.add_child(manager.combatant_root)
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.add_child(manager.battle_world)
	manager.hero_view_scene = _non_card_view_scene(false)
	manager.enemy_view_scene = _view_scene_with_presentation_count(0)
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
	assert_eq(manager.battle_world.enemy_views.get_child_count(), 0)
	assert_true(manager._combatant_exit_callbacks.is_empty())
	assert_true(manager._presentations.is_empty())
	assert_true(manager._presentation_view_roots.is_empty())
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


func test_projectile_requests_follow_registry_replacement_and_teardown_once() -> void:
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
	first.projectile_requested.emit(Vector2(10, 20), Vector2(30, 40), &"laser")
	manager.register_presentation(model, replacement)
	first.projectile_requested.emit(Vector2.ZERO, Vector2.ONE, &"stale")
	replacement.projectile_requested.emit(
		Vector2(50, 60), Vector2(70, 80), &"laser",
	)
	manager.unregister_presentation(model)
	replacement.projectile_requested.emit(Vector2.ONE, Vector2.ZERO, &"detached")

	assert_eq(manager.projectile_requests, [
		{"from": Vector2(10, 20), "to": Vector2(30, 40), "effect": &"laser"},
		{"from": Vector2(50, 60), "to": Vector2(70, 80), "effect": &"laser"},
	])


func test_projectile_request_forwards_exact_screen_positions_only_to_active_world() -> void:
	var manager := PassiveBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	add_child_autofree(world)
	add_child_autofree(manager)
	manager.battle_world = world

	manager._on_projectile_requested(
		Vector2(123, 234), Vector2(765, 876), &"laser",
	)

	assert_eq(world.projectile_layer.active_lasers.size(), 1)
	if world.projectile_layer.active_lasers.is_empty():
		return
	assert_eq(
		world.projectile_layer.active_lasers[0].points,
		PackedVector2Array([Vector2(123, 234), Vector2(765, 876)]),
	)
	world.hide()
	manager._on_projectile_requested(Vector2.ZERO, Vector2.ONE, &"laser")
	assert_eq(world.projectile_layer.active_lasers.size(), 1)


func test_manager_wires_camera_rig_and_shakes_only_for_hero_impacts() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	var manager := TestBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	var effects := FXManager.new()
	add_child_autofree(world)
	add_child_autofree(effects)
	add_child_autofree(manager)
	manager.battle_world = world
	manager.fx_manager = effects
	manager._configure_battle_feedback()
	var hero := _combatant(100, BattleCombatant.Faction.HERO, manager)
	var enemy := _combatant(100, BattleCombatant.Faction.ENEMY, manager)
	manager._connect_combatant_signals(hero)
	manager._connect_combatant_signals(enemy)

	assert_same(effects.camera_rig, world.camera_rig)
	enemy.presentation_event.emit(enemy, &"impact", {"intensity": 0.9})
	assert_eq(world.camera_rig.trauma, 0.0)
	hero.presentation_event.emit(hero, &"impact", {"intensity": 0.7})
	assert_eq(world.camera_rig.trauma, 0.7)
	manager.free()
	assert_null(effects.camera_rig)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_packed_battle_scene_wires_world_camera_rig_during_ready() -> void:
	var battle_scene := BattleSceneScene.instantiate() as BattleScene
	add_child_autofree(battle_scene)
	var manager := battle_scene.manager

	assert_not_null(manager.battle_world.camera_rig)
	assert_same(manager.fx_manager.camera_rig, manager.battle_world.camera_rig)


func test_card_shake_setting_zero_is_a_true_no_op() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(0.0, false)
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var home_position := card.position
	var visual_home := card.panel.position

	card.shake_panel(1.0)

	assert_null(card.shake_tween)
	assert_eq(card.position, home_position)
	assert_eq(card.panel.position, visual_home)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_partial_shake_setting_scales_the_whole_requested_displacement() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	var full_card := HeroCardScene.instantiate() as HeroCard
	var partial_card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(full_card)
	add_child_autofree(partial_card)
	var full_home := full_card.panel.position
	var partial_home := partial_card.panel.position
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	full_card.shake_panel(1.0)
	full_card.shake_tween.custom_step(0.025)
	var full_displacement := full_card.panel.position.y - full_home.y
	CombatPresentationSettings.set_shake_intensity(0.1, false)
	partial_card.shake_panel(1.0)
	partial_card.shake_tween.custom_step(0.025)
	var partial_displacement := partial_card.panel.position.y - partial_home.y

	assert_gt(full_displacement, 0.0)
	assert_almost_eq(partial_displacement, full_displacement * 0.1, 0.001)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_card_shake_moves_only_inner_visuals_at_intermediate_frame() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.position = Vector2(90, 40)
	card.size = Vector2(400, 180)
	await get_tree().process_frame
	var input_surface := card.get_node_or_null("InputSurface") as Control
	assert_not_null(input_surface)
	if input_surface == null:
		CombatPresentationSettings.set_shake_intensity(saved_intensity, false)
		return
	input_surface.grab_focus()
	var outer_rect := card.get_global_rect()
	var hit_rect := input_surface.get_global_rect()
	var visual_home := card.panel.global_position

	card.shake_panel(1.0)
	card.shake_tween.custom_step(0.025)

	assert_eq(card.get_global_rect(), outer_rect)
	assert_same(get_viewport().gui_get_focus_owner(), input_surface)
	assert_eq(input_surface.get_global_rect(), hit_rect)
	assert_ne(card.panel.global_position, visual_home)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_rapid_card_shake_retrigger_returns_inner_visual_to_neutral() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var outer_home := card.position
	var visual_home := card.panel.position

	card.shake_panel(1.0)
	card.shake_tween.custom_step(0.025)
	assert_ne(card.panel.position, visual_home)
	card.shake_panel(0.5)
	assert_eq(card.panel.position, visual_home)
	card.shake_tween.custom_step(1.0)

	assert_eq(card.position, outer_home)
	assert_eq(card.panel.position, visual_home)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_every_actor_card_variant_has_fixed_input_and_inner_visual_surfaces() -> void:
	for scene: PackedScene in [HeroCardScene, EnemyCardScene]:
		var card := scene.instantiate() as ActorCard
		add_child_autofree(card)
		var input_surface := card.get_node_or_null("InputSurface") as Control
		assert_not_null(input_surface)
		assert_not_null(card.panel)
		if input_surface != null:
			assert_eq(input_surface.mouse_filter, Control.MOUSE_FILTER_STOP)
			assert_eq(input_surface.get_global_rect(), card.get_global_rect())
		assert_eq(card.panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_breach_state_waits_for_unified_impact_before_shaking_panel() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	var manager := PassiveBattleManager.new()
	add_child_autofree(manager)
	manager.battle_speed = 1.0
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.battle_manager = manager
	var combatant := _combatant()
	card.bind_combatant(combatant)

	await combatant.breach()

	assert_null(card.shake_tween)
	combatant.presentation_event.emit(combatant, &"impact", {"intensity": 0.5})
	assert_not_null(card.shake_tween)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


func test_zero_guard_damage_drives_one_hero_panel_and_camera_impact() -> void:
	var saved_intensity := CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	var manager := PassiveBattleManager.new()
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	var effects := TrackingFXManager.new()
	manager.battle_world = world
	manager.fx_manager = effects
	manager.add_child(world)
	manager.add_child(effects)
	add_child_autofree(manager)
	manager._configure_battle_feedback()
	var attacker := _combatant(1000, BattleCombatant.Faction.ENEMY)
	attacker.current_stats.attack = 25
	var target := _combatant(1000, BattleCombatant.Faction.HERO)
	target.current_guard = 0
	manager._connect_combatant_signals(target)
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.battle_manager = manager
	card.bind_combatant(target)
	var impact_events: Array[Dictionary] = []
	target.presentation_event.connect(
		func(_actor: BattleCombatant, event: StringName, payload: Dictionary) -> void:
			if event == &"impact":
				impact_events.append(payload.duplicate(true))
	)
	var effect := Effect_Damage.new()
	effect.damage_type = Action.DamageType.KINETIC

	await effect.execute(attacker, [target], manager)

	assert_true(target.is_breached)
	assert_eq(impact_events, [{"intensity": 0.5}])
	assert_eq(effects.shake_requests, [0.5])
	assert_not_null(card.shake_tween)
	CombatPresentationSettings.set_shake_intensity(saved_intensity, false)


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
	card.hp_bar_ghost.hide()

	await combatant.take_one_hit(
		_damage_result(40), Effect_Damage.new(), combatant,
		Action.DamageType.KINETIC,
	)

	assert_eq(card.hp_bar_actual.value, 60.0)
	assert_eq(card.hp_bar_ghost.value, 100.0)
	assert_true(card.hp_bar_ghost.visible)
	var damage_feedback_style := card.hp_bar_ghost.get_theme_stylebox(&"fill")
	assert_is(damage_feedback_style, StyleBoxFlat)
	assert_eq(
		(damage_feedback_style as StyleBoxFlat).bg_color,
		Color(0.98, 0.76766664, 0.0, 1.0),
	)
	assert_eq(
		(card.hp_bar_ghost.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color,
		HealthFeedbackPalette.DAMAGE_YELLOW,
	)
	assert_null(card.shake_tween, "ordinary hits do not shake the actor card")
	var tween := card.sync_visual_health()
	assert_not_null(tween)
	if tween != null:
		await tween.finished
	assert_eq(card.hp_bar_actual.value, 60.0)
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
	card.hp_bar_ghost.hide()

	await combatant.take_healing(20)

	assert_eq(card.hp_bar_actual.value, 40.0)
	assert_eq(card.hp_bar_ghost.value, 60.0)
	assert_true(card.hp_bar_ghost.visible)
	var healing_feedback_style := card.hp_bar_ghost.get_theme_stylebox(&"fill")
	assert_is(healing_feedback_style, StyleBoxFlat)
	assert_eq(
		(healing_feedback_style as StyleBoxFlat).bg_color,
		Color(0.20, 0.90, 0.45, 1.0),
	)
	assert_eq(
		(card.hp_bar_ghost.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color,
		HealthFeedbackPalette.HEALING_GREEN,
	)
	var tween := card.sync_visual_health()
	assert_not_null(tween)
	if tween != null:
		await tween.finished
	assert_eq(card.hp_bar_actual.value, 60.0)
	assert_eq(card.hp_bar_ghost.value, 60.0)


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
