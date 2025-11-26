extends Node
class_name BattleManager

# --- State Machine ---
enum State { LOADING, PLAYER_ACTION, ENEMY_ACTION, EXECUTING_ACTION, FORCED_TARGET, BATTLE_OVER }
var current_state = State.LOADING

# --- Signals ---
signal turn_order_updated(turn_queue_data)
signal battle_state_changed(new_state)
signal battle_ended(won)

@export_range(0.1, 5.0) var battle_speed: float = 1.0

# --- Scene Links ---
@export_group("Scene Links")
@export var UI: Control
@export var fx_manager: FXManager
@export var hero_area: Control
@export var enemy_area: Control
@export var action_bar: ActionBar
@export var current_action_panel: PanelContainer

@export_group("Packed Scenes")
@export var hero_card_scene: PackedScene
@export var enemy_card_scene: PackedScene

# --- Encounter Data Links ---
@export var hero_data_files: Array[HeroData] = []

# --- Actor Tracking ---
var current_actor: ActorCard = null
var current_action: Action = null
var focused_button: ActionButton = null
var actor_list: Array = []
var TARGET_CT: int = 5000
var force_enemy_level: int = -1

func change_state(new_state):
	print("--- State Change: ", State.keys()[current_state], " > ", State.keys()[new_state], " ---")
	current_state = new_state
	battle_state_changed.emit(current_state)

func _ready():
	UI.modulate.a = 0.0
	await wait(0.1)
	action_bar.action_selected.connect(_on_action_button_pressed)
	action_bar.shift_button_pressed.connect(_on_shift_button_pressed)
	current_action_panel.hide()

func spawn_encounter(enemy_roster: Array[EnemyData]):
	print("Spawning encounter...")
	var fight_level = RunManager.current_dungeon_tier
	if force_enemy_level != -1:
		fight_level = force_enemy_level

	for hero_data in RunManager.party_roster:
		var hero_card: HeroCard = hero_card_scene.instantiate()
		hero_area.add_child(hero_card)
		hero_card.setup(hero_data)
		hero_card.hero_clicked.connect(_on_hero_clicked)
		hero_card.actor_breached.connect(_on_actor_breached)
		hero_card.actor_defeated.connect(_on_actor_died)
		hero_card.actor_revived.connect(_on_actor_revived)
		hero_card.spawn_particles.connect(_on_spawn_particles)
		hero_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		hero_card.current_ct = randi_range(0, hero_data.stats.speed * 5)
		actor_list.append(hero_card)

	for enemy_data in enemy_roster:
		var enemy_card: EnemyCard = enemy_card_scene.instantiate()
		enemy_area.add_child(enemy_card)
		enemy_card.setup(enemy_data, fight_level)
		enemy_card.enemy_clicked.connect(_on_enemy_clicked)
		enemy_card.actor_breached.connect(_on_actor_breached)
		enemy_card.actor_defeated.connect(_on_actor_died)
		enemy_card.actor_revived.connect(_on_actor_revived)
		enemy_card.spawn_particles.connect(_on_spawn_particles)
		enemy_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		enemy_card.current_ct = randi_range(0, enemy_data.stats.speed * 5)
		actor_list.append(enemy_card)
		enemy_card.prepare_turn_base_action()
	_update_all_enemy_intents()

	print("Spawning complete.")
	change_state(State.LOADING)
	await _fade_in()
	await wait(0.25)
	await _flush_all_health_animations()
	await wait(0.5)
	await _apply_starting_passives()
	find_and_start_next_turn()

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

	var sim_data = []
	for actor in actor_list:
		sim_data.append({
			"actor": actor,
			"ct": actor.current_ct # Copy the REAL, current CT
		})

	while projected_queue.size() < num_turns:
		var winner_dict = null
		var ticks_needed_for_winner = 999999

		# 3. Find the next winner in the "ghost" list
		for data in sim_data:
			var ct_needed = TARGET_CT - data.ct
			var ticks_needed = ceil(float(ct_needed) / data.actor.get_speed())

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
			data.ct += data.actor.get_speed() * ticks_needed_for_winner

		winner_dict.ct = 0

	return projected_queue

func find_and_start_next_turn():
	if current_state == State.BATTLE_OVER:
		return
	if current_actor:
		current_actor.highlight(false)

	var projection = _run_ct_simulation()

	if projection.is_empty():
		push_error("Error: No one can take a turn!")
		return

	var first_turn_data = projection[0]
	var winner: ActorCard = first_turn_data.actor
	var real_ticks_passed = first_turn_data.ticks_needed

	for actor in actor_list:
		actor.current_ct += actor.get_speed() * real_ticks_passed

	winner.current_ct = 0
	turn_order_updated.emit(projection)

	current_actor = winner
	if winner is HeroCard:
		change_state(State.LOADING)
		if action_bar.sliding:
			await action_bar.slide_finished
		change_state(State.PLAYER_ACTION)
		await winner.on_turn_started()
		await _flush_all_health_animations()
	else:
		change_state(State.ENEMY_ACTION)
		await winner.on_turn_started()
		await _flush_all_health_animations()
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

