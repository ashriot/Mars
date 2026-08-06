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

var _saved_input_mode: InputManager.InputMode
var _saved_presentation_mode: InputManager.PresentationMode
var _saved_consumed_mouse_button: MouseButton
var _saved_mouse_mode: Input.MouseMode


class RegistryTrackingBattleManager extends BattleManager:
	func _ready() -> void:
		pass


class FixedTargetPresentation extends CombatantPresentation:
	var target_position := Vector2.ZERO
	var target_visible := true

	func get_target_screen_position() -> Vector2:
		return target_position

	func is_target_visible() -> bool:
		return target_visible


func before_each() -> void:
	_saved_input_mode = InputManager._active_mode
	_saved_presentation_mode = InputManager._presentation_mode
	_saved_consumed_mouse_button = InputManager._consumed_mouse_button
	_saved_mouse_mode = Input.mouse_mode


func after_each() -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()
	InputManager._set_active_mode(_saved_input_mode)
	InputManager._set_presentation_mode(_saved_presentation_mode)
	InputManager._consumed_mouse_button = _saved_consumed_mouse_button
	Input.mouse_mode = _saved_mouse_mode


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
	first.presentation.set_target_presentation(
		CombatantPresentation.TargetState.AVAILABLE,
	)
	assert_not_null(first.presentation.instance_material.next_pass)
	assert_null(second.presentation.instance_material.next_pass)


