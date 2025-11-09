extends Node
class_name BattleManager

# --- State Machine ---
enum State { LOADING, PLAYER_ACTION, WAITING_FOR_TARGET, ENEMY_ACTION, EXECUTING_ACTION }
var current_state = State.LOADING

# --- Signals ---
signal player_turn_started(hero_card)
signal turn_order_updated(turn_queue_data)

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
var TARGET_CT: int = 1000 # Your CT target

func change_state(new_state):
	print("--- State Change: ", State.keys()[current_state], " > ", State.keys()[new_state], " ---")
	current_state = new_state

func _ready():
	randomize() # For tie-breakers
	await get_tree().create_timer(0.5).timeout
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
		hero_card.current_ct = randi_range(0, 400) # Give a random starting charge
		hero_card.role_shifted.connect(_on_hero_role_shifted)
		actor_list.append(hero_card)

	for enemy_data in enemy_data_files:
		var enemy_card: EnemyCard = enemy_card_scene.instantiate()
		enemy_area.add_child(enemy_card)
		enemy_card.setup(enemy_data)
		enemy_card.current_ct = randi_range(0, 400) # Give a random starting charge
		enemy_card.enemy_clicked.connect(_on_enemy_clicked)
		actor_list.append(enemy_card)
	print("Spawning complete.")

# Add this new function to BattleManager.gd
func project_turn_order(num_turns_to_project: int) -> Array:
	var projected_queue = [] # This is the list we will return

	# 1. Create a "simulation" list. We can't mess with the "real" actor_list.
	# We'll make an array of dictionaries to hold the "ghost" data.
	var sim_data = []
	for actor in actor_list:
		sim_data.append({
			"actor": actor, # A reference to the real actor
			"ct": actor.current_ct # A *copy* of their current CT
		})

	# 2. Run the simulation 10 times
	while projected_queue.size() < num_turns_to_project:
		# 3. Find the "next" winner in the simulation
		var winner_dict = null
		var ticks_needed_for_winner = 999999

		for data in sim_data:
			var ct_needed = TARGET_CT - data.ct
			if data.actor.current_stats.speed <= 0:
				continue

			var ticks_needed = ceil(float(ct_needed) / data.actor.current_stats.speed)

			if ticks_needed < ticks_needed_for_winner:
				ticks_needed_for_winner = ticks_needed
				winner_dict = data
			elif ticks_needed == ticks_needed_for_winner:
				# Tie-breaker (using your existing sort function)
				if sort_actors_by_ct(data.actor, winner_dict.actor):
					winner_dict = data

		# 4. If we can't find a winner (e.g., all speeds are 0), stop.
		if not winner_dict:
			break

		# 5. Add the winner to our projected list
		projected_queue.append(winner_dict.actor)

		# 6. "Fast-forward" the simulation clock
		for data in sim_data:
			data.ct += data.actor.current_stats.speed * ticks_needed_for_winner

		winner_dict.ct = 0

	# 8. Return the final, 10-turn projected list
	return projected_queue

func find_and_start_next_turn():
	var winner = null
	var ticks_needed_for_winner = 999999

	for actor in actor_list:
		var ct_needed = TARGET_CT - actor.current_ct
		if actor.current_stats.speed <= 0:
			continue

		var ticks_needed = ceil(float(ct_needed) / actor.current_stats.speed)

		if ticks_needed < ticks_needed_for_winner:
			ticks_needed_for_winner = ticks_needed
			winner = actor
		elif ticks_needed == ticks_needed_for_winner:
			if sort_actors_by_ct(actor, winner):
				winner = actor

	for actor in actor_list:
		actor.current_ct += actor.current_stats.speed * ticks_needed_for_winner

	var projected_queue = project_turn_order(10)
	turn_order_updated.emit(projected_queue)

	winner.current_ct = 0

	if winner.is_in_group("player"):
		self.current_hero = winner
		change_state(State.PLAYER_ACTION) # <-- CORRECT STATE
		player_turn_started.emit(current_hero)
	else:
		self.current_hero = null
		change_state(State.ENEMY_ACTION)
		await execute_enemy_turn(winner)
		find_and_start_next_turn()