func _update_all_enemy_intents():
	if current_state == State.EXECUTING_ACTION:
		return
	var living_heroes = get_living_heroes()
	var living_enemies = get_living_enemies()
	for enemy in living_enemies:
		if enemy == current_actor: continue
		enemy.decide_intent(living_heroes)

func _on_actor_died(actor: ActorCard):
	print(actor.actor_name, " has died. Removing from actor_list.")

	if actor is HeroCard:
		actor.hero_data.injuries += 1
		print("Hero gained an injury. Total: ", actor.hero_data.injuries)

	actor_list.erase(actor)
	if await _check_if_battle_ended():
		return
	_update_all_enemy_intents()
	update_turn_order()

func _on_actor_revived(actor: ActorCard):
	print(actor.name, " has revived! Adding back to actor_list.")

	if not actor_list.has(actor):
		actor_list.append(actor)
	else:
		print("Actor was already in actor_list?")

	update_turn_order()

	# 3. Check if the battle needs to "un-end"
	# (This is a future-proof check)

func set_current_action(action: Action):
	current_action = action
	current_action_panel.get_node("HBoxContainer/Mask/Icon").texture = current_action.icon
	current_action_panel.get_node("HBoxContainer/Label").text = _get_rich_description(current_action)
	var hero = current_actor as HeroCard
	current_action_panel.modulate = hero.get_current_role().color
	current_action_panel.show()
	var target_list = get_targets(action.target_type, true)

	for target in target_list:
		target.start_flashing()

func _focus_button(button: ActionButton):
	if focused_button:
		focused_button.focused(false)
		_clear_all_targeting_ui()
		focused_button = null
	focused_button = button
	focused_button.focused(true)

func _finish_hero_turn():
	var is_shift_action = current_action.is_shift_action
	if focused_button:
		focused_button.focused(false)
		focused_button = null
	if not is_shift_action:
		current_action = null
		await current_actor.on_turn_ended()
		find_and_start_next_turn()
	await wait()

func _apply_role_passive(hero: HeroCard):
	current_actor = hero
	var current_role = hero.get_current_role()
	if current_role and current_role.passive:
		var action: Action = current_role.passive
		print("Applying passive: ", action.action_name, " to ", hero.actor_name)
		await execute_action(hero, action, [hero], false)

func execute_action(actor: ActorCard, action: Action, targets: Array, display_name: bool = true):
	var parent_targets = targets
	if actor is HeroCard:
		current_action_panel.hide()
		actor.modify_focus(-action.focus_cost)
		_clear_all_targeting_ui()
		if display_name:
			actor.show_action(action.action_name)
			await wait(0.25)
		if action.is_shift_action:
			action_bar.stop_flashing_panel()
	var actor_name = actor.actor_name
	print(actor_name, " uses ", action.action_name)

	for effect in action.effects:
		if effect.target_type in [Action.TargetType.ALL_ALLIES, Action.TargetType.ALL_ENEMIES, Action.TargetType.ALLIES_ONLY, Action.TargetType.LEAST_GUARD_ALLY, Action.TargetType.LEAST_FOCUS_ALLY]:
			targets = get_targets(effect.target_type, actor is HeroCard)
		else:
			if effect.target_type == Action.TargetType.SELF:
				targets = [current_actor]
			else:
				targets = parent_targets
		await effect.execute(actor, targets, self, action)
	if action.is_attack:
		var context = { "targets": targets, "action": action }
		await actor._fire_condition_event(Trigger.TriggerType.AFTER_ATTACKING, context)
		await _flush_all_health_animations()
	if display_name: await actor.hide_action()
	await _flush_all_health_animations()
	return

func execute_triggered_effect(actor: ActorCard, effect: ActionEffect, targets: Array, action: Action, context: Dictionary = {}):
	await effect.execute(actor, targets, self, action, context)

func execute_enemy_turn(enemy: EnemyCard):
	change_state(State.EXECUTING_ACTION)
	print("\n", enemy.actor_name, " is executing its turn!")
	var action = enemy.intended_action
	var targets = enemy.intended_targets
	enemy.show_action(action.action_name)
	await wait(0.5)

	if not action:
		push_error(enemy.actor_name, " is missing an action!")
		return

	await execute_action(enemy, action, targets)
	await wait(0.15)
	enemy.prepare_turn_base_action()
	_update_all_enemy_intents()
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

