extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

var _current_target: BattleCombatant
var _navigation_origin: BattleCombatant
var _last_enemy_target: EnemyCombatant
var _last_hero_target: HeroCombatant
var _last_controller_direction := Vector2.ZERO
var _direction_hold_time := 0.0
const REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.12
const TURN_QUEUE_TOP_MARGIN_DESKTOP := 16.0
const TURN_QUEUE_BOTTOM_MARGIN_DESKTOP := 300.0
const TURN_QUEUE_TOP_MARGIN_COMPACT := 16.0
const TURN_QUEUE_BOTTOM_MARGIN_COMPACT := 300.0

func _ready():
	DisplayProfile.bind(apply_display_profile)
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


func apply_display_profile(profile: int, window_size: Vector2i, logical_size: Vector2) -> void:
	var compact := profile == DisplayProfileService.Profile.COMPACT
	var turn_queue := get_node_or_null("UI/TurnQueue") as TurnQueue
	if turn_queue:
		turn_queue.offset_top = (
			TURN_QUEUE_TOP_MARGIN_COMPACT if compact else TURN_QUEUE_TOP_MARGIN_DESKTOP
		)
		turn_queue.offset_bottom = -(
			TURN_QUEUE_BOTTOM_MARGIN_COMPACT if compact else TURN_QUEUE_BOTTOM_MARGIN_DESKTOP
		)
		turn_queue.apply_display_profile(profile, window_size, logical_size)
	var action_bar := get_node_or_null("UI/ActionBar") as ActionBar
	if action_bar:
		action_bar.apply_display_profile(profile, window_size, logical_size)


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
	var origin: Vector2 = _target_position(_current_target) \
		if _is_valid_candidate(_current_target) else _target_origin(candidates)
	var best: BattleCombatant
	var best_angle := INF
	var best_distance := INF
	for candidate: BattleCombatant in candidates:
		if candidate == _current_target:
			continue
		var offset := _target_position(candidate) - origin
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
	var wrapped: BattleCombatant
	var wrapped_projection := INF
	for candidate: BattleCombatant in candidates:
		if candidate == _current_target:
			continue
		var projection := _target_position(candidate).dot(direction.normalized())
		if projection < wrapped_projection:
			wrapped = candidate
			wrapped_projection = projection
	if wrapped:
		_set_current_target(wrapped)


func confirm_target() -> void:
	if not _is_valid_candidate(_current_target) \
		or not _is_presentation_visible(_current_target) \
		or _presentation_target_state(_current_target) != CombatantPresentation.TargetState.SELECTED:
		return
	if _current_target is HeroCombatant:
		manager._on_hero_clicked(_current_target as HeroCombatant)
	elif _current_target is EnemyCombatant:
		manager._on_enemy_clicked(_current_target as EnemyCombatant)


func cancel_targeting() -> void:
	if not _is_targeting():
		return
	manager.current_action = null
	_clear_current_target(false)
	manager._clear_all_targeting_ui()
	if manager.current_action_panel:
		manager.current_action_panel.hide()
	if manager.focused_button:
		manager.release_focused_button()
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


func _on_target_hovered(actor: BattleCombatant) -> void:
	if InputManager.get_active_mode() != InputManager.InputMode.KEYBOARD_MOUSE \
		or InputManager.get_presentation_mode() != InputManager.PresentationMode.POINTER \
		or not _is_targeting() \
		or not _is_valid_candidate(actor):
		return
	_set_current_target(actor)


func _on_target_unhovered(actor: BattleCombatant) -> void:
	if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and InputManager.get_presentation_mode() == InputManager.PresentationMode.POINTER \
		and actor == _current_target:
		_clear_current_target(true)


func _on_target_invalidated(actor: BattleCombatant) -> void:
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
	for candidate: BattleCombatant in _valid_targets():
		if group_targeting:
			_set_target_state(candidate, CombatantPresentation.TargetState.SELECTED)
		elif candidate != _current_target:
			_set_target_state(candidate, CombatantPresentation.TargetState.AVAILABLE)
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


func _valid_targets() -> Array[BattleCombatant]:
	var targets: Array[BattleCombatant] = []
	if not manager:
		return targets
	for actor: BattleCombatant in manager._all_combatants_with_presentations():
		if _is_presentation_visible(actor) \
			and actor.is_valid_target \
			and (not actor.is_defeated or _allows_defeated_target(actor)):
			targets.append(actor)
	return targets


func _allows_defeated_target(actor: BattleCombatant) -> bool:
	return actor is HeroCombatant \
		and manager.current_action != null \
		and manager.current_action.can_revive_targets


