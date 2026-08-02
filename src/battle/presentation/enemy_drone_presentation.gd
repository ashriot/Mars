extends CombatantPresentation
class_name EnemyDronePresentation

const HUD_SCENE := preload("res://src/battle/presentation/enemy_world_hud.tscn")
const DEFEAT_FADE_DURATION := 0.2

@export var view_root: Node3D
@export var model_loader: OptionalLocalModel3D
@export var head_anchor: Marker3D
@export var foot_anchor: Marker3D

var camera: Camera3D
var hud: EnemyWorldHUD
var animation_player: AnimationPlayer
var instance_material: BaseMaterial3D

var _instance_materials: Array[BaseMaterial3D] = []
var _action_operation: PresentationOperation
var _hit_operation: PresentationOperation
var _shutdown_operation: PresentationOperation
var _fade_tween: Tween


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	set_process(false)
	_stop_owned_motion()
	_disconnect_model_events()
	_disconnect_combatant_events()
	_remove_hud()
	super._exit_tree()


func setup_view(value: BattleCombatant) -> bool:
	if not (value is EnemyCombatant):
		push_error("EnemyDronePresentation requires an EnemyCombatant.")
		return false
	if not super.setup_view(value):
		return false
	if not is_instance_valid(view_root) \
		or not is_instance_valid(model_loader) \
		or not is_instance_valid(head_anchor) \
		or not is_instance_valid(foot_anchor):
		push_error("EnemyDronePresentation requires configured view nodes.")
		return false
	camera = get_viewport().get_camera_3d()
	var hud_layer := _hud_layer_for_viewport()
	if not is_instance_valid(camera) or not is_instance_valid(hud_layer):
		camera = null
		push_error("EnemyDronePresentation requires a battle camera and HUD layer.")
		return false
	hud = HUD_SCENE.instantiate() as EnemyWorldHUD
	if not is_instance_valid(hud):
		push_error("EnemyDronePresentation could not instantiate its enemy HUD.")
		return false
	hud_layer.add_child(hud)
	hud.enable_presentation_owned_defeat_fade()
	hud.set_projection_visible(false)
	if not hud.bind_combatant(value as EnemyCombatant):
		_remove_hud()
		return false
	hud.set_projection_visible(false)
	_connect_hud_input()
	_connect_combatant_events()
	_connect_model_events()
	model_loader.try_load()
	if (value as EnemyCombatant).is_defeated:
		view_root.visible = false
		return true
	set_process(true)
	return true


func get_target_screen_position() -> Vector2:
	if not is_instance_valid(camera) or not is_instance_valid(head_anchor):
		return Vector2.ZERO
	return camera.unproject_position(head_anchor.global_position)


func is_target_visible() -> bool:
	return is_instance_valid(hud) and hud.has_valid_projection()


func set_target_presentation(state: TargetState) -> void:
	super.set_target_presentation(state)
	if is_instance_valid(hud):
		hud.set_target_state(state)
	_refresh_details_visibility()


func set_acting(active: bool):
	acting = active
	if not _combatant_is_defeated():
		_play_if_present(&"Charging" if active else &"Idle")
	_refresh_details_visibility()
	return PresentationOperation.already_completed()


func show_action(_action_name: String) -> void:
	if _hit_operation != null:
		_hit_operation.complete()
	_request_intended_target_projectiles()
	_action_operation = _start_transient_animation(&"Attack", _action_operation)


func hide_action():
	if _action_operation != null:
		return _action_operation
	return PresentationOperation.already_completed()


func sync_visual_health():
	if _shutdown_operation != null:
		return _shutdown_operation
	if _hit_operation != null:
		return _hit_operation
	return PresentationOperation.already_completed()


func refresh_intent() -> void:
	if is_instance_valid(hud):
		hud.refresh_intent()


func set_instance_tint(color: Color) -> void:
	for material: BaseMaterial3D in _instance_materials:
		material.albedo_color = color


func cancel_pending_operations() -> void:
	_stop_owned_motion()
	super.cancel_pending_operations()


func _process(_delta: float) -> void:
	_update_projection()


func _update_projection() -> void:
	if not is_instance_valid(camera) \
		or not is_instance_valid(hud) \
		or not is_instance_valid(head_anchor) \
		or not is_instance_valid(foot_anchor) \
		or not is_instance_valid(combatant) \
		or combatant.is_defeated:
		if is_instance_valid(hud):
			hud.set_projection_visible(false)
		return
	if camera.is_position_behind(head_anchor.global_position) \
		or camera.is_position_behind(foot_anchor.global_position):
		hud.set_projection_visible(false)
		return
	hud.set_projected_head_position(
		camera.unproject_position(head_anchor.global_position),
	)
	hud.set_projected_foot_position(
		camera.unproject_position(foot_anchor.global_position),
	)
	hud.set_projection_visible(true)


