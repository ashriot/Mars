extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

var _current_target: ActorCard
var _navigation_origin: ActorCard
var _last_enemy_target: EnemyCard
var _last_hero_target: HeroCard
var _last_controller_direction := Vector2.ZERO
var _direction_hold_time := 0.0
const REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.12

func _ready():
	manager.battle_ended.connect(_on_battle_ended)
	manager.battle_state_changed.connect(_on_battle_state_changed)
	manager.target_hovered.connect(_on_target_hovered)
	manager.target_unhovered.connect(_on_target_unhovered)
	manager.target_invalidated.connect(_on_target_invalidated)
	if manager.action_bar:
		manager.action_bar.action_selected.connect(_on_action_selected)
		manager.action_bar.action_cancelled.connect(cancel_targeting)
		manager.action_bar.availability_changed.connect(_publish_controller_hints)
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	InputManager.presentation_mode_changed.connect(_on_presentation_mode_changed)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.set_adapter(self)
	_refresh_targeting()
	_publish_controller_hints()


func _exit_tree() -> void:
	_clear_current_target(false)
	if manager:
		manager._clear_all_targeting_ui()
	_last_enemy_target = null
	_last_hero_target = null
	var navigation := _navigation_ux_layer()
	if navigation and navigation._adapter == self:
		navigation.set_adapter(null)
		navigation.publish_hints([])


func _process(delta: float) -> void:
	if not _controller_input_allowed():
		_last_controller_direction = Vector2.ZERO
		return
	var direction := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
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
	if not is_instance_valid(_current_target) and _is_valid_candidate(_navigation_origin):
		_set_current_target(_navigation_origin)
		return
	var candidates := _valid_targets()
	if candidates.is_empty():
		return
	var origin: Vector2 = _current_target.global_position + _current_target.size * 0.5 if _is_valid_candidate(_current_target) else _target_origin(candidates)
	var best: ActorCard
	var best_angle := INF
	var best_distance := INF
	for candidate: ActorCard in candidates:
		if candidate == _current_target:
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
		_set_current_target(best)
		return
	# Cycle at the edge to the geometrically opposite extreme.
	var wrapped: ActorCard
	var wrapped_projection := INF
	for candidate: ActorCard in candidates:
		if candidate == _current_target:
			continue
		var projection := (candidate.global_position + candidate.size * 0.5).dot(direction.normalized())
		if projection < wrapped_projection:
			wrapped = candidate
			wrapped_projection = projection
	if wrapped:
		_set_current_target(wrapped)


func confirm_target() -> void:
	if not _is_valid_candidate(_current_target) \
		or not _current_target.is_visible_in_tree() \
		or _current_target.get_target_presentation() != ActorCard.TargetPresentation.SELECTED:
		return
	if _current_target is HeroCard:
		manager._on_hero_clicked(_current_target as HeroCard)
	elif _current_target is EnemyCard:
		manager._on_enemy_clicked(_current_target as EnemyCard)


func cancel_targeting() -> void:
	if not _is_targeting():
		return
	manager.current_action = null
	_clear_current_target(false)
	manager._clear_all_targeting_ui()
	if manager.current_action_panel:
		manager.current_action_panel.hide()
	if manager.focused_button:
		manager.focused_button.focused(false)
		manager.focused_button = null
	manager.change_state(BattleManager.State.PLAYER_ACTION)
	manager.update_turn_order()
	_publish_controller_hints()


func _on_action_selected(_button: ActionButton) -> void:
	if InputManager.get_active_mode() != InputManager.InputMode.CONTROLLER:
		_clear_current_target(false)
	_refresh_targeting.call_deferred()


func _on_battle_state_changed(_state: BattleManager.State) -> void:
	_refresh_targeting.call_deferred()


func _on_input_mode_changed(mode: InputManager.InputMode) -> void:
	_last_controller_direction = Vector2.ZERO
	_direction_hold_time = 0.0
	if mode == InputManager.InputMode.CONTROLLER and _is_targeting():
		_restore_remembered_target()
	_publish_controller_hints()


func _on_presentation_mode_changed(mode: InputManager.PresentationMode) -> void:
	if mode == InputManager.PresentationMode.POINTER \
		and InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and _is_targeting():
		_clear_current_target(true)


func _on_target_hovered(actor: ActorCard) -> void:
	if InputManager.get_active_mode() != InputManager.InputMode.KEYBOARD_MOUSE \
		or InputManager.get_presentation_mode() != InputManager.PresentationMode.POINTER \
		or not _is_targeting() \
		or not _is_valid_candidate(actor):
		return
	_set_current_target(actor)


func _on_target_unhovered(actor: ActorCard) -> void:
	if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and InputManager.get_presentation_mode() == InputManager.PresentationMode.POINTER \
		and actor == _current_target:
		_clear_current_target(true)


