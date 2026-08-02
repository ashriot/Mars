extends Node
class_name BattleManager

const CT_FASTER_COLOR := Color("67e88a")
const CT_SLOWER_COLOR := Color("f87171")
const FUTURE_TURN_DISPLAY_COUNT := 20

# --- State Machine ---
enum State { LOADING, PLAYER_ACTION, ENEMY_ACTION, EXECUTING_ACTION, FORCED_TARGET, BATTLE_OVER }
enum TurnOrderUpdate { REFRESH, PREVIEW, COMMIT, ADVANCE }
var current_state = State.LOADING

# --- Signals ---
signal turn_order_updated(projected_queue: Array, update_kind: TurnOrderUpdate)
signal battle_state_changed(new_state)
signal battle_ended(won)
signal target_hovered(combatant: BattleCombatant)
signal target_unhovered(combatant: BattleCombatant)
signal target_invalidated(combatant: BattleCombatant)

@export_range(0.1, 5.0) var battle_speed: float = 1.0

# --- Scene Links ---
@export_group("Scene Links")
@export var UI: Control
@export var fx_manager: FXManager
@export var hero_area: Node
@export var enemy_area: Node
@export var action_bar: ActionBar
@export var current_action_panel: PanelContainer
@export var combatant_root: Node
@export var battle_world: BattleWorld3D

@export_group("Packed Scenes")
@export var hero_view_scene: PackedScene
@export var enemy_view_scene: PackedScene

# --- Actor Tracking ---
var _current_actor_was_assigned := false
var current_actor: BattleCombatant:
	set(value):
		current_actor = value
		_current_actor_was_assigned = value != null
var current_action: Action = null
var executing_action: Action = null
var _pending_after_shift_action: HeroCombatant
var executing_action_ct_percent := 100
var executing_action_ends_turn := false
var focused_button: ActionButton = null
var actor_list: Array[BattleCombatant] = []
var TARGET_CT: int = 4000
var battle_ct_speed_scale := 1.0
var current_encounter: Encounter
var encounter_seed := 0
var rewards_enabled := true
var _combat_rng: RandomNumberGenerator
var _presentations: Dictionary = {}
var _presentation_view_roots: Dictionary = {}
var _presentation_exit_callbacks: Dictionary = {}
var _combatant_exit_callbacks: Dictionary = {}
var _canceling_active_actor_state := false
var _orchestration_generation := 0
var _orchestration_shutting_down := false
var _assigned_camera_rig: BattleCameraRig


func _capture_continuation(
	actor: BattleCombatant = null,
	action: Action = null,
) -> Dictionary:
	return {
		"generation": _orchestration_generation,
		"actor": actor,
		"action": action,
		"owns_current_actor": is_instance_valid(actor) and current_actor == actor,
	}


func _continuation_is_current(
	continuation: Dictionary,
	require_executing_action := false,
) -> bool:
	if _orchestration_shutting_down \
		or int(continuation.get("generation", -1)) != _orchestration_generation:
		return false
	var actor_value: Variant = continuation.get("actor")
	if actor_value != null:
		if not is_instance_valid(actor_value):
			return false
		if bool(continuation.get("owns_current_actor", false)) \
			and current_actor != actor_value:
			return false
	if require_executing_action:
		var action_value: Variant = continuation.get("action")
		if action_value != null and executing_action != action_value:
			return false
	return true


func _invalidate_orchestration(shutting_down := false) -> void:
	_orchestration_generation += 1
	if shutting_down:
		_orchestration_shutting_down = true


func register_presentation(
	combatant: BattleCombatant,
	presentation: CombatantPresentation,
) -> bool:
	return _register_presentation(combatant, presentation, null, false)


func _register_presentation(
	combatant: BattleCombatant,
	presentation: CombatantPresentation,
	view_root: Node,
	registers_exact_view_root: bool,
) -> bool:
	if not is_instance_valid(combatant):
		push_error("BattleManager cannot register an invalid combatant.")
		return false
	if not is_instance_valid(presentation):
		push_error("BattleManager cannot register an invalid presentation.")
		return false
	_prune_stale_presentations()
	for registered_combatant: Variant in _presentations:
		if registered_combatant != combatant \
			and _presentations.get(registered_combatant) == presentation:
			push_error(
				"CombatantPresentation is already registered to another combatant.",
			)
			return false
	if presentation.combatant != combatant:
		push_error(
			"CombatantPresentation is not bound to the requested combatant.",
		)
		return false
	var previous := presentation_for(combatant)
	var previous_state := CombatantPresentation.TargetState.NORMAL
	var previous_acting := false
	if previous != null:
		previous_state = previous.target_state
		previous_acting = previous.acting
	if previous != null and previous != presentation:
		previous.set_target_presentation(CombatantPresentation.TargetState.NORMAL)
		previous.set_acting(false)
		_disconnect_presentation(previous)
	_presentations[combatant] = presentation
	if previous != presentation:
		if registers_exact_view_root:
			_presentation_view_roots[combatant] = view_root
		else:
			_presentation_view_roots.erase(combatant)
	if not presentation.target_hovered.is_connected(_on_target_hovered):
		presentation.target_hovered.connect(_on_target_hovered)
	if not presentation.target_unhovered.is_connected(_on_target_unhovered):
		presentation.target_unhovered.connect(_on_target_unhovered)
	if not presentation.target_pressed.is_connected(_on_target_pressed):
		presentation.target_pressed.connect(_on_target_pressed)
	if not presentation.particles_requested.is_connected(_on_spawn_particles):
		presentation.particles_requested.connect(_on_spawn_particles)
	if not presentation.projectile_requested.is_connected(_on_projectile_requested):
		presentation.projectile_requested.connect(_on_projectile_requested)
	_connect_presentation_cleanup(combatant, presentation)
	presentation.set_target_presentation(previous_state)
	if previous != null and previous != presentation:
		presentation.set_acting(previous_acting)
		previous.cancel_pending_operations()
	return true


func presentation_for(combatant: BattleCombatant) -> CombatantPresentation:
	if not is_instance_valid(combatant):
		_prune_stale_presentations()
		return null
	var candidate: Variant = _presentations.get(combatant)
	if not is_instance_valid(candidate):
		_prune_stale_presentations()
		return null
	return candidate as CombatantPresentation


func has_active_battle_world() -> bool:
	return is_instance_valid(battle_world) \
		and battle_world.is_inside_tree() \
		and battle_world.visible


func presentation_uses_battle_world(combatant: BattleCombatant) -> bool:
	var view_root := presentation_view_root_for(combatant)
	return is_instance_valid(battle_world) \
		and is_instance_valid(view_root) \
		and battle_world.is_ancestor_of(view_root)


func presentation_view_root_for(combatant: BattleCombatant) -> Node:
	if not is_instance_valid(combatant):
		_prune_stale_presentations()
		return null
	var candidate: Variant = _presentation_view_roots.get(combatant)
	if not is_instance_valid(candidate):
		_presentation_view_roots.erase(combatant)
		return null
	return candidate as Node


func _prune_stale_presentations() -> void:
	for combatant_value: Variant in _presentations.keys():
		var presentation_value: Variant = _presentations.get(combatant_value)
		var combatant_is_valid := is_instance_valid(combatant_value)
		var presentation_is_valid := is_instance_valid(presentation_value)
		if combatant_is_valid and presentation_is_valid:
			continue
		if presentation_is_valid:
			var presentation := presentation_value as CombatantPresentation
			presentation.set_target_presentation(
				CombatantPresentation.TargetState.NORMAL,
			)
			presentation.set_acting(false)
			_disconnect_presentation(presentation)
		else:
			_presentation_exit_callbacks.erase(presentation_value)
		if not combatant_is_valid:
			_combatant_exit_callbacks.erase(combatant_value)
		_presentations.erase(combatant_value)
		_presentation_view_roots.erase(combatant_value)
		if combatant_is_valid:
			target_invalidated.emit(combatant_value as BattleCombatant)
		if presentation_is_valid and is_instance_valid(presentation_value):
			(presentation_value as CombatantPresentation).cancel_pending_operations()
	_prune_invalid_combatants()


