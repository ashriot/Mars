extends Node
class_name BattleManager

# --- State Machine ---
enum State { LOADING, PLAYER_ACTION, TARGETING_ENEMIES, TARGETING_TEAM, ENEMY_ACTION, EXECUTING_ACTION }
var current_state = State.LOADING

# --- Signals ---
signal player_turn_started(hero_card)
signal turn_order_updated(turn_queue_data)

@export_range(0.1, 5.0) var global_animation_speed: float = 1.0

# --- Scene Links ---
@export var hero_card_scene: PackedScene
@export var enemy_card_scene: PackedScene
@export var hero_area: Control
@export var enemy_area: Control
@export var action_bar: ActionBar

# --- Encounter Data Links ---
@export var hero_data_files: Array[HeroData] = []
@export var enemy_data_files: Array[EnemyData] = []

# --- Actor Tracking ---
var current_actor: ActorCard = null
var selected_action: Action = null
var actor_list: Array = [] # Renamed from turn_queue
var TARGET_CT: int = 5000 # Your CT target

func change_state(new_state):
	print("--- State Change: ", State.keys()[current_state], " > ", State.keys()[new_state], " ---")
	current_state = new_state

func _ready():
	randomize() # For tie-breakers
	await wait(0.5)
	action_bar.action_selected.connect(_on_action_selected)
	action_bar.shift_button_pressed.connect(_on_shift_button_pressed)

	spawn_encounter()

	change_state(State.EXECUTING_ACTION)
	await _apply_starting_passives()

	find_and_start_next_turn()

func spawn_encounter():
	print("Spawning encounter...")
	for hero_data in hero_data_files:
		var hero_card: HeroCard = hero_card_scene.instantiate()
		hero_area.add_child(hero_card)
		hero_card.setup(hero_data)
		hero_card.hero_clicked.connect(_on_hero_clicked)
		hero_card.actor_breached.connect(_on_actor_breached)
		hero_card.actor_defeated.connect(_on_actor_died)
		hero_card.actor_revived.connect(_on_actor_revived)
		hero_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		hero_card.current_ct = randi_range(hero_data.stats.speed / 5, hero_data.stats.speed * 3)
		hero_card.role_shifted.connect(_on_hero_role_shifted)
		actor_list.append(hero_card)

	for enemy_data in enemy_data_files:
		var enemy_card: EnemyCard = enemy_card_scene.instantiate()
		enemy_area.add_child(enemy_card)
		enemy_card.setup(enemy_data)
		enemy_card.enemy_clicked.connect(_on_enemy_clicked)
		enemy_card.actor_breached.connect(_on_actor_breached)
		enemy_card.actor_defeated.connect(_on_actor_died)
		enemy_card.actor_revived.connect(_on_actor_revived)
		enemy_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		enemy_card.current_ct = randi_range(enemy_data.stats.speed / 5, enemy_data.stats.speed * 3)
		actor_list.append(enemy_card)
		enemy_card.decide_intent(get_living_heroes())
	print("Spawning complete.")

func _apply_starting_passives() -> void:
	print("--- Applying Starting Passives ---")

	for actor in actor_list:
		if actor is HeroCard and not actor.is_defeated:
			await _apply_role_passive(actor)
	print("--- Starting Passives Applied ---")
	return

func _run_ct_simulation(num_turns := 7) -> Array:
	var projected_queue = []
	var relative_ticks = 0

	# 1. Create a "ghost" list so we don't mess with real data
	var sim_data = []
	for actor in actor_list:
		sim_data.append({
			"actor": actor,
			"ct": actor.current_ct # Copy the REAL, current CT
		})

	# 2. Run the simulation 'num_turns' times
	while projected_queue.size() < num_turns:
		var winner_dict = null
		var ticks_needed_for_winner = 999999

		# 3. Find the next winner in the "ghost" list
		for data in sim_data:
			var ct_needed = TARGET_CT - data.ct
			var ticks_needed = ceil(float(ct_needed) / data.actor.current_stats.speed)

			if ticks_needed < ticks_needed_for_winner:
				ticks_needed_for_winner = ticks_needed
				winner_dict = data
			elif ticks_needed == ticks_needed_for_winner:
				if sort_actors_by_ct(data.actor, winner_dict.actor):
					winner_dict = data

		if not winner_dict:
			break

		relative_ticks += ticks_needed_for_winner
		projected_queue.append({
			"actor": winner_dict.actor,
			"ticks_needed": relative_ticks # e.g., 0, 28, 48
		})

		for data in sim_data:
			data.ct += data.actor.current_stats.speed * ticks_needed_for_winner

		winner_dict.ct = 0

	return projected_queue