func _on_target_invalidated(actor: ActorCard) -> void:
	if _navigation_origin == actor:
		_navigation_origin = null
	if _last_enemy_target == actor:
		_last_enemy_target = null
	if _last_hero_target == actor:
		_last_hero_target = null
	_refresh_targeting()


func _refresh_targeting() -> void:
	if not _is_targeting():
		_clear_current_target(false)
		_publish_controller_hints()
		return
	_prune_target_memory()
	if is_instance_valid(_current_target) and not _is_valid_candidate(_current_target):
		if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
			_restore_remembered_target()
		else:
			_clear_current_target(false)
	var group_targeting := _is_group_targeting()
	for candidate: ActorCard in _valid_targets():
		if group_targeting:
			candidate.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		elif candidate != _current_target:
			candidate.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER \
		and not _is_valid_candidate(_current_target):
		_restore_remembered_target()
	elif InputManager.get_active_mode() != InputManager.InputMode.CONTROLLER \
		and not _is_valid_candidate(_current_target):
		_clear_current_target(false)
	_publish_controller_hints()


func _is_targeting() -> bool:
	return manager != null and not _valid_targets().is_empty()


func _is_group_targeting() -> bool:
	return manager != null and manager.is_group_target_action(manager.current_action)


func navigation_focus_restored() -> void:
	_refresh_targeting()


func _valid_targets() -> Array[ActorCard]:
	var targets: Array[ActorCard] = []
	if not manager:
		return targets
	var source: Array = manager.get_living_heroes() + manager.get_living_enemies()
	for actor in source:
		if actor is ActorCard \
			and actor.is_visible_in_tree() \
			and actor.is_valid_target \
			and not actor.is_defeated:
			targets.append(actor)
	return targets


func _is_valid_candidate(target: ActorCard) -> bool:
	return is_instance_valid(target) \
		and target.is_inside_tree() \
		and target.is_valid_target \
		and not target.is_defeated \
		and _valid_targets().has(target)


func _target_origin(candidates: Array[ActorCard]) -> Vector2:
	if manager and is_instance_valid(manager.current_actor):
		return manager.current_actor.global_position + manager.current_actor.size * 0.5
	return candidates[0].global_position + candidates[0].size * 0.5


func _set_current_target(target: ActorCard) -> void:
	if not _is_valid_candidate(target):
		return
	if is_instance_valid(_current_target) and _current_target != target:
		if _is_group_targeting() and _is_valid_candidate(_current_target):
			_current_target.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		else:
			_current_target.set_target_presentation(
				ActorCard.TargetPresentation.AVAILABLE
				if _is_valid_candidate(_current_target)
				else ActorCard.TargetPresentation.NORMAL
			)
	_current_target = target
	_navigation_origin = target
	target.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	if target is EnemyCard:
		_last_enemy_target = target
	elif target is HeroCard:
		_last_hero_target = target
	_refresh_target_preview()


func _clear_current_target(retain_origin: bool) -> void:
	if is_instance_valid(_current_target):
		if _is_group_targeting() and _is_valid_candidate(_current_target):
			_current_target.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		else:
			_current_target.set_target_presentation(
				ActorCard.TargetPresentation.AVAILABLE
				if _is_valid_candidate(_current_target)
				else ActorCard.TargetPresentation.NORMAL
			)
		if retain_origin:
			_navigation_origin = _current_target
	_current_target = null
	if not retain_origin:
		_navigation_origin = null
	_refresh_target_preview()


func _refresh_target_preview() -> void:
	if manager and is_instance_valid(manager.current_actor) and manager.current_action:
		var preview_target: ActorCard = null if _is_group_targeting() else _current_target
		manager.preview_action_turn_order(manager.current_actor, manager.current_action, preview_target)


func _restore_remembered_target() -> void:
	var candidates := _valid_targets()
	if candidates.is_empty():
		_clear_current_target(false)
		return
	var remembered: ActorCard = _last_hero_target if candidates[0] is HeroCard else _last_enemy_target
	_set_current_target(remembered if _is_valid_candidate(remembered) else candidates[0])


func _prune_target_memory() -> void:
	if _last_enemy_target != null \
		and (not is_instance_valid(_last_enemy_target) or _last_enemy_target.is_defeated):
		_last_enemy_target = null
	if _last_hero_target != null \
		and (not is_instance_valid(_last_hero_target) or _last_hero_target.is_defeated):
		_last_hero_target = null


func _publish_controller_hints() -> void:
	var navigation := _navigation_ux_layer()
	if not navigation:
		return
	# Combat controls carry their own input glyphs; the global hint panel is redundant here.
	navigation.publish_hints([])


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
