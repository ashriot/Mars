extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

var _controller_target: ActorCard
var _last_controller_direction := Vector2.ZERO
var _direction_hold_time := 0.0
const REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.12

func _ready():
	manager.battle_ended.connect(_on_battle_ended)
	manager.battle_state_changed.connect(_on_battle_state_changed)
	if manager.action_bar:
		manager.action_bar.action_selected.connect(_on_action_selected)
		manager.action_bar.availability_changed.connect(_publish_controller_hints)
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.set_adapter(self)
	_restore_controller_target()
	_publish_controller_hints()


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and navigation._adapter == self:
		navigation.set_adapter(null)
		navigation.publish_hints([])


func _process(delta: float) -> void:
	if not _controller_input_allowed():
		_last_controller_direction = Vector2.ZERO
		return
	var direction := Input.get_vector(&"nav_left", &"nav_right", &"nav_up", &"nav_down")
	process_controller_direction(direction, delta)


func process_controller_direction(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		_last_controller_direction = Vector2.ZERO
		_direction_hold_time = 0.0
		return
	var changed := _last_controller_direction.is_zero_approx() or direction.normalized().dot(_last_controller_direction.normalized()) < 0.99
	if changed:
		select_direction(direction)
		_direction_hold_time = 0.0
	else:
		_direction_hold_time += delta
		if _direction_hold_time >= REPEAT_DELAY:
			select_direction(direction)
			_direction_hold_time = REPEAT_DELAY - REPEAT_INTERVAL
	_last_controller_direction = direction


func _unhandled_input(event: InputEvent) -> void:
	if not _controller_input_allowed():
		return
	if event.is_action_pressed(&"confirm") and _is_targeting():
		var viewport := get_viewport()
		confirm_target()
		if viewport:
			viewport.set_input_as_handled()
	elif event.is_action_pressed(&"cancel") and _is_targeting():
		cancel_targeting()
		get_viewport().set_input_as_handled()


func select_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	var candidates := _valid_controller_targets()
	if candidates.is_empty():
		return
	var origin: Vector2 = _controller_target.global_position + _controller_target.size * 0.5 if is_instance_valid(_controller_target) else _target_origin(candidates)
	var best: ActorCard
	var best_angle := INF
	var best_distance := INF
	for candidate: ActorCard in candidates:
		if candidate == _controller_target:
			continue
		var offset := candidate.global_position + candidate.size * 0.5 - origin
		if offset.dot(direction) <= 0.0:
			continue
		var angle: float = abs(direction.normalized().angle_to(offset.normalized()))
		var distance: float = offset.length_squared()
		if angle < best_angle or (is_equal_approx(angle, best_angle) and distance < best_distance):
			best = candidate
			best_angle = angle
			best_distance = distance
	if best:
		_set_controller_target(best)
		return
	# Cycle at the edge to the geometrically opposite extreme.
	var wrapped: ActorCard
	var wrapped_projection := INF
	for candidate: ActorCard in candidates:
		if candidate == _controller_target:
			continue
		var projection := (candidate.global_position + candidate.size * 0.5).dot(direction.normalized())
		if projection < wrapped_projection:
			wrapped = candidate
			wrapped_projection = projection
	if wrapped:
		_set_controller_target(wrapped)


func confirm_target() -> void:
	if not is_instance_valid(_controller_target) or not _controller_target.is_valid_target or _controller_target.is_defeated:
		return
	if _controller_target is HeroCard:
		manager._on_hero_clicked(_controller_target as HeroCard)
	elif _controller_target is EnemyCard:
		manager._on_enemy_clicked(_controller_target as EnemyCard)


func cancel_targeting() -> void:
	if not _is_targeting():
		return
	manager._clear_all_targeting_ui()
	manager.current_action = null
	if manager.current_action_panel:
		manager.current_action_panel.hide()
	if manager.focused_button:
		manager.focused_button.focused(false)
		manager.focused_button = null
	manager.change_state(BattleManager.State.PLAYER_ACTION)
	_controller_target = manager.current_actor
	_update_cursor()
	_publish_controller_hints()


func _on_action_selected(_button: ActionButton) -> void:
	_refresh_targeting.call_deferred()


func _on_battle_state_changed(_state: BattleManager.State) -> void:
	_refresh_targeting.call_deferred()


func _on_input_mode_changed(mode: InputManager.InputMode) -> void:
	if mode == InputManager.InputMode.CONTROLLER:
		return
	if is_instance_valid(_controller_target) and _controller_target is EnemyCard:
		manager._on_enemy_unhovered(_controller_target as EnemyCard)
	_controller_target = manager.current_actor
	_last_controller_direction = Vector2.ZERO
	_direction_hold_time = 0.0
	_update_cursor()


func _refresh_targeting() -> void:
	if _is_targeting():
		var candidates := _valid_controller_targets()
		if not candidates.is_empty() and not candidates.has(_controller_target):
			_set_controller_target(candidates[0])
	else:
		_controller_target = manager.current_actor
		_update_cursor()
	_publish_controller_hints()


func _is_targeting() -> bool:
	return manager != null and (manager.current_state == BattleManager.State.FORCED_TARGET or manager.current_action != null) and not _valid_controller_targets().is_empty()


func navigation_focus_restored() -> void:
	_restore_controller_target()
	_publish_controller_hints()


func _valid_controller_targets() -> Array[ActorCard]:
	var targets: Array[ActorCard] = []
	if not manager:
		return targets
	var source: Array = manager.get_living_heroes() + manager.get_living_enemies()
	for actor in source:
		if actor is ActorCard and actor.is_valid_target and not actor.is_defeated:
			targets.append(actor)
	return targets


func _target_origin(candidates: Array[ActorCard]) -> Vector2:
	if manager and is_instance_valid(manager.current_actor):
		return manager.current_actor.global_position + manager.current_actor.size * 0.5
	return candidates[0].global_position + candidates[0].size * 0.5


func _set_controller_target(target: ActorCard) -> void:
	if is_instance_valid(_controller_target) and _controller_target is EnemyCard:
		manager._on_enemy_unhovered(_controller_target as EnemyCard)
	_controller_target = target
	if target is EnemyCard:
		manager._on_enemy_hovered(target as EnemyCard)
	_update_cursor()
	_publish_controller_hints()


func _restore_controller_target() -> void:
	var candidates := _valid_controller_targets()
	if not candidates.is_empty() and _is_targeting():
		_set_controller_target(candidates[0])
	elif manager:
		_controller_target = manager.current_actor
		_update_cursor()


func _update_cursor() -> void:
	var navigation := _navigation_ux_layer()
	if not navigation:
		return
	if is_instance_valid(_controller_target):
		navigation.cursor.set_focus_target(_controller_target, NavigationCursor.CursorState.TARGET)
	else:
		navigation.cursor.clear_target()


func _publish_controller_hints() -> void:
	var navigation := _navigation_ux_layer()
	if not navigation or not manager:
		return
	var hints: Array[Dictionary] = []
	if manager.current_state == BattleManager.State.PLAYER_ACTION and manager.current_action == null and manager.action_bar:
		for index in 4:
			var button := manager.action_bar.actions_ui.get_child(index) as ActionButton if index < manager.action_bar.actions_ui.get_child_count() else null
			if button and button.visible and not button.disabled:
				hints.append({action = StringName("action_%d" % (index + 1)), label = button.label.text, enabled = true})
		var shift_direction := manager.action_bar._available_shift_direction()
		if not shift_direction.is_empty():
			hints.append({action = &"shift_action", label = "Shift", enabled = true})
	if _is_targeting():
		hints.append({action = &"confirm", label = "Select", enabled = is_instance_valid(_controller_target)})
		hints.append({action = &"cancel", label = "Cancel", enabled = true})
	navigation.publish_hints(hints)


func _controller_input_allowed() -> bool:
	var navigation := _navigation_ux_layer()
	return manager != null and (navigation == null or (navigation._adapter == self and navigation._modal_stack.is_empty()))


func _navigation_ux_layer() -> NavigationUXLayer:
	if not is_inside_tree() or get_tree() == null:
		return null
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer

# Update signature to take the full resource
func setup_battle(encounter: Encounter):
	manager.current_encounter = encounter
	manager.spawn_encounter()

func _on_battle_ended(won: bool):
	battle_ended.emit(won)