func find_and_start_next_turn():
	if current_actor:
		current_actor.highlight(false)

	var projection = _run_ct_simulation()

	if projection.is_empty():
		push_error("Error: No one can take a turn!")
		return

	# 2. Get the winner and the "time" that passed
	var first_turn_data = projection[0]
	var winner: ActorCard = first_turn_data.actor
	# This is the "real" time that passed since the last turn
	var real_ticks_passed = first_turn_data.ticks_needed

	# 3. "Fast-forward" the REAL game clock
	for actor in actor_list:
		actor.current_ct += actor.current_stats.speed * real_ticks_passed

	winner.current_ct = 0
	turn_order_updated.emit(projection)

	# 6. Start the winner's turn
	self.current_actor = winner
	if winner is HeroCard:
		change_state(State.EXECUTING_ACTION)
		if action_bar.sliding:
			await action_bar.slide_finished
		await winner.on_turn_started()
		player_turn_started.emit(current_actor)
		await action_bar.slide_in()
		change_state(State.PLAYER_ACTION)
	else:
		change_state(State.ENEMY_ACTION)
		await winner.on_turn_started()
		await execute_enemy_turn(winner)
		await winner.on_turn_ended()
		await wait(0.5)
		find_and_start_next_turn()

func sort_actors_by_ct(a, b):
	var a_is_player = a is HeroCard
	var b_is_player = b is HeroCard

	if a_is_player and not b_is_player: return true
	if not a_is_player and b_is_player: return false
	return randf() > 0.5

func _on_actor_breached():
	print("\n Actor was Breached -> New Queue: ")
	update_turn_order()

func update_turn_order():
	turn_order_updated.emit(_run_ct_simulation())

func _on_actor_died(actor: ActorCard):
	print(actor.actor_name, " has died. Removing from actor_list.")

	# 1. Remove from the "master list"
	if actor_list.has(actor):
		actor_list.erase(actor)
	else:
		print("Error: Actor was not in actor_list.")

	# 2. Re-run the simulation to update the UI
	# This is the same logic from _on_actor_breached
	update_turn_order()

	# 3. Check for victory/defeat
	if get_living_heroes().is_empty():
		print("--- GAME OVER ---")
		change_state(State.EXECUTING_ACTION) # (Or a new DEFEAT state)
	elif get_living_enemies().is_empty():
		print("--- VICTORY ---")
		change_state(State.EXECUTING_ACTION) # (Or a new VICTORY state)

func _on_actor_revived(actor: ActorCard):
	print(actor.name, " has revived! Adding back to actor_list.")

	if not actor_list.has(actor):
		actor_list.append(actor)
	else:
		print("Actor was already in actor_list?")

	update_turn_order()

	# 3. Check if the battle needs to "un-end"
	# (This is a future-proof check)

func _on_action_selected(action: Action):
	if current_state in [State.LOADING, State.EXECUTING_ACTION]: return

	if current_actor.current_focus_pips < action.focus_cost:
		return

	var target_list = []

	self.selected_action = action
	match action.target_type:
		Action.TargetType.ONE_ENEMY, Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			change_state(State.TARGETING_ENEMIES)
			target_list = get_living_enemies()

		Action.TargetType.SELF:
			change_state(State.TARGETING_TEAM)
			target_list = [current_actor]
		Action.TargetType.TEAM_MEMBER, Action.TargetType.TEAMMATE, Action.TargetType.TEAM, Action.TargetType.TEAMMATES_ONLY:
			change_state(State.TARGETING_TEAM)
			target_list = get_living_heroes()

		_:
			push_error("Unknown target type! Canceling.")

	for target in target_list:
		target.start_flashing()

func _on_hero_clicked(target_hero: HeroCard):
	if current_state != State.TARGETING_TEAM: return

	print("Target selected: ", target_hero.actor_name)
	change_state(State.EXECUTING_ACTION)
	action_bar.hide_bar()

	var targets_array = []
	match selected_action.target_type:
		Action.TargetType.SELF, Action.TargetType.TEAM_MEMBER:
			targets_array.append(target_hero)
		Action.TargetType.TEAM:
			targets_array = get_living_heroes()
		Action.TargetType.TEAMMATES_ONLY:
			for ally in get_living_heroes():
				if ally != current_actor:
					targets_array.append(ally)

	await execute_action(current_actor, selected_action, targets_array)
	await _finish_hero_turn()

func _on_enemy_clicked(target_enemy: EnemyCard):
	if current_state != State.TARGETING_ENEMIES: return

	if target_enemy.is_defeated:
			print("Target is already defeated.")
			return

	change_state(State.EXECUTING_ACTION)
	action_bar.hide_bar()

	var targets_array = []
	match selected_action.target_type:
		Action.TargetType.ONE_ENEMY:
			targets_array.append(target_enemy)

		Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			targets_array = enemy_area.get_children()

	await execute_action(current_actor, selected_action, targets_array)
	_finish_hero_turn()