func _is_valid_candidate(target: BattleCombatant) -> bool:
	return is_instance_valid(target) \
		and target.is_inside_tree() \
		and target.is_valid_target \
		and _valid_targets().has(target)


func _target_origin(candidates: Array[BattleCombatant]) -> Vector2:
	if manager and is_instance_valid(manager.current_actor):
		return _target_position(manager.current_actor)
	return _target_position(candidates[0])


func _target_position(combatant: BattleCombatant) -> Vector2:
	var presentation := manager.presentation_for(combatant) if manager != null else null
	return presentation.get_target_screen_position() \
		if presentation != null else Vector2.ZERO


func _is_presentation_visible(combatant: BattleCombatant) -> bool:
	var presentation := manager.presentation_for(combatant) if manager != null else null
	return presentation != null and presentation.is_target_visible()


func _presentation_target_state(
	combatant: BattleCombatant,
) -> CombatantPresentation.TargetState:
	var presentation := manager.presentation_for(combatant) if manager != null else null
	return presentation.target_state \
		if presentation != null else CombatantPresentation.TargetState.NORMAL


func _set_target_state(
	combatant: BattleCombatant,
	state: CombatantPresentation.TargetState,
) -> void:
	var presentation := manager.presentation_for(combatant) if manager != null else null
	if presentation != null:
		presentation.set_target_presentation(state)


func _set_current_target(target: BattleCombatant) -> void:
	if not _is_valid_candidate(target):
		return
	if is_instance_valid(_current_target) and _current_target != target:
		if _is_group_targeting() and _is_valid_candidate(_current_target):
			_set_target_state(_current_target, CombatantPresentation.TargetState.SELECTED)
		else:
			_set_target_state(
				_current_target,
				CombatantPresentation.TargetState.AVAILABLE
				if _is_valid_candidate(_current_target)
				else CombatantPresentation.TargetState.NORMAL
			)
	_current_target = target
	_navigation_origin = target
	_set_target_state(target, CombatantPresentation.TargetState.SELECTED)
	if target is EnemyCombatant:
		_last_enemy_target = target as EnemyCombatant
	elif target is HeroCombatant:
		_last_hero_target = target as HeroCombatant
	_refresh_target_preview()


func _clear_current_target(retain_origin: bool) -> void:
	if is_instance_valid(_current_target):
		if _is_group_targeting() and _is_valid_candidate(_current_target):
			_set_target_state(_current_target, CombatantPresentation.TargetState.SELECTED)
		else:
			_set_target_state(
				_current_target,
				CombatantPresentation.TargetState.AVAILABLE
				if _is_valid_candidate(_current_target)
				else CombatantPresentation.TargetState.NORMAL
			)
		if retain_origin:
			_navigation_origin = _current_target
	_current_target = null
	if not retain_origin:
		_navigation_origin = null
	_refresh_target_preview()


func _refresh_target_preview() -> void:
	if manager and is_instance_valid(manager.current_actor) and manager.current_action:
		var preview_target: BattleCombatant = _current_target \
			if manager.action_uses_exact_selected_target(manager.current_action) \
			else null
		manager.refresh_current_action_presentation(preview_target)
		manager.preview_action_turn_order(manager.current_actor, manager.current_action, preview_target)


func _restore_remembered_target() -> void:
	var candidates := _valid_targets()
	if candidates.is_empty():
		_clear_current_target(false)
		return
	var remembered: BattleCombatant = _last_hero_target \
		if candidates[0] is HeroCombatant else _last_enemy_target
	_set_current_target(remembered if _is_valid_candidate(remembered) else candidates[0])


func _prune_target_memory() -> void:
	if _last_enemy_target != null \
		and (not is_instance_valid(_last_enemy_target) or not _is_valid_candidate(_last_enemy_target)):
		_last_enemy_target = null
	if _last_hero_target != null \
		and (not is_instance_valid(_last_hero_target) or not _is_valid_candidate(_last_hero_target)):
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

func setup_battle(
	encounter: Encounter,
	roster_override: Array[HeroData] = [],
	enemy_level_override: int = -1,
	seed_override: int = -1,
	rewards_enabled: bool = true,
	enemy_hp_multiplier: float = 1.0,
) -> void:
	manager.current_encounter = encounter
	manager.spawn_encounter(
		roster_override,
		enemy_level_override,
		seed_override,
		rewards_enabled,
		enemy_hp_multiplier,
	)

func _on_battle_ended(won: bool):
	battle_ended.emit(won)
