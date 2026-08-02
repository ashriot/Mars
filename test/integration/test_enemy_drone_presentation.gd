extends GutTest

const DRONE_SCENE := preload(
	"res://src/battle/presentation/enemy_drone_presentation.tscn",
)
const WORLD_SCENE := preload("res://src/battle/presentation/battle_world_3d.tscn")
const LOCAL_MODEL_PATH := (
	"res://assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf"
)
const MISSING_MODEL_PATH := (
	"res://assets/graphics/models/quaternius_local/enemies/eye_drone/missing.gltf"
)
const TRACKED_MODEL_PATH := "res://test/fixtures/presentation/optional_model_fixture.tscn"


class RegistryTrackingBattleManager extends BattleManager:
	func _ready() -> void:
		pass


func after_each() -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()


func test_scene_has_one_nested_presentation_and_string_only_model_path() -> void:
	var fixture := _drone_view(_world())
	var presentations: Array[CombatantPresentation] = []
	_collect_presentations(fixture.root, presentations)

	assert_eq(presentations.size(), 1)
	assert_same(presentations[0], fixture.presentation)
	assert_eq(fixture.presentation.model_loader.local_resource_path, LOCAL_MODEL_PATH)
	assert_true(fixture.presentation.model_loader.placeholder is MeshInstance3D)
	assert_true(fixture.presentation.model_loader.using_placeholder)


func test_drone_view_binds_enemy_and_adds_one_hud_to_world_layer() -> void:
	var world_fixture := _world()
	var fixture := _drone_view(world_fixture)
	var enemy := _enemy()

	assert_true(fixture.presentation.setup_view(enemy))
	assert_same(fixture.presentation.combatant, enemy)
	assert_eq(world_fixture.world.hud_layer.get_child_count(), 1)
	assert_same(fixture.presentation.hud.combatant, enemy)
	assert_eq(fixture.presentation.model_loader.model_loaded.get_connections().size(), 1)
	assert_eq(fixture.presentation.model_loader.model_unavailable.get_connections().size(), 1)
	assert_false(
		fixture.presentation.hud.visible,
		"a HUD remains hidden until its first valid projection",
	)


func test_two_drones_do_not_share_material_or_animation_state() -> void:
	var first := _bound_animated_drone(_world(), _enemy())
	var second := _bound_animated_drone(_world(), _enemy())

	assert_not_null(first.presentation.instance_material)
	assert_not_null(second.presentation.instance_material)
	assert_not_null(first.presentation.animation_player)
	assert_not_null(second.presentation.animation_player)
	first.presentation.set_instance_tint(Color.CYAN)
	first.presentation.set_acting(true)

	assert_ne(first.presentation.instance_material, second.presentation.instance_material)
	assert_ne(
		first.presentation.instance_material.albedo_color,
		second.presentation.instance_material.albedo_color,
	)
	assert_ne(first.presentation.animation_player, second.presentation.animation_player)
	assert_eq(first.presentation.animation_player.current_animation, "Charging")
	assert_eq(second.presentation.animation_player.current_animation, "Idle")


func test_wrong_model_and_second_setup_are_rejected() -> void:
	var fixture := _drone_view(_world())
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	hero.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO)

	assert_false(fixture.presentation.setup_view(hero))
	assert_push_error("EnemyDronePresentation requires an EnemyCombatant.")
	var enemy := _enemy()
	assert_true(fixture.presentation.setup_view(enemy))
	var presentation_connection_count := enemy.presentation_event.get_connections().size()
	assert_false(fixture.presentation.setup_view(enemy))
	assert_push_error("CombatantPresentation cannot be rebound")
	assert_eq(
		enemy.presentation_event.get_connections().size(),
		presentation_connection_count,
		"rejected setup cannot duplicate model event wiring",
	)


func test_post_bind_dependency_failure_leaves_no_partial_hud_or_model() -> void:
	var root := DRONE_SCENE.instantiate() as Node3D
	add_child_autofree(root)
	var presentation := root.get_node("CombatantPresentation") as EnemyDronePresentation
	var enemy := _enemy()

	assert_false(presentation.setup_view(enemy))
	assert_push_error("requires a battle camera and HUD layer")
	assert_same(presentation.combatant, enemy, "immutable binding remains observable")
	assert_null(presentation.hud)
	assert_null(presentation.model_loader.loaded_model)
	assert_false(enemy.presentation_event.is_connected(presentation._on_presentation_event))