func _finish_hero_turn():
	self.selected_action = null
	await current_actor.on_turn_ended()
	await wait(0.01)

	find_and_start_next_turn()

func _apply_role_passive(hero: HeroCard):
	var current_role = hero.get_current_role()
	if current_role and current_role.passive:
		var passive_action: Action = current_role.passive
		print("Applying passive: ", passive_action.action_name, " to ", hero.actor_name)
		await execute_action(hero, passive_action, [hero])

func execute_action(actor: ActorCard, action: Action, targets: Array):
	if actor is HeroCard:
		actor.spend_focus(action.focus_cost)
		_clear_all_targeting_ui()
	var actor_name = actor.actor_name
	print(actor_name, " uses ", action.action_name)

	for effect in action.effects:
		await effect.execute(actor, targets, self, action)
	if action.is_attack:
		var context = { "targets": targets, "action": action }
		await actor._fire_condition_event(Trigger.TriggerType.AFTER_ATTACKING, context)
	await _flush_all_health_animations()
	return

func execute_triggered_effect(actor: ActorCard, effect: ActionEffect, targets: Array, action: Action):

	await effect.execute(actor, targets, self, action)

func execute_enemy_turn(enemy: EnemyCard):
	change_state(State.EXECUTING_ACTION)
	print("\n", enemy.actor_name, " is executing its turn!")
	await wait(0.25)
	for i in range(2):
		await enemy.flash_intent(0.1)

	var action = enemy.intended_action
	var target = enemy.intended_target

	if not action:
		print(enemy.actor_name, " has no action to perform.")
		enemy.decide_intent(get_living_heroes())
		return

	var targets = []
	match action.target_type:
		Action.TargetType.ONE_ENEMY:
			if target and is_instance_valid(target):
				targets.append(target)
		Action.TargetType.ALL_ENEMIES:
			targets = get_living_heroes()
		Action.TargetType.SELF:
			targets.append(enemy)
	await execute_action(enemy, action, targets)
	enemy.decide_intent(get_living_heroes())
	return

func get_living_heroes() -> Array[HeroCard]:
	var living_heroes: Array[HeroCard] = []
	for hero_card in hero_area.get_children():
		if not hero_card.is_defeated:
			living_heroes.append(hero_card)
	return living_heroes

func get_living_enemies() -> Array[EnemyCard]:
	var living_enemies: Array[EnemyCard] = []
	for enemy_card in enemy_area.get_children():
		if not enemy_card.is_defeated:
			living_enemies.append(enemy_card)
	return living_enemies

func _on_actor_conditions_changed(_actor_who_changed: ActorCard, retarget: bool):
	var living_heroes = get_living_heroes()

	for enemy in get_living_enemies():
		if current_state == State.ENEMY_ACTION and enemy == current_actor:
			continue
		if retarget:
			enemy.get_a_target(living_heroes)
			enemy.flash_intent(0.3)

func _on_shift_button_pressed(direction: String):
	if current_state in [State.LOADING, State.EXECUTING_ACTION]: return
	selected_action = null
	if current_actor:
		change_state(State.EXECUTING_ACTION)
		await action_bar.slide_out()
		await current_actor.shift_role(direction)
		await action_bar.slide_in()
		change_state(State.PLAYER_ACTION)
		print("Shift complete. Returning to player's action.")

func _on_hero_role_shifted(hero_card: HeroCard):
	var new_role = hero_card.get_current_role()
	var action: Action = new_role.shift_action

	if not action:
		return

	if action.auto_target:
		print("Auto-executing shift action...")

		var target_list = []
		match action.target_type:
			Action.TargetType.SELF:
				target_list.append(current_actor)
			Action.TargetType.ALL_ENEMIES:
				target_list = get_living_enemies()
			Action.TargetType.TEAM:
				target_list = get_living_heroes()

		await execute_action(current_actor, action, target_list)
		return

	print("Action requires a target. Waiting for click...")
	_on_action_selected(action)

func _flush_all_health_animations() -> void:
	var tweens_to_await = []
	for actor in actor_list:
		var new_tween = actor.sync_visual_health()
		if new_tween:
			tweens_to_await.append(new_tween)

	if tweens_to_await.is_empty(): return
	print("flushing health animations")

	for tween in tweens_to_await:
		await tween.finished

func _clear_all_targeting_ui():
	for actor in actor_list:
		actor.stop_flashing()

func wait(duration : float) -> void:
	var scaled_duration = duration / global_animation_speed
	await get_tree().create_timer(scaled_duration).timeout