func test_binding_loops_idle_without_changing_transient_animation_loop_modes() -> void:
	var fixture := _bound_animated_drone(_world(), _enemy())
	var player: AnimationPlayer = fixture.presentation.animation_player

	assert_eq(player.get_animation(&"Idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation(&"Attack").loop_mode, Animation.LOOP_NONE)
	assert_eq(player.get_animation(&"Hit").loop_mode, Animation.LOOP_NONE)


func test_loaded_drone_material_is_tuned_for_readable_stage_lighting() -> void:
	var fixture := _bound_animated_drone(_world(), _enemy())

	assert_false(fixture.presentation._instance_materials.is_empty())
	for material: BaseMaterial3D in fixture.presentation._instance_materials:
		assert_almost_eq(material.metallic, 0.2, 0.0001)
		assert_almost_eq(material.roughness, 0.5, 0.0001)


func test_valid_target_outline_brightens_when_selected_and_clears_when_normal() -> void:
	var fixture := _bound_animated_drone(_world(), _enemy())
	var materials: Array[BaseMaterial3D] = fixture.presentation._instance_materials
	assert_false(materials.is_empty())
	for material: BaseMaterial3D in materials:
		assert_null(material.next_pass)

	fixture.presentation.set_target_presentation(
		CombatantPresentation.TargetState.AVAILABLE,
	)
	var available_outline := materials[0].next_pass as BaseMaterial3D
	assert_not_null(available_outline)
	assert_true(available_outline.grow)
	assert_eq(available_outline.cull_mode, BaseMaterial3D.CULL_FRONT)
	assert_eq(
		available_outline.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
	)
	assert_gt(available_outline.albedo_color.g, available_outline.albedo_color.r)
	assert_gt(available_outline.albedo_color.g, available_outline.albedo_color.b)
	var available_width := available_outline.grow_amount
	for material: BaseMaterial3D in materials:
		assert_same(material.next_pass, available_outline)

	fixture.presentation.set_target_presentation(
		CombatantPresentation.TargetState.SELECTED,
	)
	var selected_outline := materials[0].next_pass as BaseMaterial3D
	assert_same(selected_outline, available_outline)
	assert_gt(selected_outline.grow_amount, available_width)
	assert_gt(selected_outline.albedo_color.g, available_outline.albedo_color.r)

	fixture.presentation.set_target_presentation(
		CombatantPresentation.TargetState.NORMAL,
	)
	for material: BaseMaterial3D in materials:
		assert_null(material.next_pass)


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


func test_pointer_hover_reveals_only_its_own_details() -> void:
	var world_fixture := _world()
	var first := _bound_drone(world_fixture, _enemy())
	var second := _bound_drone(world_fixture, _enemy())
	first.presentation._process(0.0)
	second.presentation._process(0.0)

	first.presentation.hud.target_region.mouse_entered.emit()

	assert_true(first.presentation.hud.details.visible)
	assert_false(second.presentation.hud.details.visible)
	first.presentation.hud.target_region.mouse_exited.emit()
	assert_false(first.presentation.hud.details.visible)


func test_inspection_focus_controls_details_independently_of_target_highlight() -> void:
	var fixture := _bound_drone(_world(), _enemy())

	fixture.presentation.set_target_presentation(
		CombatantPresentation.TargetState.SELECTED,
	)
	assert_false(fixture.presentation.hud.details.visible)

	fixture.presentation.set_inspection_focused(true)
	assert_true(fixture.presentation.hud.details.visible)
	fixture.presentation.set_inspection_focused(false)
	assert_false(fixture.presentation.hud.details.visible)


func test_group_target_highlights_do_not_reveal_multiple_detail_blocks() -> void:
	var world_fixture := _world()
	var first := _bound_drone(world_fixture, _enemy())
	var second := _bound_drone(world_fixture, _enemy())

	first.presentation.set_target_presentation(
		CombatantPresentation.TargetState.SELECTED,
	)
	second.presentation.set_target_presentation(
		CombatantPresentation.TargetState.SELECTED,
	)

	assert_eq(first.presentation.target_state, CombatantPresentation.TargetState.SELECTED)
	assert_eq(second.presentation.target_state, CombatantPresentation.TargetState.SELECTED)
	assert_false(first.presentation.hud.details.visible)
	assert_false(second.presentation.hud.details.visible)


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
		_projected_proxy_rect(camera, fixture.presentation).grow(18.0),
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


func test_projected_target_contains_authored_proxy_at_depth_and_outer_positions() -> void:
	var world_fixture := _world()
	var fixture := _bound_drone(world_fixture, _enemy())
	var camera: Camera3D = world_fixture.world.camera
	var projected_widths: Array[float] = []
	for position: Vector3 in [
		Vector3(0.0, 0.0, -1.4),
		Vector3(0.0, 0.0, 4.0),
		Vector3(-3.6, 0.0, -1.0),
		Vector3(3.6, 0.0, 1.0),
	]:
		fixture.root.position = position
		fixture.presentation._process(0.0)
		world_fixture.world._layout_enemy_huds()
		var proxy_rect: Rect2 = _projected_proxy_rect(camera, fixture.presentation)
		var target_rect: Rect2 = fixture.presentation.hud.get_target_rect()
		projected_widths.append(proxy_rect.size.x)
		assert_true(target_rect.encloses(proxy_rect))
		assert_true(Rect2(24, 24, 1232, 752).encloses(target_rect))

	assert_gt(projected_widths[1], projected_widths[0])
	assert_gt(projected_widths[2], 96.0)
	assert_gt(projected_widths[3], 96.0)


func test_real_pointer_selects_at_projected_model_side_edge() -> void:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	InputManager._consumed_mouse_button = MOUSE_BUTTON_NONE
	var world_fixture := _world()
	var fixture := _bound_drone(world_fixture, _enemy())
	fixture.root.position = Vector3(0.0, 0.0, 4.0)
	fixture.presentation._process(0.0)
	world_fixture.world._layout_enemy_huds()
	var proxy_rect: Rect2 = _projected_proxy_rect(
		world_fixture.world.camera,
		fixture.presentation,
	)
	var side_edge := Vector2(proxy_rect.position.x + 1.0, proxy_rect.get_center().y)
	watch_signals(fixture.presentation)

	world_fixture.viewport.push_input(_mouse_motion_at(Vector2(12, 740)), true)
	await get_tree().process_frame
	world_fixture.viewport.push_input(_mouse_motion_at(side_edge), true)
	await get_tree().process_frame
	world_fixture.viewport.push_input(_mouse_button_at(side_edge, true), true)
	world_fixture.viewport.push_input(_mouse_button_at(side_edge, false), true)
	await get_tree().process_frame

	assert_signal_emitted_with_parameters(
		fixture.presentation,
		&"target_pressed",
		[fixture.presentation.combatant],
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
	var enemy: EnemyCombatant = fixture.presentation.combatant
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

	_stage_damage(enemy, 40)
	assert_true(action_operation.is_completed, "Hit replaces and completes Attack")
	assert_eq(player.current_animation, "Hit")
	var health_operation: PresentationOperation = fixture.presentation.sync_visual_health()
	var hit_operation: PresentationOperation = fixture.presentation._hit_operation
	assert_false(fixture.presentation._health_operation.is_completed)
	assert_false(hit_operation.is_completed)
	assert_false(health_operation.is_completed)
	fixture.presentation.hud._health_tween.custom_step(1.0)
	assert_false(
		health_operation.is_completed,
		"health completion still waits for the pending Hit animation",
	)
	player.animation_finished.emit(&"Hit")
	assert_true(health_operation.is_completed)
	assert_eq(player.current_animation, "Idle")

	fixture.presentation._process(0.0)
	assert_true(fixture.presentation.hud.visible)
	fixture.presentation.combatant.defeat()
	var shutdown_operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(shutdown_operation.is_completed)
	assert_same(fixture.presentation.sync_visual_health(), shutdown_operation)
	assert_null(fixture.presentation.instance_material.next_pass)
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


func test_lethal_hit_shutdown_settles_later_health_sync_without_hidden_tween() -> void:
	var fixture := _bound_animated_drone(_world(), _enemy())
	var enemy: EnemyCombatant = fixture.presentation.combatant

	await enemy.take_one_hit(
		_damage_result(100), Effect_Damage.new(), enemy, Action.DamageType.KINETIC,
	)
	assert_true(enemy.is_defeated)
	assert_eq(fixture.presentation.hud.hp_bar_actual.value, 0.0)
	assert_eq(fixture.presentation.hud.hp_bar_feedback.value, 100.0)
	var shutdown_operation: PresentationOperation = fixture.presentation.sync_visual_health()
	assert_false(shutdown_operation.is_completed)
	fixture.presentation._fade_tween.custom_step(
		fixture.presentation.DEFEAT_FADE_DURATION,
	)
	assert_true(shutdown_operation.is_completed)
	assert_false(fixture.presentation.hud.visible)
	assert_null(fixture.presentation._shutdown_operation)
	assert_null(fixture.presentation.hud._health_tween)

	var settled_operation: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_true(
		settled_operation.is_completed,
		"post-shutdown health synchronization never delays teardown",
	)
	assert_null(fixture.presentation._health_operation)
	assert_null(fixture.presentation.hud._health_tween)


func test_action_emits_one_laser_for_each_visible_intended_hero_target() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var world_fixture := _world()
	var enemy := _enemy()
	enemy.battle_manager = manager
	var fixture := _bound_animated_drone(world_fixture, enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	fixture.presentation._process(0.0)
	var visible_hero := HeroCombatant.new()
	var hidden_hero := HeroCombatant.new()
	add_child_autofree(visible_hero)
	add_child_autofree(hidden_hero)
	visible_hero.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO, manager)
	hidden_hero.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO, manager)
	var visible_presentation := FixedTargetPresentation.new()
	var hidden_presentation := FixedTargetPresentation.new()
	manager.add_child(visible_presentation)
	manager.add_child(hidden_presentation)
	visible_presentation.target_position = Vector2(640, 710)
	hidden_presentation.target_position = Vector2(940, 710)
	hidden_presentation.target_visible = false
	visible_presentation.bind(visible_hero)
	hidden_presentation.bind(hidden_hero)
	assert_true(manager.register_presentation(visible_hero, visible_presentation))
	assert_true(manager.register_presentation(hidden_hero, hidden_presentation))
	enemy.intended_targets.assign([visible_hero, hidden_hero])
	watch_signals(fixture.presentation)

	fixture.presentation.show_action("Burst")

	assert_signal_emit_count(fixture.presentation, &"projectile_requested", 1)
	assert_signal_emitted_with_parameters(
		fixture.presentation,
		&"projectile_requested",
		[
			fixture.presentation.get_target_screen_position(),
			visible_presentation.target_position,
			&"laser",
		],
	)


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


func test_missing_model_keeps_hud_health_feedback_without_blocking_on_clips() -> void:
	var fixture := _drone_view(_world())
	fixture.presentation.model_loader.local_resource_path = MISSING_MODEL_PATH
	var enemy := _enemy()

	assert_true(fixture.presentation.setup_view(enemy))
	assert_true(fixture.presentation.model_loader.using_placeholder)
	assert_true(fixture.presentation.model_loader.placeholder.visible)
	assert_null(fixture.presentation.animation_player)
	assert_not_null(fixture.presentation.instance_material)
	var acting_operation: PresentationOperation = fixture.presentation.set_acting(true)
	fixture.presentation.show_action("Missing Attack")
	var action_operation: PresentationOperation = fixture.presentation.hide_action()
	_stage_damage(enemy, 40)
	var health_operation: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_true(acting_operation.is_completed)
	assert_true(action_operation.is_completed)
	assert_true(fixture.presentation._hit_operation.is_completed)
	assert_false(health_operation.is_completed)
	assert_eq(fixture.presentation.hud.hp_bar_actual.value, 60.0)
	assert_eq(fixture.presentation.hud.hp_bar_feedback.value, 100.0)
	fixture.presentation.hud._health_tween.custom_step(1.0)
	assert_true(health_operation.is_completed)
	assert_eq(fixture.presentation.hud.hp_bar_feedback.value, 60.0)
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


func test_manager_free_completes_pending_health_hit_join_and_children_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	_stage_damage(enemy, 40)
	var joined: PresentationOperation = fixture.presentation.sync_visual_health()
	var health: PresentationOperation = fixture.presentation._health_operation
	var hit: PresentationOperation = fixture.presentation._hit_operation
	assert_false(joined.is_completed)
	assert_false(health.is_completed)
	assert_false(hit.is_completed)
	var joined_count := [0]
	var health_count := [0]
	var hit_count := [0]
	var registry_was_clear_on_completion := [false]
	joined.completed.connect(
		func() -> void:
			joined_count[0] += 1
			registry_was_clear_on_completion[0] = \
				manager.presentation_for(enemy) == null
	)
	health.completed.connect(func() -> void: health_count[0] += 1)
	hit.completed.connect(func() -> void: hit_count[0] += 1)

	fixture.root.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(joined.is_completed)
	assert_true(health.is_completed)
	assert_true(hit.is_completed)
	assert_eq(joined_count[0], 1)
	assert_eq(health_count[0], 1)
	assert_eq(hit_count[0], 1)
	assert_true(registry_was_clear_on_completion[0])
	assert_null(manager.presentation_for(enemy))


func test_manager_replacement_completes_pending_health_hit_join_and_children_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	_stage_damage(enemy, 40)
	var operation: PresentationOperation = fixture.presentation.sync_visual_health()
	var health: PresentationOperation = fixture.presentation._health_operation
	var hit: PresentationOperation = fixture.presentation._hit_operation
	assert_false(operation.is_completed)
	assert_false(health.is_completed)
	assert_false(hit.is_completed)
	fixture.presentation.set_inspection_focused(true)
	var replacement := CombatantPresentation.new()
	replacement.bind(enemy)
	manager.add_child(replacement)
	var registry_was_replaced_on_completion := [false]
	var completion_count := [0]
	var health_count := [0]
	var hit_count := [0]
	operation.completed.connect(
		func() -> void:
			completion_count[0] += 1
			registry_was_replaced_on_completion[0] = (
				manager.presentation_for(enemy) == replacement
			)
	)
	health.completed.connect(func() -> void: health_count[0] += 1)
	hit.completed.connect(func() -> void: hit_count[0] += 1)

	assert_true(manager.register_presentation(enemy, replacement))

	assert_true(operation.is_completed)
	assert_true(health.is_completed)
	assert_true(hit.is_completed)
	assert_eq(completion_count[0], 1)
	assert_eq(health_count[0], 1)
	assert_eq(hit_count[0], 1)
	assert_true(registry_was_replaced_on_completion[0])
	assert_same(manager.presentation_for(enemy), replacement)
	assert_false(fixture.presentation.inspection_focused)
	assert_true(replacement.inspection_focused)
	assert_true(is_instance_valid(fixture.root))


func test_healing_waits_for_hud_health_without_starting_hit() -> void:
	var enemy := _enemy()
	enemy.current_hp = 40
	var fixture := _bound_animated_drone(_world(), enemy)

	enemy.take_healing(20)
	var operation: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_false(operation.is_completed)
	assert_null(fixture.presentation._hit_operation)
	assert_false(fixture.presentation._health_operation.is_completed)
	assert_eq(fixture.presentation.hud.hp_bar_actual.value, 40.0)
	assert_eq(fixture.presentation.hud.hp_bar_feedback.value, 60.0)
	fixture.presentation.hud._health_tween.custom_step(1.0)
	assert_true(operation.is_completed)
	assert_eq(fixture.presentation.hud.hp_bar_actual.value, 60.0)


func test_repeated_health_sync_replaces_only_health_and_preserves_hit() -> void:
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	_stage_damage(enemy, 40)
	var first_joined: PresentationOperation = fixture.presentation.sync_visual_health()
	var first_health: PresentationOperation = fixture.presentation._health_operation
	var hit: PresentationOperation = fixture.presentation._hit_operation

	enemy.take_healing(10)
	var second_joined: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_true(first_health.is_completed, "the replaced health wait is released")
	assert_false(first_joined.is_completed, "the first join still observes Hit")
	assert_false(hit.is_completed, "health replacement never completes Hit")
	assert_same(fixture.presentation._hit_operation, hit)
	assert_false(second_joined.is_completed)
	assert_false(fixture.presentation._health_operation.is_completed)
	fixture.presentation.hud._health_tween.custom_step(1.0)
	assert_false(second_joined.is_completed, "the replacement join still observes Hit")
	fixture.presentation.animation_player.animation_finished.emit(&"Hit")
	assert_true(first_joined.is_completed)
	assert_true(second_joined.is_completed)


func test_repeated_health_sync_preserves_attack_and_acting_state() -> void:
	var enemy := _enemy()
	enemy.current_hp = 40
	var fixture := _bound_animated_drone(_world(), enemy)
	fixture.presentation.set_acting(true)
	fixture.presentation.show_action("Burst")
	var attack: PresentationOperation = fixture.presentation._action_operation
	enemy.take_healing(10)
	var first_health: PresentationOperation = fixture.presentation.sync_visual_health()

	enemy.take_healing(10)
	var second_health: PresentationOperation = fixture.presentation.sync_visual_health()

	assert_true(first_health.is_completed)
	assert_false(second_health.is_completed)
	assert_false(attack.is_completed, "health replacement preserves Attack")
	assert_same(fixture.presentation._action_operation, attack)
	assert_true(fixture.presentation.acting)
	fixture.presentation.hud._health_tween.custom_step(1.0)
	fixture.presentation.animation_player.animation_finished.emit(&"Attack")


func test_manager_unregister_completes_pending_health_hit_join_and_children_once() -> void:
	var manager := RegistryTrackingBattleManager.new()
	add_child_autofree(manager)
	var enemy := _enemy()
	var fixture := _bound_animated_drone(_world(), enemy)
	assert_true(manager.register_presentation(enemy, fixture.presentation))
	_stage_damage(enemy, 40)
	var joined: PresentationOperation = fixture.presentation.sync_visual_health()
	var health: PresentationOperation = fixture.presentation._health_operation
	var hit: PresentationOperation = fixture.presentation._hit_operation
	assert_false(joined.is_completed)
	assert_false(health.is_completed)
	assert_false(hit.is_completed)
	var joined_count := [0]
	var health_count := [0]
	var hit_count := [0]
	var registry_was_clear_on_completion := [false]
	joined.completed.connect(
		func() -> void:
			joined_count[0] += 1
			registry_was_clear_on_completion[0] = \
				manager.presentation_for(enemy) == null
	)
	health.completed.connect(func() -> void: health_count[0] += 1)
	hit.completed.connect(func() -> void: hit_count[0] += 1)

	manager.unregister_presentation(enemy)

	assert_true(joined.is_completed)
	assert_true(health.is_completed)
	assert_true(hit.is_completed)
	assert_eq(joined_count[0], 1)
	assert_eq(health_count[0], 1)
	assert_eq(hit_count[0], 1)
	assert_true(registry_was_clear_on_completion[0])
	assert_null(manager.presentation_for(enemy))
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
	material.metallic = 1.0
	material.roughness = 0.1
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


func _damage_result(amount: int) -> DamageResult:
	var request := DamageRequest.new(
		amount, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 0,
	)
	return DamageResult.new(
		request, amount, 0, 1.0, 1.0, 1.0, amount, amount,
	)


func _stage_damage(enemy: EnemyCombatant, amount: int) -> void:
	enemy.current_hp -= amount
	enemy.hp_changed.emit(enemy, enemy.current_hp, enemy.current_stats.max_hp)
	enemy.presentation_event.emit(enemy, &"damage_received", {"actual_damage": amount})


func _collect_presentations(
	node: Node,
	result: Array[CombatantPresentation],
) -> void:
	if node is CombatantPresentation:
		result.append(node as CombatantPresentation)
	for child: Node in node.get_children():
		_collect_presentations(child, result)


func _projected_proxy_rect(
	camera: Camera3D,
	presentation: EnemyDronePresentation,
) -> Rect2:
	var points: Array[Vector2] = []
	for anchor: Marker3D in [
		presentation.bounds_left_anchor,
		presentation.bounds_right_anchor,
		presentation.bounds_top_anchor,
		presentation.bounds_bottom_anchor,
	]:
		points.append(camera.unproject_position(anchor.global_position))
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _mouse_motion_at(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _mouse_button_at(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event