func _refresh_details_visibility() -> void:
	if is_instance_valid(hud):
		hud.set_details_visible(acting or target_state == TargetState.SELECTED)


func _request_intended_target_projectiles() -> void:
	if not (combatant is EnemyCombatant) or not is_target_visible():
		return
	var enemy := combatant as EnemyCombatant
	var manager := enemy.battle_manager as BattleManager
	if not is_instance_valid(manager):
		return
	var from_screen := get_target_screen_position()
	for target: BattleCombatant in enemy.intended_targets:
		if not (target is HeroCombatant) or not is_instance_valid(target):
			continue
		var target_presentation := manager.presentation_for(target)
		if target_presentation == null or not target_presentation.is_target_visible():
			continue
		projectile_requested.emit(
			from_screen,
			target_presentation.get_target_screen_position(),
			&"laser",
		)


func _hud_layer_for_viewport() -> Control:
	for candidate: Node in get_tree().get_nodes_in_group(&"battle_enemy_hud_layer"):
		if candidate is Control and candidate.get_viewport() == get_viewport():
			return candidate as Control
	return null


func _connect_hud_input() -> void:
	if not hud.hovered.is_connected(_on_hud_hovered):
		hud.hovered.connect(_on_hud_hovered)
	if not hud.unhovered.is_connected(_on_hud_unhovered):
		hud.unhovered.connect(_on_hud_unhovered)
	if not hud.pressed.is_connected(_on_hud_pressed):
		hud.pressed.connect(_on_hud_pressed)


func _disconnect_hud_input() -> void:
	if not is_instance_valid(hud):
		return
	if hud.hovered.is_connected(_on_hud_hovered):
		hud.hovered.disconnect(_on_hud_hovered)
	if hud.unhovered.is_connected(_on_hud_unhovered):
		hud.unhovered.disconnect(_on_hud_unhovered)
	if hud.pressed.is_connected(_on_hud_pressed):
		hud.pressed.disconnect(_on_hud_pressed)


func _connect_combatant_events() -> void:
	if is_instance_valid(combatant) \
		and not combatant.presentation_event.is_connected(_on_presentation_event):
		combatant.presentation_event.connect(_on_presentation_event)


func _disconnect_combatant_events() -> void:
	if is_instance_valid(combatant) \
		and combatant.presentation_event.is_connected(_on_presentation_event):
		combatant.presentation_event.disconnect(_on_presentation_event)


func _connect_model_events() -> void:
	if not model_loader.model_loaded.is_connected(_on_model_loaded):
		model_loader.model_loaded.connect(_on_model_loaded)
	if not model_loader.model_unavailable.is_connected(_on_model_unavailable):
		model_loader.model_unavailable.connect(_on_model_unavailable)


func _disconnect_model_events() -> void:
	if not is_instance_valid(model_loader):
		return
	if model_loader.model_loaded.is_connected(_on_model_loaded):
		model_loader.model_loaded.disconnect(_on_model_loaded)
	if model_loader.model_unavailable.is_connected(_on_model_unavailable):
		model_loader.model_unavailable.disconnect(_on_model_unavailable)


func _on_hud_hovered() -> void:
	if _combatant_is_interactive():
		target_hovered.emit(combatant)


func _on_hud_unhovered() -> void:
	if _combatant_is_interactive():
		target_unhovered.emit(combatant)


func _on_hud_pressed() -> void:
	if _combatant_is_interactive():
		target_pressed.emit(combatant)


func _on_model_loaded(instance: Node3D) -> void:
	_prepare_model(instance)


func _on_model_unavailable(_path: String) -> void:
	_prepare_model(model_loader.placeholder)


func _prepare_model(model_root: Node3D) -> void:
	_disconnect_animation_player()
	_instance_materials.clear()
	instance_material = null
	if not is_instance_valid(model_root):
		return
	_duplicate_mesh_materials(model_root)
	animation_player = _find_animation_player(model_root)
	if is_instance_valid(animation_player):
		animation_player.animation_finished.connect(_on_animation_finished)
		if not _combatant_is_defeated():
			_play_if_present(&"Idle")