func _prune_invalid_combatants() -> void:
	var removed_invalid_combatant := false
	for index in range(actor_list.size() - 1, -1, -1):
		if not is_instance_valid(actor_list[index]):
			actor_list.remove_at(index)
			removed_invalid_combatant = true
	for combatant_value: Variant in _combatant_exit_callbacks.keys():
		if not is_instance_valid(combatant_value):
			_combatant_exit_callbacks.erase(combatant_value)
			removed_invalid_combatant = true
	if _current_actor_was_assigned and not is_instance_valid(current_actor):
		var owned_active_state: bool = current_state in [
			State.PLAYER_ACTION,
			State.FORCED_TARGET,
			State.EXECUTING_ACTION,
		]
		var should_cancel_active_state: bool = owned_active_state \
			or current_action != null \
			or executing_action != null \
			or focused_button != null \
			or executing_action_ends_turn \
			or executing_action_ct_percent != 100
		current_actor = null
		if removed_invalid_combatant \
			and should_cancel_active_state \
			and not _canceling_active_actor_state:
			_cancel_active_actor_state()
	if not is_instance_valid(_pending_after_shift_action):
		_pending_after_shift_action = null


func unregister_presentation(combatant: BattleCombatant) -> void:
	if not _presentations.has(combatant):
		return
	var presentation := presentation_for(combatant)
	if not _presentations.has(combatant):
		return
	if presentation != null:
		presentation.set_target_presentation(CombatantPresentation.TargetState.NORMAL)
		presentation.set_acting(false)
		_disconnect_presentation(presentation)
	_presentations.erase(combatant)
	_presentation_view_roots.erase(combatant)
	target_invalidated.emit(combatant)
	if is_instance_valid(presentation):
		presentation.cancel_pending_operations()


func _disconnect_presentation(presentation: CombatantPresentation) -> void:
	if presentation.target_hovered.is_connected(_on_target_hovered):
		presentation.target_hovered.disconnect(_on_target_hovered)
	if presentation.target_unhovered.is_connected(_on_target_unhovered):
		presentation.target_unhovered.disconnect(_on_target_unhovered)
	if presentation.target_pressed.is_connected(_on_target_pressed):
		presentation.target_pressed.disconnect(_on_target_pressed)
	if presentation.particles_requested.is_connected(_on_spawn_particles):
		presentation.particles_requested.disconnect(_on_spawn_particles)
	if presentation.projectile_requested.is_connected(_on_projectile_requested):
		presentation.projectile_requested.disconnect(_on_projectile_requested)
	var exit_callback: Callable = _presentation_exit_callbacks.get(
		presentation, Callable(),
	)
	if exit_callback.is_valid() \
		and presentation.tree_exiting.is_connected(exit_callback):
		presentation.tree_exiting.disconnect(exit_callback)
	_presentation_exit_callbacks.erase(presentation)


func _connect_presentation_cleanup(
	combatant: BattleCombatant,
	presentation: CombatantPresentation,
) -> void:
	if _presentation_exit_callbacks.has(presentation):
		return
	var exit_callback := _on_presentation_tree_exiting.bind(
		combatant, presentation,
	)
	_presentation_exit_callbacks[presentation] = exit_callback
	presentation.tree_exiting.connect(exit_callback)


func _on_presentation_tree_exiting(
	combatant: BattleCombatant,
	presentation: CombatantPresentation,
) -> void:
	if _presentations.get(combatant) != presentation:
		return
	unregister_presentation(combatant)


func _connect_combatant_cleanup(combatant: BattleCombatant) -> void:
	if _combatant_exit_callbacks.has(combatant):
		return
	var exit_callback := _on_combatant_tree_exiting.bind(combatant)
	_combatant_exit_callbacks[combatant] = exit_callback
	combatant.tree_exiting.connect(exit_callback)


func _disconnect_combatant_cleanup(combatant: BattleCombatant) -> void:
	var exit_callback: Callable = _combatant_exit_callbacks.get(
		combatant, Callable(),
	)
	if exit_callback.is_valid() \
		and combatant.tree_exiting.is_connected(exit_callback):
		combatant.tree_exiting.disconnect(exit_callback)
	_combatant_exit_callbacks.erase(combatant)


func _on_combatant_tree_exiting(combatant: BattleCombatant) -> void:
	if current_actor == combatant:
		_cancel_active_actor_state(combatant)
	actor_list.erase(combatant)
	if _pending_after_shift_action == combatant:
		_pending_after_shift_action = null
	unregister_presentation(combatant)
	_disconnect_combatant_signals(combatant)
	if combatant.battle_manager == self:
		combatant.battle_manager = null


func _cancel_active_actor_state(combatant: BattleCombatant = null) -> void:
	if _canceling_active_actor_state:
		return
	_canceling_active_actor_state = true
	_invalidate_orchestration()
	_clear_all_targeting_ui()
	if focused_button:
		release_focused_button()
	current_action = null
	executing_action = null
	_clear_executing_action_recovery()
	if is_instance_valid(current_action_panel):
		current_action_panel.hide()
	if is_instance_valid(action_bar):
		action_bar.clear_active_hero()
	if _pending_after_shift_action == combatant:
		_pending_after_shift_action = null
	current_actor = null
	if current_state != State.BATTLE_OVER:
		change_state(State.LOADING)
	_canceling_active_actor_state = false


func _set_target_state(
	combatant: BattleCombatant,
	state: CombatantPresentation.TargetState,
) -> void:
	var presentation := presentation_for(combatant)
	if presentation != null:
		presentation.set_target_presentation(state)


func _set_actor_acting(combatant: BattleCombatant, active: bool) -> void:
	var presentation := presentation_for(combatant)
	if presentation != null:
		await _await_presentation_operation(presentation.set_acting(active))


func _await_presentation_operation(operation: PresentationOperation) -> void:
	if operation != null and not operation.is_completed:
		await operation.completed


func _show_action(combatant: BattleCombatant, action_name: String) -> void:
	var presentation := presentation_for(combatant)
	if presentation != null:
		presentation.show_action(action_name)


func _hide_action(combatant: BattleCombatant) -> void:
	var presentation := presentation_for(combatant)
	if presentation != null:
		await _await_presentation_operation(presentation.hide_action())

func change_state(new_state):
	if current_state == State.BATTLE_OVER:
		print("Trying to change state when the battle has ended!")
		return
	print("--- State Change: ", State.keys()[current_state], " > ", State.keys()[new_state], " ---")
	current_state = new_state
	battle_state_changed.emit(current_state)

func _ready():
	_configure_battle_feedback()
	var continuation := _capture_continuation()
	UI.modulate.a = 0.0
	await wait(0.1)
	if not _continuation_is_current(continuation):
		return
	action_bar.action_selected.connect(_on_action_button_pressed)
	action_bar.shift_button_pressed.connect(_on_shift_button_pressed)
	current_action_panel.hide()


func _exit_tree() -> void:
	_invalidate_orchestration(true)
	_clear_battle_feedback()
	_clear_all_targeting_ui()
	if is_instance_valid(action_bar):
		action_bar.clear_active_hero()
	for combatant: BattleCombatant in _presentations.keys():
		unregister_presentation(combatant)
	for combatant_value: Variant in _combatant_exit_callbacks.keys():
		if is_instance_valid(combatant_value):
			var combatant := combatant_value as BattleCombatant
			_disconnect_combatant_signals(combatant)
			if combatant.battle_manager == self:
				combatant.battle_manager = null
		else:
			_combatant_exit_callbacks.erase(combatant_value)