func _on_actor_conditions_changed():
	_update_all_enemy_intents()

func _on_action_button_pressed(button: ActionButton):
	if current_state in [State.LOADING, State.FORCED_TARGET]: return

	var action = button.action
	if current_actor.current_focus < button.focus_cost:
		return

	AudioManager.play_sfx("terminal")
	_focus_button(button)
	set_current_action(action)

func _on_hero_clicked(target_hero: HeroCard):
	if not target_hero.is_valid_target: return

	print("Target selected: ", target_hero.actor_name)
	change_state(State.EXECUTING_ACTION)
	if not current_action.is_shift_action:
		action_bar.hide_bar()

	var target_list = [target_hero]
	await execute_action(current_actor, current_action, target_list)
	await _finish_hero_turn()

func _on_enemy_clicked(target_enemy: EnemyCard):
	if not target_enemy.is_valid_target: return

	if target_enemy.is_defeated:
			print("Target is already defeated.")
			return

	change_state(State.EXECUTING_ACTION)
	if not current_action.is_shift_action:
		action_bar.hide_bar()

	var targets_array = []

	match current_action.target_type:
		Action.TargetType.ONE_ENEMY:
			targets_array.append(target_enemy)

		Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			targets_array = get_living_enemies()

	await execute_action(current_actor, current_action, targets_array)
	await _finish_hero_turn()

func _on_shift_button_pressed(direction: String):
	var current_hero = current_actor as HeroCard
	if current_state in [State.LOADING, State.FORCED_TARGET]: return
	_clear_all_targeting_ui()
	change_state(State.LOADING)
	current_action = null
	AudioManager.play_sfx("radiate")
	await action_bar.slide_out()
	await current_actor.shift_role(direction)
	action_bar.update_action_bar(current_hero, true)
	await action_bar.slide_in()
	await _apply_role_passive(current_hero)
	print("Shift complete. Returning to player's action.")
	if current_hero.get_current_role().shift_action:
		var action = current_hero.get_current_role().shift_action
		if action.auto_target:
			print("Auto-executing shift action...")
			var target_list = get_targets(action.target_type, true)

			await execute_action(current_actor, action, target_list)
			change_state(State.PLAYER_ACTION)
			return

		change_state(State.FORCED_TARGET)
		print("Action requires a target. Waiting for click...")
		set_current_action(action)
	else:
		change_state(State.PLAYER_ACTION)

func get_targets(target_type: Action.TargetType, friendly: bool, parent_targets: Array = [], attacker: ActorCard = null) -> Array:
	var enemies = []
	var heroes = []
	enemies = get_living_enemies()
	heroes = get_living_heroes()

	var target_list = []
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
			var allies = []
			if friendly:
				allies = heroes
			else:
				allies = enemies
			for ally in allies:
				if ally != current_actor:
					target_list.append(ally)
		Action.TargetType.LEAST_GUARD_ALLY:
			var allies = []
			if friendly:
				allies = heroes
			else:
				allies = enemies
			if allies.is_empty():
				push_error("No allies found!")
				return []
			var target_ally: ActorCard = allies[0]
			for ally in allies:
				if ally.current_guard < target_ally.current_guard:
					target_ally = ally
			target_list.append(target_ally)
		Action.TargetType.LEAST_FOCUS_ALLY:
			var allies = []
			if friendly:
				allies = heroes
			else:
				allies = enemies
			if allies.is_empty():
				push_error("No allies found!")
				return []
			var target_ally: ActorCard = allies[0]
			for ally in allies:
				if ally.current_focus < target_ally.current_focus:
					target_ally = ally
			target_list.append(target_ally)
		_:
			push_error("get_target() unknown target type!")
	return target_list

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

func _on_spawn_particles(pos: Vector2, _type: String):
	fx_manager.play_hit_effect(pos, false)

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

func _get_rich_description(action: Action) -> String:
	var hero = current_actor as HeroCard
	var description = action.get_rich_description(hero)

	return description

func _check_if_battle_ended() -> bool:
	var heroes_alive = not get_living_heroes().is_empty()
	var enemies_alive = not get_living_enemies().is_empty()

	if not enemies_alive:
		print("--- VICTORY ---")
		change_state(State.BATTLE_OVER)
		action_bar.slide_out()
		await wait(2.0)
		var xp_reward = 150
		RunManager.add_run_xp(xp_reward)
		battle_ended.emit(true)
		return true

	if not heroes_alive:
		print("--- DEFEAT ---")
		change_state(State.BATTLE_OVER)
		await wait(2.0)
		battle_ended.emit(false) # Player Lost
		return true

	return false