func test_target_state_acting_and_hud_input_are_forwarded() -> void:
	var fixture := _bound_drone(_world(), _enemy())
	watch_signals(fixture.presentation)

	fixture.presentation.set_target_presentation(
		CombatantPresentation.TargetState.SELECTED,
	)
	fixture.presentation.set_acting(true)
	fixture.presentation.hud.hovered.emit()
	fixture.presentation.hud.unhovered.emit()
	fixture.presentation.hud.pressed.emit()

	assert_eq(
		fixture.presentation.hud.target_state,
		CombatantPresentation.TargetState.SELECTED,
	)
	assert_true(fixture.presentation.acting)
	assert_true(fixture.presentation.hud.details.visible)
	assert_signal_emitted_with_parameters(
		fixture.presentation, &"target_hovered", [fixture.presentation.combatant],
	)
	assert_signal_emitted_with_parameters(
		fixture.presentation, &"target_unhovered", [fixture.presentation.combatant],
	)
	assert_signal_emitted_with_parameters(
		fixture.presentation, &"target_pressed", [fixture.presentation.combatant],
	)


func test_acting_detail_visibility_is_independent_of_update_order() -> void:
	var fixture := _bound_drone(_world(), _enemy())
	for state: CombatantPresentation.TargetState in [
		CombatantPresentation.TargetState.NORMAL,
		CombatantPresentation.TargetState.AVAILABLE,
	]:
		fixture.presentation.set_acting(false)
		fixture.presentation.set_target_presentation(state)
		assert_false(fixture.presentation.hud.details.visible)

		fixture.presentation.set_acting(true)
		assert_true(
			fixture.presentation.hud.details.visible,
			"target state followed by acting shows details",
		)

		fixture.presentation.set_acting(false)
		fixture.presentation.set_acting(true)
		fixture.presentation.set_target_presentation(state)
		assert_true(
			fixture.presentation.hud.details.visible,
			"acting followed by target state keeps details visible",
		)


func test_projection_uses_active_transformed_camera_and_hides_behind_it() -> void:
	var world_fixture := _world()
	var fixture := _bound_drone(world_fixture, _enemy())
	var camera: Camera3D = world_fixture.world.camera
	assert_eq(world_fixture.viewport.size, Vector2i(1280, 800))
	assert_ne(camera.global_transform, Transform3D.IDENTITY)

	fixture.presentation._process(0.0)
	var expected_head := camera.unproject_position(
		fixture.presentation.head_anchor.global_position,
	)
	var expected_foot := camera.unproject_position(
		fixture.presentation.foot_anchor.global_position,
	)
	assert_eq(fixture.presentation.get_target_screen_position(), expected_head)
	assert_true(fixture.presentation.is_target_visible())
	assert_eq(
		fixture.presentation.hud.get_target_rect(),
		Rect2(
			Vector2(expected_head.x - 48.0, minf(expected_head.y, expected_foot.y) - 18.0),
			Vector2(96.0, absf(expected_head.y - expected_foot.y) + 36.0),
		),
	)

	fixture.root.global_position = camera.global_position + camera.global_basis.z * 2.0
	assert_true(camera.is_position_behind(fixture.presentation.head_anchor.global_position))
	fixture.presentation._process(0.0)

	assert_false(fixture.presentation.is_target_visible())
	assert_false(fixture.presentation.hud.visible)
	assert_eq(
		fixture.presentation.hud.target_region.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
	)


func test_already_defeated_setup_never_exposes_a_stale_hud() -> void:
	var world_fixture := _world()
	var fixture := _drone_view(world_fixture)
	var enemy := _enemy()
	enemy.defeat()

	assert_true(fixture.presentation.setup_view(enemy))
	assert_not_null(fixture.presentation.hud)
	assert_false(fixture.presentation.hud.visible)
	assert_false(fixture.presentation.is_target_visible())
	assert_eq(
		fixture.presentation.hud.target_region.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
	)


func test_freeing_view_removes_its_externally_owned_hud() -> void:
	var world_fixture := _world()
	var fixture := _bound_drone(world_fixture, _enemy())
	var hud: EnemyWorldHUD = fixture.presentation.hud
	assert_eq(world_fixture.world.hud_layer.get_child_count(), 1)

	fixture.root.free()

	assert_false(is_instance_valid(hud))
	assert_eq(world_fixture.world.hud_layer.get_child_count(), 0)