func _spawn_presentation_view(
	view_scene: PackedScene,
	view_parent: Node,
	combatant: BattleCombatant,
) -> CombatantPresentation:
	if view_scene == null:
		push_error("BattleManager cannot spawn a combatant view from a null scene.")
		return null
	if not is_instance_valid(view_parent):
		push_error("BattleManager cannot spawn a combatant view without a valid parent.")
		return null
	if not is_instance_valid(combatant):
		push_error("BattleManager cannot spawn a view for an invalid combatant.")
		return null
	var view_root := view_scene.instantiate()
	if view_root == null:
		push_error(
			"BattleManager could not instantiate combatant view '%s'." %
				view_scene.resource_path,
		)
		return null
	var presentations: Array[CombatantPresentation] = []
	_collect_presentations(view_root, presentations)
	if presentations.size() != 1:
		push_error(
			"Combatant view '%s' must contain exactly one CombatantPresentation; found %d." % [
			view_scene.resource_path if not view_scene.resource_path.is_empty() else view_root.name,
			presentations.size(),
		],
		)
		view_root.free()
		return null
	view_parent.add_child(view_root)
	var presentation := presentations[0]
	var setup_succeeded := presentation.setup_view(combatant)
	if not setup_succeeded:
		view_root.free()
		return null
	if presentation.combatant != combatant:
		push_error(
			"Combatant presentation setup did not bind the requested combatant.",
		)
		view_root.free()
		return null
	if not _register_presentation(combatant, presentation, view_root, true):
		view_root.free()
		return null
	return presentation


func _collect_presentations(
	node: Node,
	result: Array[CombatantPresentation],
) -> void:
	if node is CombatantPresentation:
		result.append(node as CombatantPresentation)
	for child: Node in node.get_children():
		_collect_presentations(child, result)


func _discard_encounter_spawn(combatants: Array[BattleCombatant]) -> void:
	for index in range(combatants.size() - 1, -1, -1):
		var combatant := combatants[index]
		if not is_instance_valid(combatant):
			continue
		var view_root := presentation_view_root_for(combatant)
		unregister_presentation(combatant)
		_disconnect_combatant_signals(combatant)
		actor_list.erase(combatant)
		if combatant.battle_manager == self:
			combatant.battle_manager = null
		if is_instance_valid(view_root):
			view_root.free()
		combatant.free()

func spawn_encounter(
	roster_override: Array[HeroData] = [],
	enemy_level_override: int = -1,
	seed_override: int = -1,
	allow_rewards: bool = true,
	enemy_hp_multiplier: float = 1.0,
) -> void:
	print("Spawning encounter...")
	var roster: Array[HeroData] = []
	roster.assign(
		roster_override if not roster_override.is_empty() else RunManager.party_roster
	)
	var fight_level := enemy_level_override \
		if enemy_level_override >= 0 else RunManager.current_dungeon_tier
	encounter_seed = seed_override \
		if seed_override >= 0 else RunManager.current_run_seed
	rewards_enabled = allow_rewards
	_configure_combat_rng(seed_override)

	assert(is_instance_valid(combatant_root), "BattleManager requires a combatant root.")
	var encounter_combatants: Array[BattleCombatant] = []
	for hero_data: HeroData in roster:
		var hero := HeroCombatant.new()
		combatant_root.add_child(hero)
		hero.setup(hero_data, self)
		hero.current_ct = 0
		hero.battle_priority = actor_list.size()
		actor_list.append(hero)
		encounter_combatants.append(hero)
		_connect_combatant_signals(hero)
		var presentation := _spawn_presentation_view(hero_view_scene, hero_area, hero)
		if presentation == null:
			_discard_encounter_spawn(encounter_combatants)
			return
		print(hero.actor_name, "'s CT: ", hero.current_ct)

	var spawned_enemies: Array[EnemyCombatant] = []
	var name_counts: Dictionary = {}

	var enemies_to_spawn = current_encounter.enemies
	var is_elite = current_encounter.is_elite
	var is_boss = current_encounter.is_boss

	for enemy_data: EnemyData in enemies_to_spawn:
		var enemy := EnemyCombatant.new()
		combatant_root.add_child(enemy)
		enemy.setup(
			enemy_data,
			fight_level,
			is_elite,
			is_boss,
			enemy_hp_multiplier,
			self,
		)
		var base_name := enemy.actor_name
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		enemy.current_ct = 0
		enemy.battle_priority = actor_list.size()
		actor_list.append(enemy)
		encounter_combatants.append(enemy)
		spawned_enemies.append(enemy)
		_connect_combatant_signals(enemy)
	if not spawned_enemies.is_empty() and not has_active_battle_world():
		push_error("BattleManager requires an active BattleWorld3D for enemy views.")
		_discard_encounter_spawn(encounter_combatants)
		return

	var current_indices = {}
	var suffixes = [" A", " B", " C", " D"]
	for enemy_index in spawned_enemies.size():
		var enemy := spawned_enemies[enemy_index]
		var base_name := enemy.actor_name
		if name_counts[base_name] > 1:
			var idx = current_indices.get(base_name, 0)
			if idx < suffixes.size():
				var new_name = base_name + suffixes[idx]
				enemy.actor_name = new_name
				enemy.current_stats.actor_name = new_name
				current_indices[base_name] = idx + 1
		if not has_active_battle_world():
			push_error("BattleManager requires an active BattleWorld3D for enemy views.")
			_discard_encounter_spawn(encounter_combatants)
			return
		var enemy_view_parent: Node = battle_world.enemy_views
		var presentation := _spawn_presentation_view(
			enemy_view_scene, enemy_view_parent, enemy,
		)
		if presentation == null:
			_discard_encounter_spawn(encounter_combatants)
			return
		if not has_active_battle_world():
			push_error("BattleManager requires an active BattleWorld3D for enemy views.")
			_discard_encounter_spawn(encounter_combatants)
			return
		var view_root := presentation_view_root_for(enemy) as Node3D
		if not is_instance_valid(view_root) \
			or not battle_world.place_ordinary_view(
				view_root,
				enemy_index,
				spawned_enemies.size(),
				current_encounter.enemy_formation,
			):
			push_error(
				"BattleManager could not place enemy view %d of %d in the battle world." % [
					enemy_index + 1, spawned_enemies.size(),
				],
			)
			_discard_encounter_spawn(encounter_combatants)
			return
		enemy.initialize_ai(encounter_seed)
		print(enemy.actor_name, "'s CT: ", enemy.current_ct)

	print("Spawning complete.")
	change_state(State.LOADING)
	var continuation := _capture_continuation()
	await _fade_in()
	if not _continuation_is_current(continuation):
		return
	await wait(0.25)
	if not _continuation_is_current(continuation):
		return
	await _flush_all_health_animations()
	if not _continuation_is_current(continuation):
		return
	await wait(0.5)
	if not _continuation_is_current(continuation):
		return
	await _apply_starting_passives()
	if not _continuation_is_current(continuation):
		return
	_finalize_initial_ai_timing()
	find_and_start_next_turn()

func _apply_starting_passives() -> void:
	print("--- Applying Starting Passives ---")
	_prune_invalid_combatants()
	var continuation := _capture_continuation()
	var starting_actors: Array[BattleCombatant] = actor_list.duplicate()
	for actor: BattleCombatant in starting_actors:
		if not _continuation_is_current(continuation):
			return
		if not is_instance_valid(actor):
			continue
		if actor is HeroCombatant and not actor.is_defeated:
			await _apply_role_passive(actor as HeroCombatant)
			if not _continuation_is_current(continuation):
				return
	print("--- Starting Passives Applied ---")
	return