# Tie-breaker function
func sort_actors_by_ct(a, b):
	var a_is_player = a.is_in_group("player")
	var b_is_player = b.is_in_group("player")

	if a_is_player and not b_is_player: return true
	if not a_is_player and b_is_player: return false
	return randf() > 0.5

func _on_action_selected(action: Action):
	if current_state != State.PLAYER_ACTION: return

	self.selected_action = action
	change_state(State.WAITING_FOR_TARGET)

func _on_enemy_clicked(target_enemy: EnemyCard):
	if current_state != State.WAITING_FOR_TARGET: return

	change_state(State.EXECUTING_ACTION)

	var targets_array = []
	match selected_action.target_type:
		Action.TargetType.ONE_ENEMY:
			targets_array.append(target_enemy)

		Action.TargetType.ALL_ENEMIES:
			targets_array = enemy_area.get_children()

		Action.TargetType.ENEMY_GROUP:
			targets_array = get_adjacent_enemies(target_enemy)

	await execute_action(current_hero, selected_action, targets_array)

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
	var actor_name = actor.current_stats.actor_name

	print(actor_name, " uses ", action.action_name)

	# Build target list if it's empty (for auto-actions)
	if targets.is_empty():
		match action.target_type:
			Action.TargetType.ALL_ENEMIES:
				if actor.is_in_group("player"):
					targets = enemy_area.get_children()
				else:
					targets = hero_area.get_children()
			Action.TargetType.SELF:
				targets.append(actor)
			# (Add more auto-target logic here)

	if targets.is_empty():
		print("Action has no targets.")
		return

	for target in targets:
		if target and is_instance_valid(target):
			await target.take_damage_from_action(action, actor)
		else:
			print("Target is invalid or null.")
	return

func execute_enemy_turn(enemy: EnemyCard):
	change_state(State.EXECUTING_ACTION)

	print("\n", enemy.enemy_data.stats.actor_name, " is thinking...")
	await get_tree().create_timer(0.5).timeout

	var action = enemy.get_next_action()
	if not action: return
	var targets = [] # We'll build this array

	# --- Enemy AI Target Logic ---
	match action.target_type:
		Action.TargetType.ONE_ENEMY:
			# TODO: Add real targeting logic
			if not hero_area.get_children().is_empty():
				targets.append(hero_area.get_child(0))
		Action.TargetType.ALL_ENEMIES:
			# "All Enemies" for an enemy means "All Heroes"
			targets = hero_area.get_children()
		Action.TargetType.SELF:
			targets.append(enemy)
	# --- End AI Target Logic ---

	await execute_action(enemy, action, targets)
	return

func _on_shift_button_pressed(direction: String):
	if current_state != State.PLAYER_ACTION: return # <-- CORRECT STATE

	if current_hero:
		change_state(State.EXECUTING_ACTION)
		await current_hero.shift_role(direction)
		change_state(State.PLAYER_ACTION) # <-- CORRECT STATE
		print("Shift complete. Returning to player's action.")

func _on_hero_role_shifted(hero_card: HeroCard):
	var new_role = hero_card.get_current_role()
	var action: Action = new_role.shift_action

	if not action:
		return

	var targets_array = []
	match action.target_type:
		Action.TargetType.ALL_ENEMIES:
			targets_array = enemy_area.get_children()
		Action.TargetType.SELF:
			targets_array.append(current_hero)
		Action.TargetType.ONE_ENEMY:
			# This is the logic we fixed: wait for a target
			print("Action requires a target. Waiting for click...")
			self.selected_action = action
			change_state(State.WAITING_FOR_TARGET)
			return # Exit the function, we're now waiting

	# If we're still here, it's an auto-execute action
	await execute_action(current_hero, action, targets_array)
	return