func test_tracked_model_routes_animations_and_visible_defeat_fade() -> void:
	var fixture := _bound_animated_drone(_world(), _enemy())
	var player: AnimationPlayer = fixture.presentation.animation_player
	assert_not_null(player)
	for animation_name: StringName in [&"Idle", &"Attack", &"Hit", &"Charging"]:
		assert_true(player.has_animation(animation_name), str(animation_name))

	fixture.presentation.set_acting(true)
	assert_eq(player.current_animation, "Charging")
	fixture.presentation.show_action("Burst")
	assert_eq(player.current_animation, "Attack")
	var action_operation: PresentationOperation = fixture.presentation.hide_action()
	assert_false(action_operation.is_completed)

	fixture.presentation.combatant.presentation_event.emit(
		fixture.presentation.combatant, &"damage_received", {},
	)
	assert_true(action_operation.is_completed, "Hit replaces and completes Attack")
	assert_eq(player.current_animation, "Hit")
	var hit_operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(hit_operation.is_completed)
	player.animation_finished.emit(&"Hit")
	assert_true(hit_operation.is_completed)
	assert_eq(player.current_animation, "Idle")

	fixture.presentation._process(0.0)
	assert_true(fixture.presentation.hud.visible)
	fixture.presentation.combatant.defeat()
	var shutdown_operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(shutdown_operation.is_completed)
	assert_true(
		fixture.presentation.hud.visible,
		"defeat keeps the non-interactive HUD renderable during its fade",
	)
	assert_eq(
		fixture.presentation.hud.target_region.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
	)
	assert_not_null(fixture.presentation._fade_tween)
	fixture.presentation._fade_tween.custom_step(
		fixture.presentation.DEFEAT_FADE_DURATION * 0.5,
	)
	assert_true(fixture.presentation.hud.visible)
	assert_between(fixture.presentation.hud.modulate.a, 0.01, 0.99)
	assert_between(fixture.presentation.instance_material.albedo_color.a, 0.01, 0.99)
	fixture.presentation._fade_tween.custom_step(
		fixture.presentation.DEFEAT_FADE_DURATION,
	)
	assert_true(shutdown_operation.is_completed)
	assert_true(is_instance_valid(fixture.root), "fade leaves teardown ownership to encounter")
	assert_false(fixture.root.visible)
	assert_false(fixture.presentation.hud.visible)
	assert_eq(fixture.presentation.hud.modulate.a, 0.0)
	assert_eq(fixture.presentation.instance_material.albedo_color.a, 0.0)


func test_local_eye_drone_smoke_when_installed() -> void:
	if not ResourceLoader.exists(LOCAL_MODEL_PATH):
		pass_test("optional local EyeDrone is not installed")
		return
	var fixture := _bound_drone(_world(), _enemy())

	assert_false(fixture.presentation.model_loader.using_placeholder)
	assert_not_null(fixture.presentation.instance_material)
	assert_not_null(fixture.presentation.animation_player)
	for animation_name: StringName in [&"Idle", &"Attack", &"Hit", &"Charging"]:
		assert_true(fixture.presentation.animation_player.has_animation(animation_name))


func test_forced_missing_model_keeps_placeholder_and_never_blocks_clips() -> void:
	var fixture := _drone_view(_world())
	fixture.presentation.model_loader.local_resource_path = MISSING_MODEL_PATH

	assert_true(fixture.presentation.setup_view(_enemy()))
	assert_true(fixture.presentation.model_loader.using_placeholder)
	assert_true(fixture.presentation.model_loader.placeholder.visible)
	assert_null(fixture.presentation.animation_player)
	assert_not_null(fixture.presentation.instance_material)
	var acting_operation: PresentationOperation = fixture.presentation.set_acting(true)
	fixture.presentation.show_action("Missing Attack")
	var action_operation: PresentationOperation = fixture.presentation.hide_action()
	fixture.presentation.combatant.presentation_event.emit(
		fixture.presentation.combatant, &"damage_received", {},
	)
	var hit_operation: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_true(acting_operation.is_completed)
	assert_true(action_operation.is_completed)
	assert_true(hit_operation.is_completed)
	var placeholder := fixture.presentation.model_loader.placeholder as MeshInstance3D
	assert_same(placeholder.mesh.surface_get_material(0), fixture.presentation.instance_material)
	assert_null(placeholder.get_surface_override_material(0))
	fixture.root.free()