func _configure_battle_ct_speed_scale() -> void:
	_prune_invalid_combatants()
	var raw_speeds: Array = []
	for actor: BattleCombatant in actor_list:
		if is_instance_valid(actor) and not actor.is_defeated:
			raw_speeds.append(maxi(actor.get_speed(), 1))
	battle_ct_speed_scale = CTBSpeed.scale_for(raw_speeds)
	for actor: BattleCombatant in actor_list:
		if is_instance_valid(actor):
			actor.ct_speed_scale = battle_ct_speed_scale


func _apply_initial_ct_head_starts(test_rolls: Array = []) -> void:
	_prune_invalid_combatants()
	for index in actor_list.size():
		var actor := actor_list[index]
		if not is_instance_valid(actor) or actor.is_defeated:
			continue
		var roll := float(test_rolls[index]) \
			if index < test_rolls.size() else combat_random_float()
		actor.current_ct += CTBSpeed.head_start_ct(actor.get_ct_speed(), roll)


func _configure_combat_rng(seed_override: int) -> void:
	if seed_override < 0:
		_combat_rng = null
		return
	_combat_rng = RandomNumberGenerator.new()
	_combat_rng.seed = seed_override


func has_local_combat_rng() -> bool:
	return _combat_rng != null


func combat_random_float() -> float:
	return _combat_rng.randf() if _combat_rng != null else randf()


func combat_roll_percent(chance: int) -> bool:
	var roll := _combat_rng.randi_range(1, 100) \
		if _combat_rng != null else randi_range(1, 100)
	return roll <= chance


func combat_random_actor(candidates: Array[BattleCombatant]) -> BattleCombatant:
	if candidates.is_empty():
		return null
	var index := _combat_rng.randi_range(0, candidates.size() - 1) \
		if _combat_rng != null else randi_range(0, candidates.size() - 1)
	return candidates[index]


func _award_victory_xp(amount: int) -> void:
	if rewards_enabled:
		RunManager.add_run_xp(amount)


func _finalize_initial_ai_timing(head_start_rolls: Array = []) -> void:
	_prune_invalid_combatants()
	current_actor = null
	_configure_battle_ct_speed_scale()
	_apply_initial_ct_head_starts(head_start_rolls)
	_update_all_enemy_intents()

func _run_ct_simulation(num_turns := 10, ct_adjustments: Dictionary = {}) -> Array:
	_prune_invalid_combatants()
	return CTBSimulator.project(actor_list, TARGET_CT, num_turns, ct_adjustments)


func _display_projection(
	ct_adjustments: Dictionary = {},
	count: int = FUTURE_TURN_DISPLAY_COUNT + 1,
) -> Array:
	var future_count := count - 1 if is_instance_valid(current_actor) else count
	var projection := _run_ct_simulation(future_count, ct_adjustments)
	if is_instance_valid(current_actor):
		projection.insert(0, {"actor": current_actor, "ticks_needed": 0})
	return projection

func find_and_start_next_turn():
	_prune_invalid_combatants()
	executing_action = null
	_clear_executing_action_recovery()
	if current_state == State.BATTLE_OVER:
		return
	var outgoing_actor := current_actor
	var continuation := _capture_continuation(outgoing_actor)
	if is_instance_valid(outgoing_actor):
		await _set_actor_acting(outgoing_actor, false)
		if not _continuation_is_current(continuation):
			return
	change_state(State.LOADING)

	var projection := _run_ct_simulation()

	if projection.is_empty():
		push_error("Error: No one can take a turn!")
		return

	var first_turn_data = projection[0]
	var winner := first_turn_data.actor as BattleCombatant
	var real_ticks_passed = first_turn_data.ticks_needed

	for actor: BattleCombatant in actor_list:
		if not is_instance_valid(actor):
			continue
		actor.current_ct += actor.get_ct_speed() * real_ticks_passed

	if not is_instance_valid(winner):
		return
	winner.current_ct = 0
	current_actor = winner
	continuation = _capture_continuation(winner)
	_publish_turn_order(TurnOrderUpdate.ADVANCE)
	await _set_actor_acting(winner, true)
	if not _continuation_is_current(continuation):
		return
	if winner is HeroCombatant:
		if action_bar.sliding:
			await action_bar.slide_finished
			if not _continuation_is_current(continuation):
				return
		change_state(State.PLAYER_ACTION)
		await winner.on_turn_started()
		if not _continuation_is_current(continuation):
			return
		await action_bar.load_actions(winner as HeroCombatant, false)
		if not _continuation_is_current(continuation):
			return
		await _flush_all_health_animations()
		if not _continuation_is_current(continuation):
			return
	else:
		change_state(State.ENEMY_ACTION)
		await winner.on_turn_started()
		if not _continuation_is_current(continuation):
			return
		await _flush_all_health_animations()
		if not _continuation_is_current(continuation):
			return
		await execute_enemy_turn(winner)
		if not _continuation_is_current(continuation):
			return
		await winner.on_turn_ended()
		if not _continuation_is_current(continuation):
			return
		await _set_actor_acting(winner, false)
		if not _continuation_is_current(continuation):
			return
		current_actor = null
		continuation = _capture_continuation(winner)
		if await _check_if_battle_ended():
			return
		if not _continuation_is_current(continuation):
			return
		change_state(State.LOADING)
		if is_instance_valid(winner) and not winner.is_defeated:
			(winner as EnemyCombatant).decide_intent(_enemy_ai_context())
		await wait(0.5)
		if not _continuation_is_current(continuation):
			return
		find_and_start_next_turn()

func _on_combatant_breached(breached: BattleCombatant) -> void:
	_prune_invalid_combatants()
	if not is_instance_valid(breached):
		return
	var continuation := _capture_continuation(breached)
	print("\n Actor was Breached -> New Queue: ")
	update_turn_order()
	if breached is EnemyCombatant \
		and (breached as EnemyCombatant).recover_action != null \
		and (breached != current_actor or current_state != State.EXECUTING_ACTION):
		(breached as EnemyCombatant).decide_intent(_enemy_ai_context())
	var observers: Array[BattleCombatant] = actor_list.duplicate()
	for observer: BattleCombatant in observers:
		if not is_instance_valid(observer):
			continue
		if observer.is_defeated or observer.faction == breached.faction:
			continue
		var observer_continuation := _capture_continuation(observer)
		await observer._fire_condition_event(
			Trigger.TriggerType.ON_ENEMY_BREACHED,
			{"target": breached, "targets": [breached]},
		)
		if not _continuation_is_current(continuation) \
			or not _continuation_is_current(observer_continuation):
			return

func update_turn_order() -> void:
	_publish_turn_order(TurnOrderUpdate.REFRESH)


func _publish_turn_order(update_kind: TurnOrderUpdate) -> void:
	turn_order_updated.emit(_display_projection(), update_kind)

func get_action_recovery_adjustment(actor: BattleCombatant, action: Action) -> int:
	var percent := actor.get_action_ct_percent(action)
	return int(TARGET_CT * (100 - percent) / 100.0)

func _apply_executing_action_recovery(actor: BattleCombatant) -> void:
	if not executing_action_ends_turn:
		return
	actor.current_ct += int(TARGET_CT * (100 - executing_action_ct_percent) / 100.0)
	_clear_executing_action_recovery()
	update_turn_order()

func _clear_executing_action_recovery() -> void:
	executing_action_ct_percent = 100
	executing_action_ends_turn = false

func _enemy_ai_context() -> EnemyAIContext:
	_prune_invalid_combatants()
	var ticks := {}
	for actor: BattleCombatant in actor_list:
		if not is_instance_valid(actor) or actor.is_defeated:
			continue
		ticks[actor] = maxi(
			ceili(float(TARGET_CT - actor.current_ct) / maxi(actor.get_ct_speed(), 1)),
			0,
		)
	return EnemyAIContext.new(
		get_living_heroes(), get_living_enemies(), ticks, encounter_seed,
	)


