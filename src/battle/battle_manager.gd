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
@export var action_bar: Control

# --- Encounter Data Links ---
@export var hero_data_files: Array[HeroData] = []
@export var enemy_data_files: Array[EnemyData] = []

# --- Actor Tracking ---
var current_hero: HeroCard = null
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

	# We start by finding the first turn
	change_state(State.EXECUTING_ACTION) # "Pause" the game
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
		enemy_card.current_ct = randi_range(enemy_data.stats.speed / 5, enemy_data.stats.speed * 3)
		enemy_card.decide_intent(get_living_heroes())
		actor_list.append(enemy_card)
	print("Spawning complete.")

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
	if winner.is_in_group("player"):
		self.current_hero = winner
		change_state(State.EXECUTING_ACTION)
		await winner.on_turn_started()
		player_turn_started.emit(current_hero)
		await action_bar.slide_in()
		change_state(State.PLAYER_ACTION)
	else:
		self.current_hero = null
		change_state(State.ENEMY_ACTION)
		await winner.on_turn_started()
		await execute_enemy_turn(winner)
		await wait(0.5)
		find_and_start_next_turn()

func sort_actors_by_ct(a, b):
	var a_is_player = a.is_in_group("player")
	var b_is_player = b.is_in_group("player")

	if a_is_player and not b_is_player: return true
	if not a_is_player and b_is_player: return false
	return randf() > 0.5

func _on_actor_breached():
	print("\n New Queue: ")
	var new_projection = _run_ct_simulation()

	turn_order_updated.emit(new_projection)

func _on_actor_died(actor: ActorCard):
	print(actor.actor_name, " has died. Removing from actor_list.")

	# 1. Remove from the "master list"
	if actor_list.has(actor):
		actor_list.erase(actor)
	else:
		print("Error: Actor was not in actor_list.")

	# 2. Re-run the simulation to update the UI
	# This is the same logic from _on_actor_breached
	var new_projection = _run_ct_simulation()
	turn_order_updated.emit(new_projection)

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

	var new_projection = _run_ct_simulation()
	turn_order_updated.emit(new_projection)

	# 3. Check if the battle needs to "un-end"
	# (This is a future-proof check)

func _on_action_selected(action: Action):
	if current_state != State.PLAYER_ACTION: return

	self.selected_action = action
	var target_list = []
	match action.target_type:
		Action.TargetType.ONE_ENEMY, Action.TargetType.ENEMY_GROUP, Action.TargetType.ALL_ENEMIES:
			change_state(State.TARGETING_ENEMIES)
			target_list = get_living_enemies()
			if not target_list.is_empty():
				target_list[0].grab_focus()

		Action.TargetType.SELF, Action.TargetType.TEAM_MEMBER, Action.TargetType.TEAMMATE, Action.TargetType.TEAM, Action.TargetType.TEAMMATES_ONLY:
			change_state(State.TARGETING_TEAM)
			target_list = get_living_heroes()
			if not target_list.is_empty():
				target_list[0].grab_focus()

		_:
			push_error("Unknown target type! Canceling.")
			#_on_target_canceled()

func _on_hero_clicked(target_hero: HeroCard):
	if current_state != State.TARGETING_TEAM: return

	# 2. We have our action and our target!
	print("Target selected: ", target_hero.actor_name)
	change_state(State.EXECUTING_ACTION)

	# 3. Build the target list (this is the "confirmation" step)
	var targets_array = []
	match selected_action.target_type:
		Action.TargetType.TEAM_MEMBER:
			targets_array.append(target_hero)
		Action.TargetType.TEAM:
			targets_array = get_living_heroes()
		Action.TargetType.TEAMMATES_ONLY:
			for ally in get_living_heroes():
				if ally != current_hero:
					targets_array.append(ally)
		# (etc.)

	# 4. Call the "dumb" executor
	await execute_action(current_hero, selected_action, targets_array)

	# 5. Clean up and end the turn
	self.selected_action = null
	find_and_start_next_turn()

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

		Action.TargetType.ALL_ENEMIES:
			targets_array = enemy_area.get_children()

		Action.TargetType.ENEMY_GROUP:
			targets_array = get_adjacent_enemies(target_enemy)

	await execute_action(current_hero, selected_action, targets_array)
	current_hero.on_turn_ended()
	await wait(1.0)

	self.selected_action = null
	find_and_start_next_turn()

func get_adjacent_enemies(target_enemy: EnemyCard) -> Array:
	var all_enemies = enemy_area.get_children()
	var target_index = all_enemies.find(target_enemy)

	if target_index == -1:
		return [target_enemy] # Safety check

	var final_targets = [target_enemy]
	# Add left neighbor (if it exists)
	if target_index > 0:
		final_targets.append(all_enemies[target_index - 1])
	# Add right neighbor (if it exists)
	if target_index < all_enemies.size() - 1:
		final_targets.append(all_enemies[target_index + 1])

	return final_targets

func execute_action(actor: ActorCard, action: Action, targets: Array):
	var actor_name = actor.actor_name

	print(actor_name, " uses ", action.action_name)

	for effect in action.effects:
		await effect.execute(actor, targets, self, action)
	await _flush_all_health_animations()
	return

func execute_enemy_turn(enemy: EnemyCard):
	change_state(State.EXECUTING_ACTION)
	print("\n", enemy.actor_name, " is executing its turn!")
	await wait(1.0)

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

func _on_shift_button_pressed(direction: String):
	if current_state != State.PLAYER_ACTION: return

	if current_hero:
		change_state(State.EXECUTING_ACTION)
		await current_hero.shift_role(direction)
		change_state(State.PLAYER_ACTION)
		print("Shift complete. Returning to player's action.")

func _on_hero_role_shifted(hero_card: HeroCard):
	var new_role = hero_card.get_current_role()
	var action: Action = new_role.shift_action

	if not action:
		return

	if action.auto_target:
		print("Auto-executing shift action...")

		# Build the auto-target list
		var target_list = []
		match action.target_type:
			Action.TargetType.SELF:
				target_list.append(current_hero)
			Action.TargetType.ALL_ENEMIES:
				target_list = get_living_enemies()
			Action.TargetType.TEAM:
				target_list = get_living_heroes()
			# (etc. for other auto-types)

		await execute_action(current_hero, action, target_list)
		return # We're done, return to _on_shift_button_pressed

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

func wait(duration : float) -> void:
	var scaled_duration = duration / global_animation_speed
	await get_tree().create_timer(scaled_duration).timeout