func test_manager_free_completes_pending_attack_after_unregistration_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	fixture.presentation.show_action("Burst")
	var operation: PresentationOperation = fixture.presentation.hide_action()
	assert_false(operation.is_completed)
	var registry_was_clear_on_completion := [false]
	var completion_count := [0]
	operation.completed.connect(
		func() -> void:
			completion_count[0] += 1
			registry_was_clear_on_completion[0] = manager.presentation_for(enemy) == null
	)

	fixture.root.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(operation.is_completed)
	assert_eq(completion_count[0], 1)
	assert_true(registry_was_clear_on_completion[0])
	assert_null(manager.presentation_for(enemy))


func test_manager_replacement_completes_pending_hit_after_registry_switch_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	fixture.presentation.combatant.presentation_event.emit(
		fixture.presentation.combatant, &"damage_received", {},
	)
	var operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(operation.is_completed)
	var replacement := CombatantPresentation.new()
	replacement.bind(enemy)
	manager.add_child(replacement)
	var registry_was_replaced_on_completion := [false]
	var completion_count := [0]
	operation.completed.connect(
		func() -> void:
			completion_count[0] += 1
			registry_was_replaced_on_completion[0] = (
				manager.presentation_for(enemy) == replacement
			)
	)

	assert_true(manager.register_presentation(enemy, replacement))

	assert_true(operation.is_completed)
	assert_eq(completion_count[0], 1)
	assert_true(registry_was_replaced_on_completion[0])
	assert_same(manager.presentation_for(enemy), replacement)
	assert_true(is_instance_valid(fixture.root))


func test_manager_unregister_completes_pending_shutdown_after_registry_clear_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	fixture.presentation._process(0.0)
	enemy.defeat()
	var operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(operation.is_completed)
	var registry_was_clear_on_completion := [false]
	var completion_count := [0]
	operation.completed.connect(
		func() -> void:
			completion_count[0] += 1
			registry_was_clear_on_completion[0] = manager.presentation_for(enemy) == null
	)

	manager.unregister_presentation(enemy)

	assert_true(operation.is_completed)
	assert_eq(completion_count[0], 1)
	assert_true(registry_was_clear_on_completion[0])
	assert_null(manager.presentation_for(enemy))
	assert_true(is_instance_valid(fixture.root))


func _world() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	viewport.add_child(world)
	return {"viewport": viewport, "world": world}


func _drone_view(world_fixture: Dictionary) -> Dictionary:
	var root := DRONE_SCENE.instantiate() as Node3D
	(world_fixture.world as BattleWorld3D).enemy_views.add_child(root)
	return {
		"root": root,
		"presentation": root.get_node("CombatantPresentation") as EnemyDronePresentation,
	}


func _bound_drone(world_fixture: Dictionary, enemy: EnemyCombatant) -> Dictionary:
	var fixture := _drone_view(world_fixture)
	assert_true(fixture.presentation.setup_view(enemy))
	return fixture


func _bound_animated_drone(
	world_fixture: Dictionary,
	enemy: EnemyCombatant,
) -> Dictionary:
	var fixture := _drone_view(world_fixture)
	fixture.presentation.model_loader.local_resource_path = TRACKED_MODEL_PATH
	fixture.presentation.model_loader.model_loaded.connect(
		_populate_animated_model, CONNECT_ONE_SHOT,
	)
	assert_true(fixture.presentation.setup_view(enemy))
	return fixture


func _populate_animated_model(model_root: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.25, 0.35)
	var mesh := SphereMesh.new()
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	model_root.add_child(mesh_instance)

	var library := AnimationLibrary.new()
	for animation_name: StringName in [&"Idle", &"Attack", &"Hit", &"Charging"]:
		var animation := Animation.new()
		animation.length = 60.0
		library.add_animation(animation_name, animation)
	var player := AnimationPlayer.new()
	player.add_animation_library(&"", library)
	model_root.add_child(player)


func _enemy() -> EnemyCombatant:
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	var stats := ActorStats.new()
	stats.actor_name = "Eye Drone"
	stats.max_hp = 100
	stats.kinetic_defense = 20
	stats.energy_defense = 35
	enemy.setup_base(stats, BattleCombatant.Faction.ENEMY)
	return enemy


func _collect_presentations(
	node: Node,
	result: Array[CombatantPresentation],
) -> void:
	if node is CombatantPresentation:
		result.append(node as CombatantPresentation)
	for child: Node in node.get_children():
		_collect_presentations(child, result)