func _update_all_enemy_intents() -> void:
	var context := _enemy_ai_context()
	for enemy: EnemyCombatant in get_living_enemies():
		if enemy != current_actor or current_state != State.EXECUTING_ACTION:
			enemy.decide_intent(context)


func _revalidate_all_enemy_intent_targets() -> void:
	var planned_enemies: Array[EnemyCombatant] = []
	for enemy: EnemyCombatant in get_living_enemies():
		if enemy.intended_action != null:
			planned_enemies.append(enemy)
	if planned_enemies.is_empty():
		return
	var context := _enemy_ai_context()
	for enemy: EnemyCombatant in planned_enemies:
		enemy.revalidate_intent_targets(context)


func _refresh_all_enemy_intent_presentations() -> void:
	if not is_instance_valid(enemy_area):
		return
	for enemy: EnemyCombatant in get_living_enemies():
		var presentation := presentation_for(enemy)
		if presentation != null:
			presentation.refresh_intent()

func _on_actor_died(actor: BattleCombatant):
	if not is_instance_valid(actor):
		return
	var continuation := _capture_continuation(actor)
	print(actor.actor_name, " has died. Removing from actor_list.")
	actor.is_valid_target = false
	_set_target_state(actor, CombatantPresentation.TargetState.NORMAL)

	if actor is HeroCombatant:
		(actor as HeroCombatant).hero_data.injuries += 1
		print("Hero gained an injury. Total: ", (actor as HeroCombatant).hero_data.injuries)

	actor_list.erase(actor)
	target_invalidated.emit(actor)
	if await _check_if_battle_ended():
		return
	if not _continuation_is_current(continuation):
		return
	_revalidate_all_enemy_intent_targets()
	update_turn_order()

func _on_actor_revived(actor: BattleCombatant):
	_prune_invalid_combatants()
	if not is_instance_valid(actor):
		return
	print(actor.actor_name, " has revived! Adding back to actor_list.")

	if actor_list.has(actor):
		print("Actor was already in actor_list?")
		return
	actor.ct_speed_scale = battle_ct_speed_scale
	var insertion_index := actor_list.size()
	for index in actor_list.size():
		if actor.battle_priority < actor_list[index].battle_priority:
			insertion_index = index
			break
	actor_list.insert(insertion_index, actor)

	_revalidate_all_enemy_intent_targets()
	update_turn_order()

func set_current_action(action: Action):
	current_action = action
	current_action_panel.get_node("HBoxContainer/Mask/Icon").texture = current_action.icon
	refresh_current_action_presentation()
	var final_percent: int = current_actor.get_action_ct_percent(current_action)
	var ct_label := current_action_panel.get_node("HBoxContainer/CTPercent") as Label
	ct_label.text = "%d%% CT" % final_percent
	ct_label.add_theme_color_override(
		"font_color", _action_ct_color(current_action.ct_cost_percent, final_percent)
	)
	var hero := current_actor as HeroCombatant
	current_action_panel.modulate = Color.WHITE
	current_action_panel.get_node("HBoxContainer/Mask").self_modulate = (
		hero.get_current_role().color
	)
	current_action_panel.show()
	var targets: Array[BattleCombatant] = get_targets(
		action.target_type, true, [], null, action.can_revive_targets,
	)
	_apply_target_presentation(action, targets)


func refresh_current_action_presentation(target: BattleCombatant = null) -> void:
	if current_action == null \
		or not is_instance_valid(current_actor) \
		or current_actor.current_stats == null:
		return
	var panel_label: RichTextLabel = null
	if is_instance_valid(current_action_panel):
		panel_label = current_action_panel.get_node_or_null(
			"HBoxContainer/Label"
		) as RichTextLabel
	var selected_tooltip: RichTooltip = null
	if is_instance_valid(focused_button) \
		and focused_button.action == current_action \
		and focused_button.tooltip != null:
		selected_tooltip = focused_button.tooltip
	if panel_label == null and selected_tooltip == null:
		return
	var presentation_target: BattleCombatant = target
	if not is_instance_valid(presentation_target) \
		or presentation_target.current_stats == null:
		presentation_target = null
	var description := _get_rich_description(current_action, presentation_target)
	if panel_label != null:
		panel_label.text = description
	if selected_tooltip != null:
		selected_tooltip.bbcode_text = description


static func _action_ct_color(base_percent: int, final_percent: int) -> Color:
	if final_percent < base_percent:
		return CT_FASTER_COLOR
	if final_percent > base_percent:
		return CT_SLOWER_COLOR
	return Color.WHITE


func is_group_target_action(action: Action) -> bool:
	return action != null and action.target_type in [
		Action.TargetType.ALL_ENEMIES,
		Action.TargetType.ALL_ALLIES,
		Action.TargetType.ALLIES_ONLY,
	]


func action_uses_exact_selected_target(action: Action) -> bool:
	return action != null and action.target_type in [
		Action.TargetType.ONE_ENEMY,
		Action.TargetType.SELF,
		Action.TargetType.ONE_ALLY,
		Action.TargetType.ALLY_ONLY,
	]


func _apply_target_presentation(
	action: Action,
	targets: Array[BattleCombatant],
) -> void:
	var presentation := CombatantPresentation.TargetState.SELECTED \
		if is_group_target_action(action) \
		else CombatantPresentation.TargetState.AVAILABLE
	for target: BattleCombatant in targets:
		if not is_instance_valid(target):
			continue
		target.is_valid_target = true
		_set_target_state(target, presentation)

func _focus_button(button: ActionButton):
	if focused_button:
		_clear_all_targeting_ui()
		release_focused_button()
	focused_button = button
	focused_button.focused(true)


func release_focused_button() -> void:
	if not is_instance_valid(focused_button):
		focused_button = null
		return
	_reset_action_button_presentation(focused_button)
	focused_button.focused(false)
	focused_button = null


func _reset_action_button_presentation(button: ActionButton) -> void:
	if not is_instance_valid(button) \
		or button.action == null \
		or button.tooltip == null \
		or not is_instance_valid(current_actor) \
		or current_actor.current_stats == null:
		return
	button.tooltip.bbcode_text = _get_rich_description(button.action)


func _finish_hero_turn():
	if current_state == State.BATTLE_OVER:
		return
	var finished_actor := current_actor
	if not is_instance_valid(finished_actor) or not finished_actor is HeroCombatant:
		return
	var finished_action := executing_action
	var continuation := _capture_continuation(finished_actor, finished_action)
	var is_shift_action := finished_action != null and finished_action.is_shift_action
	if focused_button:
		release_focused_button()
	executing_action = null
	change_state(BattleManager.State.PLAYER_ACTION)
	if is_shift_action:
		await _finish_shift_reactions(finished_actor as HeroCombatant)
		if not _continuation_is_current(continuation):
			return
	else:
		await finished_actor.on_turn_ended()
		if not _continuation_is_current(continuation):
			return
		find_and_start_next_turn()
	await wait()
	if not _continuation_is_current(continuation):
		return


func _finish_shift_reactions(hero: HeroCombatant) -> void:
	if not is_instance_valid(hero) or _pending_after_shift_action != hero:
		return
	var continuation := _capture_continuation(hero)
	_pending_after_shift_action = null
	await hero._fire_condition_event(Trigger.TriggerType.AFTER_SHIFT_ACTION)
	if not _continuation_is_current(continuation):
		return
	update_turn_order()