func _duplicate_mesh_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is PrimitiveMesh:
			_duplicate_primitive_material(mesh_instance)
		elif mesh_instance.mesh != null:
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(surface_index)
				var unique: Material = source.duplicate(true) as Material \
					if source != null else StandardMaterial3D.new()
				mesh_instance.set_surface_override_material(surface_index, unique)
				_remember_material(unique)
	for child: Node in node.get_children():
		_duplicate_mesh_materials(child)


func _duplicate_primitive_material(mesh_instance: MeshInstance3D) -> void:
	var source_mesh := mesh_instance.mesh as PrimitiveMesh
	var unique_mesh := source_mesh.duplicate() as PrimitiveMesh
	var source_material := source_mesh.material
	var unique_material: Material = source_material.duplicate(true) as Material \
		if source_material != null else StandardMaterial3D.new()
	unique_mesh.material = unique_material
	mesh_instance.mesh = unique_mesh
	_remember_material(unique_material)


func _remember_material(material: Material) -> void:
	if not (material is BaseMaterial3D):
		return
	var base_material := material as BaseMaterial3D
	_instance_materials.append(base_material)
	if instance_material == null:
		instance_material = base_material


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _disconnect_animation_player() -> void:
	if is_instance_valid(animation_player):
		if animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.disconnect(_on_animation_finished)
		animation_player.stop()
	animation_player = null


func _play_if_present(animation_name: StringName) -> bool:
	if not is_instance_valid(animation_player) \
		or not animation_player.has_animation(animation_name):
		return false
	animation_player.play(animation_name)
	return true


func _start_transient_animation(
	animation_name: StringName,
	previous: PresentationOperation,
) -> PresentationOperation:
	if previous != null:
		previous.complete()
	if _combatant_is_defeated() or not _play_if_present(animation_name):
		if not _combatant_is_defeated():
			_play_if_present(&"Idle")
		return PresentationOperation.already_completed()
	var operation := _begin_operation()
	operation.completed.connect(
		_on_transient_operation_completed.bind(animation_name, operation),
		CONNECT_ONE_SHOT,
	)
	return operation


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"Attack":
			if _action_operation != null:
				_action_operation.complete()
		&"Hit":
			if _hit_operation != null:
				_hit_operation.complete()
	if animation_name != &"Idle" and not _combatant_is_defeated():
		_play_if_present(&"Idle")


func _on_transient_operation_completed(
	animation_name: StringName,
	operation: PresentationOperation,
) -> void:
	if animation_name == &"Attack" and _action_operation == operation:
		_action_operation = null
	elif animation_name == &"Hit" and _hit_operation == operation:
		_hit_operation = null


func _on_presentation_event(
	_actor: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			if _action_operation != null:
				_action_operation.complete()
			_hit_operation = _start_transient_animation(&"Hit", _hit_operation)
		&"intent_changed":
			refresh_intent()
		&"defeat_started":
			_begin_shutdown_fade()


func _begin_shutdown_fade() -> void:
	if _shutdown_operation != null:
		return
	set_process(false)
	if is_instance_valid(hud):
		hud.set_target_state(TargetState.NORMAL)
		hud.set_details_visible(false)
		hud.begin_presentation_owned_defeat_fade()
	if _action_operation != null:
		_action_operation.complete()
	if _hit_operation != null:
		_hit_operation.complete()
	if is_instance_valid(animation_player):
		animation_player.stop()
	_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for material: BaseMaterial3D in _instance_materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_tween.tween_method(
		_apply_shutdown_alpha, 1.0, 0.0, DEFEAT_FADE_DURATION,
	)
	_shutdown_operation = _operation_for_tween(_fade_tween)
	_shutdown_operation.completed.connect(
		_on_shutdown_completed.bind(_shutdown_operation), CONNECT_ONE_SHOT,
	)


func _on_shutdown_completed(operation: PresentationOperation) -> void:
	if _shutdown_operation != operation:
		return
	_shutdown_operation = null
	_fade_tween = null
	if is_instance_valid(hud):
		hud.complete_presentation_owned_defeat_fade()
	if is_instance_valid(view_root):
		view_root.visible = false


func _apply_shutdown_alpha(alpha: float) -> void:
	for material: BaseMaterial3D in _instance_materials:
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
	if is_instance_valid(hud):
		hud.modulate.a = alpha


func _stop_owned_motion() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if is_instance_valid(animation_player):
		animation_player.stop()


func _remove_hud() -> void:
	if not is_instance_valid(hud):
		hud = null
		return
	_disconnect_hud_input()
	hud.free()
	hud = null


func _combatant_is_defeated() -> bool:
	return is_instance_valid(combatant) and combatant.is_defeated


func _combatant_is_interactive() -> bool:
	return is_instance_valid(combatant) and not combatant.is_defeated