func _apply_role_passive(hero: HeroCombatant):
	if not is_instance_valid(hero):
		return
	current_actor = hero
	var continuation := _capture_continuation(hero)
	var current_role = hero.get_current_role()
	if current_role and current_role.passive:
		var action: Action = current_role.passive
		continuation["action"] = action
		print("Applying passive: ", action.action_name, " to ", hero.actor_name)
		await execute_action(hero, action, [hero], false)
		if not _continuation_is_current(continuation, true):
			return
		if executing_action == action:
			executing_action = null

func execute_action(actor: BattleCombatant, action: Action, targets: Array[BattleCombatant], display_name: bool = true, ends_turn: bool = false):
	if not is_instance_valid(actor) or action == null:
		return
	var continuation := _capture_continuation(actor, action)
	var paid_focus_cost := action.focus_cost
	if actor is HeroCombatant:
		paid_focus_cost = (actor as HeroCombatant).get_scaled_focus_cost(action.focus_cost)
		if (actor as HeroCombatant).current_focus < paid_focus_cost:
			return
		await (actor as HeroCombatant).modify_focus(
			-paid_focus_cost,
			{"paid_focus_cost": paid_focus_cost, "action": action},
		)
		if not _continuation_is_current(continuation):
			return
	var action_context := {"paid_focus_cost": paid_focus_cost}
	var parent_targets: Array[BattleCombatant] = targets
	executing_action = action
	executing_action_ends_turn = ends_turn
	executing_action_ct_percent = actor.get_action_ct_percent(action) if ends_turn else 100
	if display_name:
		_publish_turn_order(TurnOrderUpdate.COMMIT)
	current_action = null
	if actor is HeroCombatant:
		current_action_panel.hide()
		_clear_all_targeting_ui()
		if display_name:
			_show_action(actor, action.action_name)
			await wait(0.25)
			if not _continuation_is_current(continuation, true):
				return
		if action.is_shift_action:
			action_bar.stop_flashing_panel()
	var actor_name = actor.actor_name
	print(actor_name, " uses ", action.action_name)

	for effect in action.effects:
		if not _continuation_is_current(continuation, true):
			return
		if effect.target_type in [Action.TargetType.ALL_ALLIES, Action.TargetType.ALL_ENEMIES, Action.TargetType.ALLIES_ONLY, Action.TargetType.LEAST_GUARD_ALLY, Action.TargetType.LEAST_FOCUS_ALLY]:
			var revives_defeated := effect is Effect_Healing and (effect as Effect_Healing).is_revive
			targets = get_targets(effect.target_type, actor is HeroCombatant, [], null, revives_defeated)
		else:
			if effect.target_type == Action.TargetType.SELF:
				targets = [actor]
			else:
				targets = parent_targets
		await effect.execute(actor, targets, self, action, action_context)
		if not _continuation_is_current(continuation, true):
			return
	if action.is_attack:
		var context = { "targets": targets, "action": action }
		await actor._fire_condition_event(Trigger.TriggerType.AFTER_ATTACKING, context)
		if not _continuation_is_current(continuation, true):
			return
		await _flush_all_health_animations()
		if not _continuation_is_current(continuation, true):
			return
	if display_name:
		await _hide_action(actor)
		if not _continuation_is_current(continuation, true):
			return
	await _flush_all_health_animations()
	if not _continuation_is_current(continuation, true):
		return
	_apply_executing_action_recovery(actor)
	return

func execute_triggered_effect(actor: BattleCombatant, effect: ActionEffect, targets: Array[BattleCombatant], action: Action, context: Dictionary = {}):
	if not is_instance_valid(actor) or effect == null:
		return
	var continuation := _capture_continuation(actor, action)
	await effect.execute(actor, targets, self, action, context)
	if not _continuation_is_current(continuation):
		return

func execute_enemy_turn(enemy: EnemyCombatant) -> void:
	if not is_instance_valid(enemy):
		return
	change_state(State.EXECUTING_ACTION)
	print("\n", enemy.actor_name, " is executing its turn!")
	var context := _enemy_ai_context()
	enemy.revalidate_intent_targets(context)
	if not _is_enemy_decision_executable(enemy, context):
		push_error("Enemy '%s' has no executable locked intent on AI turn %d." % [
			enemy.actor_name, enemy.ai_state.completed_turns,
		])
		enemy.clear_intent()
		enemy.complete_ai_turn()
		_clear_executing_action_recovery()
		return

	var action := enemy.intended_action
	var continuation := _capture_continuation(enemy, action)
	var targets: Array[BattleCombatant] = []
	targets.assign(enemy.intended_targets)

	if not action:
		push_error(enemy.actor_name, " is missing an action!")
		enemy.complete_ai_turn()
		_clear_executing_action_recovery()
		return

	executing_action = action
	var used_ability_id := enemy.intended_decision.ability.ability_id \
		if enemy.intended_decision.ability != null else &""
	_show_action(enemy, action.action_name)
	await wait(0.5)
	if not _continuation_is_current(continuation, true):
		return
	await execute_action(enemy, action, targets, true, true)
	if not _continuation_is_current(continuation, true):
		return
	if current_state == State.BATTLE_OVER:
		return
	await wait(0.15)
	if not _continuation_is_current(continuation, true):
		return
	enemy.clear_intent()
	enemy.complete_ai_turn(used_ability_id)
	return


func _is_enemy_decision_executable(enemy: EnemyCombatant, context: EnemyAIContext) -> bool:
	var decision := enemy.intended_decision
	if not decision.is_valid():
		return false
	if decision.is_recovery:
		return enemy.is_breached and decision.targets == [enemy]
	var ability := decision.ability
	var rule := decision.rule
	if ability == null or rule == null or rule.selector == null:
		return false
	if enemy.enemy_data == null or ability not in enemy.enemy_data.abilities:
		return false
	if decision.action != ability.action or not enemy.ai_state.is_ready(ability):
		return false
	if ability.rules.find(rule) < 0:
		return false
	return rule.selector.targets_are_legal(enemy, decision.targets, context)

func get_living_heroes() -> Array[HeroCombatant]:
	_prune_invalid_combatants()
	var living_heroes: Array[HeroCombatant] = []
	for actor: BattleCombatant in actor_list:
		if actor is HeroCombatant and not actor.is_defeated:
			living_heroes.append(actor as HeroCombatant)
	return living_heroes

func get_living_enemies() -> Array[EnemyCombatant]:
	_prune_invalid_combatants()
	var living_enemies: Array[EnemyCombatant] = []
	for actor: BattleCombatant in actor_list:
		if actor is EnemyCombatant and not actor.is_defeated:
			living_enemies.append(actor as EnemyCombatant)
	return living_enemies

func _connect_combatant_signals(actor: BattleCombatant) -> void:
	_connect_combatant_cleanup(actor)
	if not actor.hp_changed.is_connected(_on_actor_hp_changed):
		actor.hp_changed.connect(_on_actor_hp_changed)
	if not actor.guard_changed.is_connected(_on_actor_guard_changed):
		actor.guard_changed.connect(_on_actor_guard_changed)
	if not actor.conditions_changed.is_connected(_on_actor_conditions_changed):
		actor.conditions_changed.connect(_on_actor_conditions_changed)
	if not actor.defeated.is_connected(_on_actor_died):
		actor.defeated.connect(_on_actor_died)
	if not actor.revived.is_connected(_on_actor_revived):
		actor.revived.connect(_on_actor_revived)
	if not actor.presentation_event.is_connected(_on_combatant_feedback_event):
		actor.presentation_event.connect(_on_combatant_feedback_event)
	if actor is HeroCombatant and not (actor as HeroCombatant).focus_changed.is_connected(
		_on_hero_focus_updated
	):
		(actor as HeroCombatant).focus_changed.connect(_on_hero_focus_updated)


func _disconnect_combatant_signals(actor: BattleCombatant) -> void:
	if actor.hp_changed.is_connected(_on_actor_hp_changed):
		actor.hp_changed.disconnect(_on_actor_hp_changed)
	if actor.guard_changed.is_connected(_on_actor_guard_changed):
		actor.guard_changed.disconnect(_on_actor_guard_changed)
	if actor.conditions_changed.is_connected(_on_actor_conditions_changed):
		actor.conditions_changed.disconnect(_on_actor_conditions_changed)
	if actor.defeated.is_connected(_on_actor_died):
		actor.defeated.disconnect(_on_actor_died)
	if actor.revived.is_connected(_on_actor_revived):
		actor.revived.disconnect(_on_actor_revived)
	if actor.presentation_event.is_connected(_on_combatant_feedback_event):
		actor.presentation_event.disconnect(_on_combatant_feedback_event)
	if actor is HeroCombatant and (actor as HeroCombatant).focus_changed.is_connected(
		_on_hero_focus_updated
	):
		(actor as HeroCombatant).focus_changed.disconnect(_on_hero_focus_updated)
	_disconnect_combatant_cleanup(actor)


func _on_hero_focus_updated(_hero: HeroCombatant) -> void:
	_refresh_all_enemy_intent_presentations()


func _on_actor_hp_changed(
	_actor: BattleCombatant,
	_current_hp: int,
	_max_hp: int,
) -> void:
	_refresh_all_enemy_intent_presentations()


func _on_actor_guard_changed(
	_actor: BattleCombatant,
	_current_guard: int,
) -> void:
	_refresh_all_enemy_intent_presentations()


func _on_actor_conditions_changed(_actor: BattleCombatant) -> void:
	_revalidate_all_enemy_intent_targets()
	_refresh_all_enemy_intent_presentations()
	_publish_turn_order(TurnOrderUpdate.REFRESH)


func _on_combatant_feedback_event(
	actor: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	if event != &"impact" or not (actor is HeroCombatant):
		return
	if is_instance_valid(fx_manager):
		fx_manager.trigger_shake(float(payload.get("intensity", 0.5)))

func _on_action_button_pressed(button: ActionButton):
	if current_state in [State.LOADING, State.FORCED_TARGET]: return

	var action = button.action
	if current_actor.current_focus < button.focus_cost:
		return

	AudioManager.play_sfx("terminal")
	preview_action_turn_order(current_actor, action)
	_focus_button(button)
	set_current_action(action)

func _on_hero_clicked(target_hero: HeroCombatant):
	if executing_action: return
	if not target_hero.is_valid_target: return
	var actor := current_actor
	var action := current_action
	if not is_instance_valid(actor) or action == null:
		return
	var continuation := _capture_continuation(actor, action)

	print("Target selected: ", target_hero.actor_name)
	change_state(State.EXECUTING_ACTION)
	if not action.is_shift_action:
		action_bar.hide_bar()

	var target_list: Array[BattleCombatant] = [target_hero]
	await execute_action(actor, action, target_list, true, not action.is_shift_action)
	if not _continuation_is_current(continuation, true):
		return
	await _finish_hero_turn()
	if not _continuation_is_current(continuation):
		return

func _on_enemy_clicked(target_enemy: EnemyCombatant):
	if executing_action: return
	if not target_enemy.is_valid_target: return
	var actor := current_actor
	var action := current_action
	if not is_instance_valid(actor) or action == null:
		return
	var continuation := _capture_continuation(actor, action)

	if target_enemy.is_defeated:
			print("Target is already defeated.")
			return

	change_state(State.EXECUTING_ACTION)
	if not action.is_shift_action:
		action_bar.hide_bar()

	var targets_array: Array[BattleCombatant] = []

	match action.target_type:
		Action.TargetType.ONE_ENEMY:
			targets_array.append(target_enemy)

		Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			targets_array.assign(get_living_enemies())

	await execute_action(actor, action, targets_array, true, not action.is_shift_action)
	if not _continuation_is_current(continuation, true):
		return
	await _finish_hero_turn()
	if not _continuation_is_current(continuation):
		return

func _on_target_hovered(actor: BattleCombatant) -> void:
	target_hovered.emit(actor)


func _on_target_unhovered(actor: BattleCombatant) -> void:
	target_unhovered.emit(actor)


func _on_target_pressed(actor: BattleCombatant) -> void:
	if actor is HeroCombatant:
		_on_hero_clicked(actor as HeroCombatant)
	elif actor is EnemyCombatant:
		_on_enemy_clicked(actor as EnemyCombatant)

func _on_shift_button_pressed(direction: String):
	var current_hero := current_actor as HeroCombatant
	if current_state in [State.LOADING, State.FORCED_TARGET]: return
	if not is_instance_valid(current_hero):
		return
	var continuation := _capture_continuation(current_hero)
	_clear_all_targeting_ui()
	if focused_button:
		release_focused_button()
	if current_action_panel:
		current_action_panel.hide()
	change_state(State.LOADING)
	current_action = null
	AudioManager.play_sfx("radiate")
	await action_bar.slide_out()
	if not _continuation_is_current(continuation):
		return
	await current_hero.shift_role(direction)
	if not _continuation_is_current(continuation):
		return
	_pending_after_shift_action = current_hero
	update_turn_order()
	action_bar.update_action_bar(current_hero, true)
	await action_bar.slide_in()
	if not _continuation_is_current(continuation):
		return
	await _apply_role_passive(current_hero)
	if not _continuation_is_current(continuation):
		return
	print("Shift complete. Returning to player's action.")
	if current_hero.get_current_role().shift_action:
		var action = current_hero.get_current_role().shift_action
		if action.auto_target:
			print("Auto-executing shift action...")
			var target_list: Array[BattleCombatant] = get_targets(
				action.target_type, true, [], null, action.can_revive_targets,
			)

			continuation["action"] = action
			await execute_action(current_hero, action, target_list)
			if not _continuation_is_current(continuation, true):
				return
			if current_state == State.BATTLE_OVER:
				_pending_after_shift_action = null
				executing_action = null
				return
			await _finish_shift_reactions(current_hero)
			if not _continuation_is_current(continuation):
				return
			executing_action = null
			change_state(State.PLAYER_ACTION)
			return

		change_state(State.FORCED_TARGET)
		print("Action requires a target. Waiting for click...")
		set_current_action(action)
	else:
		await _finish_shift_reactions(current_hero)
		if not _continuation_is_current(continuation):
			return
		change_state(State.PLAYER_ACTION)

func get_targets(
	target_type: Action.TargetType,
	friendly: bool,
	parent_targets: Array[BattleCombatant] = [],
	attacker: BattleCombatant = null,
	include_defeated_heroes: bool = false,
) -> Array[BattleCombatant]:
	var enemies: Array[BattleCombatant] = []
	enemies.assign(get_living_enemies())
	var heroes: Array[BattleCombatant] = []
	heroes.assign(get_living_heroes())
	if include_defeated_heroes:
		for actor: BattleCombatant in _all_combatants_with_presentations():
			if actor is HeroCombatant and not heroes.has(actor):
				heroes.append(actor)

	var target_list: Array[BattleCombatant] = []
	match target_type:
		Action.TargetType.PARENT:
			target_list = parent_targets
		Action.TargetType.ATTACKER:
			target_list = [attacker]
		Action.TargetType.SELF:
			target_list.append(current_actor)
		Action.TargetType.ONE_ENEMY, Action.TargetType.RANDOM_ENEMY, Action.TargetType.ALL_ENEMIES:
			if friendly:
				target_list = enemies
			else:
				target_list = heroes
		Action.TargetType.ONE_ALLY, Action.TargetType.ALL_ALLIES:
			if friendly:
				target_list = heroes
			else:
				target_list = enemies
		Action.TargetType.ALLIES_ONLY, Action.TargetType.ALLY_ONLY:
			var allies: Array[BattleCombatant] = heroes if friendly else enemies
			for ally: BattleCombatant in allies:
				if ally != current_actor:
					target_list.append(ally)
		Action.TargetType.LEAST_GUARD_ALLY:
			var allies: Array[BattleCombatant] = heroes if friendly else enemies
			if allies.is_empty():
				push_error("No allies found!")
				return []
			var target_ally := allies[0] as BattleCombatant
			for ally: BattleCombatant in allies:
				if ally.current_guard < target_ally.current_guard:
					target_ally = ally
			target_list.append(target_ally)
		Action.TargetType.LEAST_FOCUS_ALLY:
			var allies: Array[BattleCombatant] = heroes if friendly else enemies
			if allies.is_empty():
				push_error("No allies found!")
				return []
			var target_ally := allies[0] as HeroCombatant
			for ally: BattleCombatant in allies:
				var hero_ally := ally as HeroCombatant
				if hero_ally.current_focus < target_ally.current_focus:
					target_ally = hero_ally
			target_list.append(target_ally)
		_:
			push_error("get_target() unknown target type!")
	return target_list

func _flush_all_health_animations() -> void:
	var continuation := _capture_continuation(current_actor, executing_action)
	var operations_to_await: Array[PresentationOperation] = []
	for actor: BattleCombatant in _all_combatants_with_presentations():
		var presentation := presentation_for(actor)
		if presentation != null:
			var operation: PresentationOperation = presentation.sync_visual_health()
			if operation != null and not operation.is_completed:
				operations_to_await.append(operation)

	if operations_to_await.is_empty(): return
	print("flushing health animations")

	for operation: PresentationOperation in operations_to_await:
		await _await_presentation_operation(operation)
		if not _continuation_is_current(continuation):
			return

func _clear_all_targeting_ui():
	for actor: BattleCombatant in _all_combatants_with_presentations():
		actor.is_valid_target = false
		_set_target_state(actor, CombatantPresentation.TargetState.NORMAL)


func _all_combatants_with_presentations() -> Array[BattleCombatant]:
	_prune_stale_presentations()
	var combatants: Array[BattleCombatant] = []
	for value: Variant in _presentations.keys():
		var actor := value as BattleCombatant
		if is_instance_valid(actor) and presentation_for(actor) != null:
			combatants.append(actor)
	return combatants

func _on_spawn_particles(pos: Vector2, _type: String):
	if not is_instance_valid(fx_manager):
		return
	fx_manager.play_hit_effect(pos, false)


func _on_projectile_requested(
	from_screen: Vector2,
	to_screen: Vector2,
	effect_type: StringName,
) -> void:
	if effect_type != &"laser" \
		or not has_active_battle_world() \
		or not is_instance_valid(battle_world.projectile_layer):
		return
	battle_world.projectile_layer.fire_laser(from_screen, to_screen, Color.CYAN)


func _configure_battle_feedback() -> void:
	_clear_battle_feedback()
	if not is_instance_valid(fx_manager) \
		or not is_instance_valid(battle_world) \
		or not is_instance_valid(battle_world.camera_rig):
		return
	_assigned_camera_rig = battle_world.camera_rig
	fx_manager.camera_rig = _assigned_camera_rig


func _clear_battle_feedback() -> void:
	if is_instance_valid(fx_manager) and fx_manager.camera_rig == _assigned_camera_rig:
		fx_manager.camera_rig = null
	_assigned_camera_rig = null

func wait(duration: float = 0.01) -> void:
	var scaled_duration = duration / battle_speed
	await get_tree().create_timer(scaled_duration).timeout

func _fade_in(duration: float = 0.5):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		UI,
		"modulate:a",
		1.0,
		duration
	)
	await tween.finished

func _fade_out(duration: float = 0.5):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		UI,
		"modulate:a",
		0.0,
		duration
	)
	await tween.finished

func preview_action_turn_order(actor: BattleCombatant, action: Action, selected_target: BattleCombatant = null) -> void:
	var adjustments: Dictionary = {}
	if not action.is_shift_action:
		adjustments[actor] = get_action_recovery_adjustment(actor, action)
	var primary_targets: Array[BattleCombatant] = []
	if is_instance_valid(selected_target):
		primary_targets.append(selected_target)
	elif is_group_target_action(action):
		primary_targets = get_targets(
			action.target_type, actor is HeroCombatant, [], actor, action.can_revive_targets,
		)

	for effect: ActionEffect in action.effects:
		if not effect is Effect_ModifyCT:
			continue
		if effect.target_type == Action.TargetType.PARENT and primary_targets.is_empty():
			continue
		for target: BattleCombatant in get_targets(effect.target_type, actor is HeroCombatant, primary_targets, actor):
			adjustments[target] = int(adjustments.get(target, 0)) \
				+ int(TARGET_CT * effect.ct_change_percent)
	turn_order_updated.emit(_display_projection(adjustments), TurnOrderUpdate.PREVIEW)

func _get_effect_targets(effect: ActionEffect, user: BattleCombatant, selected_target: BattleCombatant = null) -> Array[BattleCombatant]:
	"""Helper to resolve who an action will target"""
	match effect.target_type:
		Action.TargetType.SELF, Action.TargetType.ATTACKER:
			return [user]
		Action.TargetType.ONE_ENEMY:
			return [selected_target] if selected_target else []
		Action.TargetType.ALL_ENEMIES:
			var enemies: Array[BattleCombatant] = []
			enemies.assign(get_living_enemies())
			return enemies
		Action.TargetType.ALL_ALLIES:
			var heroes: Array[BattleCombatant] = []
			heroes.assign(get_living_heroes())
			return heroes
		_:
			return []

func _get_rich_description(action: Action, target: BattleCombatant = null) -> String:
	var presentation_target: BattleCombatant = null
	var presentation_targets: Array[BattleCombatant] = []
	if action_uses_exact_selected_target(action) \
		and is_instance_valid(target) \
		and target.current_stats != null:
		presentation_target = target
		presentation_targets.append(target)
	elif is_group_target_action(action):
		var resolved_targets: Array[BattleCombatant] = get_targets(
			action.target_type,
			current_actor is HeroCombatant,
			[],
			current_actor,
			action.can_revive_targets,
		)
		for resolved_target: BattleCombatant in resolved_targets:
			if is_instance_valid(resolved_target) \
				and resolved_target.current_stats != null:
				presentation_targets.append(resolved_target)
	return action.get_rich_description(
		current_actor,
		presentation_target,
		presentation_targets,
		self,
	)

func _check_if_battle_ended() -> bool:
	if current_state == State.BATTLE_OVER:
		return true
	var continuation := _capture_continuation(current_actor, executing_action)
	var heroes_alive = not get_living_heroes().is_empty()
	var enemies_alive = not get_living_enemies().is_empty()

	if not enemies_alive:
		_clear_executing_action_recovery()
		print("--- VICTORY ---")
		change_state(State.BATTLE_OVER)
		AudioManager.stop_music(1.0)
		action_bar.slide_out()
		var xp_reward = 150
		_award_victory_xp(xp_reward)
		await wait(0.5)
		if not _continuation_is_current(continuation):
			return false
		await _fade_out()
		if not _continuation_is_current(continuation):
			return false
		battle_ended.emit(true)
		return true

	if not heroes_alive:
		_clear_executing_action_recovery()
		print("--- DEFEAT ---")
		change_state(State.BATTLE_OVER)
		AudioManager.stop_music(2.0)
		await wait(0.5)
		if not _continuation_is_current(continuation):
			return false
		await _fade_out()
		if not _continuation_is_current(continuation):
			return false
		await wait(2.0)
		if not _continuation_is_current(continuation):
			return false
		battle_ended.emit(false) # Player Lost
		return true

	return false
