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
signal target_hovered(actor: ActorCard)
signal target_unhovered(actor: ActorCard)
signal target_invalidated(actor: ActorCard)

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
var executing_action: Action = null
var executing_action_ct_percent := 100
var executing_action_ends_turn := false
var focused_button: ActionButton = null
var actor_list: Array = []
var TARGET_CT: int = 4000
var battle_ct_speed_scale := 1.0
var force_enemy_level: int = -1
var current_encounter: Encounter
var encounter_seed := 0

func change_state(new_state):
	if current_state == State.BATTLE_OVER:
		print("Trying to change state when the battle has ended!")
		return
	print("--- State Change: ", State.keys()[current_state], " > ", State.keys()[new_state], " ---")
	current_state = new_state
	battle_state_changed.emit(current_state)

func _ready():
	UI.modulate.a = 0.0
	await wait(0.1)
	action_bar.action_selected.connect(_on_action_button_pressed)
	action_bar.shift_button_pressed.connect(_on_shift_button_pressed)
	current_action_panel.hide()

func spawn_encounter():
	print("Spawning encounter...")
	var fight_level = RunManager.current_dungeon_tier
	if force_enemy_level != -1: fight_level = force_enemy_level

	for hero_data in RunManager.party_roster:
		var hero_card: HeroCard = hero_card_scene.instantiate()
		hero_area.add_child(hero_card)
		hero_card.setup(hero_data)
		hero_card.hero_clicked.connect(_on_hero_clicked)
		hero_card.target_hovered.connect(_on_target_hovered)
		hero_card.target_unhovered.connect(_on_target_unhovered)
		hero_card.actor_breached.connect(_on_actor_breached)
		hero_card.actor_defeated.connect(_on_actor_died)
		hero_card.actor_revived.connect(_on_actor_revived)
		hero_card.spawn_particles.connect(_on_spawn_particles)
		hero_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		_connect_actor_intent_refresh_signals(hero_card)
		hero_card.current_ct = 0
		print(hero_card.actor_name, "'s CT: ", hero_card.current_ct)
		hero_card.battle_priority = actor_list.size()
		actor_list.append(hero_card)

	var spawned_enemies: Array[EnemyCard] = []
	var name_counts: Dictionary = {}

	var enemies_to_spawn = current_encounter.enemies
	var is_elite = current_encounter.is_elite
	var is_boss = current_encounter.is_boss

	for enemy_data in enemies_to_spawn:
		var enemy_card: EnemyCard = enemy_card_scene.instantiate()
		enemy_area.add_child(enemy_card)
		enemy_card.setup(enemy_data, fight_level, is_elite, is_boss)
		var base_name = enemy_card.actor_name
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		spawned_enemies.append(enemy_card)

		enemy_card.enemy_clicked.connect(_on_enemy_clicked)
		enemy_card.target_hovered.connect(_on_target_hovered)
		enemy_card.target_unhovered.connect(_on_target_unhovered)
		enemy_card.actor_breached.connect(_on_actor_breached)
		enemy_card.actor_defeated.connect(_on_actor_died)
		enemy_card.spawn_particles.connect(_on_spawn_particles)
		enemy_card.actor_conditions_changed.connect(_on_actor_conditions_changed)
		_connect_actor_intent_refresh_signals(enemy_card)
		enemy_card.current_ct = 0
		print(enemy_card.actor_name, "'s CT: ", enemy_card.current_ct)
		enemy_card.battle_priority = actor_list.size()
		enemy_card.initialize_ai(encounter_seed)
		actor_list.append(enemy_card)

	var current_indices = {}
	var suffixes = [" A", " B", " C", " D"]
	for enemy_card in spawned_enemies:
		var base_name = enemy_card.actor_name
		if name_counts[base_name] > 1:
			var idx = current_indices.get(base_name, 0)
			if idx < suffixes.size():
				var new_name = base_name + suffixes[idx]
				enemy_card.actor_name = new_name
				enemy_card.current_stats.actor_name = new_name
				enemy_card.name_label.text = new_name
				current_indices[base_name] = idx + 1

	_update_all_enemy_intents()

	print("Spawning complete.")
	change_state(State.LOADING)
	await _fade_in()
	await wait(0.25)
	await _flush_all_health_animations()
	await wait(0.5)
	await _apply_starting_passives()
	_finalize_initial_ai_timing()
	find_and_start_next_turn()

func _apply_starting_passives() -> void:
	print("--- Applying Starting Passives ---")

	for actor in actor_list:
		if actor is HeroCard and not actor.is_defeated:
			await _apply_role_passive(actor)
	print("--- Starting Passives Applied ---")
	return


func _configure_battle_ct_speed_scale() -> void:
	var raw_speeds: Array = []
	for actor: ActorCard in actor_list:
		if is_instance_valid(actor) and not actor.is_defeated:
			raw_speeds.append(maxi(actor.get_speed(), 1))
	battle_ct_speed_scale = CTBSpeed.scale_for(raw_speeds)
	for actor: ActorCard in actor_list:
		if is_instance_valid(actor):
			actor.ct_speed_scale = battle_ct_speed_scale


func _apply_initial_ct_head_starts(test_rolls: Array = []) -> void:
	for index in actor_list.size():
		var actor := actor_list[index] as ActorCard
		if not is_instance_valid(actor) or actor.is_defeated:
			continue
		var roll := float(test_rolls[index]) if index < test_rolls.size() else randf()
		actor.current_ct += CTBSpeed.head_start_ct(actor.get_ct_speed(), roll)


func _finalize_initial_ai_timing(head_start_rolls: Array = []) -> void:
	current_actor = null
	_configure_battle_ct_speed_scale()
	_apply_initial_ct_head_starts(head_start_rolls)
	_update_all_enemy_intents()

func _run_ct_simulation(num_turns := 10, ct_adjustments: Dictionary = {}) -> Array:
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
	executing_action = null
	_clear_executing_action_recovery()
	if current_state == State.BATTLE_OVER:
		return
	if current_actor:
		current_actor.highlight(false)
	change_state(State.LOADING)

	var projection := _run_ct_simulation()

	if projection.is_empty():
		push_error("Error: No one can take a turn!")
		return

	var first_turn_data = projection[0]
	var winner: ActorCard = first_turn_data.actor
	var real_ticks_passed = first_turn_data.ticks_needed

	for actor in actor_list:
		actor.current_ct += actor.get_ct_speed() * real_ticks_passed

	winner.current_ct = 0
	_update_all_enemy_intents()
	current_actor = winner
	_publish_turn_order(TurnOrderUpdate.ADVANCE)
	if winner is HeroCard:
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
		current_actor = null
		if await _check_if_battle_ended():
			return
		change_state(State.LOADING)
		_update_all_enemy_intents()
		await wait(0.5)
		find_and_start_next_turn()

func _on_actor_breached():
	print("\n Actor was Breached -> New Queue: ")
	update_turn_order()

func update_turn_order() -> void:
	_update_all_enemy_intents()
	_publish_turn_order(TurnOrderUpdate.REFRESH)


func _publish_turn_order(update_kind: TurnOrderUpdate) -> void:
	turn_order_updated.emit(_display_projection(), update_kind)

func get_action_recovery_adjustment(actor: ActorCard, action: Action) -> int:
	var percent := actor.get_action_ct_percent(action)
	return int(TARGET_CT * (100 - percent) / 100.0)

func _apply_executing_action_recovery(actor: ActorCard) -> void:
	if not executing_action_ends_turn:
		return
	actor.current_ct += int(TARGET_CT * (100 - executing_action_ct_percent) / 100.0)
	_clear_executing_action_recovery()
	update_turn_order()

func _clear_executing_action_recovery() -> void:
	executing_action_ct_percent = 100
	executing_action_ends_turn = false

func _enemy_ai_context() -> EnemyAIContext:
	var ticks := {}
	for actor: ActorCard in actor_list:
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
	if not is_instance_valid(hero_area) or not is_instance_valid(enemy_area):
		return
	var context := _enemy_ai_context()
	for enemy: EnemyCard in get_living_enemies():
		if enemy != current_actor or current_state != State.EXECUTING_ACTION:
			enemy.decide_intent(context)

func _on_actor_died(actor: ActorCard):
	print(actor.actor_name, " has died. Removing from actor_list.")
	actor.is_valid_target = false
	actor.set_target_presentation(ActorCard.TargetPresentation.NORMAL)

	if actor is HeroCard:
		actor.hero_data.injuries += 1
		print("Hero gained an injury. Total: ", actor.hero_data.injuries)

	actor_list.erase(actor)
	target_invalidated.emit(actor)
	if await _check_if_battle_ended():
		return
	update_turn_order()

func _on_actor_revived(actor: ActorCard):
	print(actor.name, " has revived! Adding back to actor_list.")

	if actor_list.has(actor):
		print("Actor was already in actor_list?")
		return
	actor.ct_speed_scale = battle_ct_speed_scale
	actor_list.append(actor)

	update_turn_order()

func set_current_action(action: Action):
	current_action = action
	current_action_panel.get_node("HBoxContainer/Mask/Icon").texture = current_action.icon
	refresh_current_action_presentation()
	var final_percent := current_actor.get_action_ct_percent(current_action)
	var ct_label := current_action_panel.get_node("HBoxContainer/CTPercent") as Label
	ct_label.text = "%d%% CT" % final_percent
	ct_label.add_theme_color_override(
		"font_color", _action_ct_color(current_action.ct_cost_percent, final_percent)
	)
	var hero := current_actor as HeroCard
	current_action_panel.modulate = Color.WHITE
	current_action_panel.get_node("HBoxContainer/Mask").self_modulate = (
		hero.get_current_role().color
	)
	current_action_panel.show()
	var targets := get_targets(action.target_type, true, [], null, action.can_revive_targets)
	_apply_target_presentation(action, targets)


func refresh_current_action_presentation(target: ActorCard = null) -> void:
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
	var presentation_target := target
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


func _apply_target_presentation(action: Action, targets: Array) -> void:
	var presentation := ActorCard.TargetPresentation.SELECTED \
		if is_group_target_action(action) \
		else ActorCard.TargetPresentation.AVAILABLE
	for target: ActorCard in targets:
		if not is_instance_valid(target):
			continue
		target.is_valid_target = true
		target.set_target_presentation(presentation)

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
	var is_shift_action = executing_action.is_shift_action
	if focused_button:
		release_focused_button()
	executing_action = null
	change_state(BattleManager.State.PLAYER_ACTION)
	if not is_shift_action:
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

func execute_action(actor: ActorCard, action: Action, targets: Array, display_name: bool = true, ends_turn: bool = false):
	var paid_focus_cost := action.focus_cost
	if actor is HeroCard:
		paid_focus_cost = (actor as HeroCard).get_scaled_focus_cost(action.focus_cost)
		if (actor as HeroCard).current_focus < paid_focus_cost:
			return
		await (actor as HeroCard).modify_focus(-paid_focus_cost)
	var action_context := {"paid_focus_cost": paid_focus_cost}
	var parent_targets = targets
	executing_action = action
	executing_action_ends_turn = ends_turn
	executing_action_ct_percent = actor.get_action_ct_percent(action) if ends_turn else 100
	if display_name:
		_publish_turn_order(TurnOrderUpdate.COMMIT)
	current_action = null
	if actor is HeroCard:
		current_action_panel.hide()
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
			var revives_defeated := effect is Effect_Healing and (effect as Effect_Healing).is_revive
			targets = get_targets(effect.target_type, actor is HeroCard, [], null, revives_defeated)
		else:
			if effect.target_type == Action.TargetType.SELF:
				targets = [current_actor]
			else:
				targets = parent_targets
		await effect.execute(actor, targets, self, action, action_context)
	if action.is_attack:
		var context = { "targets": targets, "action": action }
		await actor._fire_condition_event(Trigger.TriggerType.AFTER_ATTACKING, context)
		await _flush_all_health_animations()
	if display_name: await actor.hide_action()
	await _flush_all_health_animations()
	_apply_executing_action_recovery(actor)
	return

func execute_triggered_effect(actor: ActorCard, effect: ActionEffect, targets: Array, action: Action, context: Dictionary = {}):
	await effect.execute(actor, targets, self, action, context)

func execute_enemy_turn(enemy: EnemyCard) -> void:
	change_state(State.EXECUTING_ACTION)
	print("\n", enemy.actor_name, " is executing its turn!")
	var context := _enemy_ai_context()
	if not _is_enemy_decision_executable(enemy, context):
		enemy.decide_intent(context)
	if not _is_enemy_decision_executable(enemy, context):
		push_error("Enemy '%s' has no executable intent on AI turn %d after re-evaluation." % [
			enemy.actor_name, enemy.ai_state.completed_turns,
		])
		enemy.complete_ai_turn()
		_clear_executing_action_recovery()
		return

	var action := enemy.intended_action
	var targets := enemy.intended_targets

	if not action:
		push_error(enemy.actor_name, " is missing an action!")
		enemy.complete_ai_turn()
		_clear_executing_action_recovery()
		return

	var used_ability_id := enemy.intended_decision.ability.ability_id \
		if enemy.intended_decision.ability != null else &""
	enemy.show_action(action.action_name)
	await wait(0.5)
	await execute_action(enemy, action, targets, true, true)
	if current_state == State.BATTLE_OVER:
		return
	await wait(0.15)
	enemy.clear_intent()
	enemy.complete_ai_turn(used_ability_id)
	return


func _is_enemy_decision_executable(enemy: EnemyCard, context: EnemyAIContext) -> bool:
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
	var rule_index := ability.rules.find(rule)
	if rule_index < 0 or not rule.conditions.all(func(condition: EnemyDecisionCondition):
		return condition != null and condition.matches(enemy, enemy.ai_state, context)
	):
		return false
	var salt := "%s:%d" % [ability.ability_id, rule_index]
	return rule.selector.select(enemy, enemy.ai_state, context, salt) == decision.targets

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

func _connect_actor_intent_refresh_signals(actor: ActorCard) -> void:
	if not actor.hp_changed.is_connected(_on_actor_hp_changed):
		actor.hp_changed.connect(_on_actor_hp_changed)
	if not actor.armor_changed.is_connected(_on_actor_armor_changed):
		actor.armor_changed.connect(_on_actor_armor_changed)
	if actor is HeroCard and not (actor as HeroCard).focus_updated.is_connected(
		_on_hero_focus_updated
	):
		(actor as HeroCard).focus_updated.connect(_on_hero_focus_updated)


func _on_hero_focus_updated() -> void:
	_update_all_enemy_intents()


func _on_actor_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all_enemy_intents()


func _on_actor_armor_changed(_current_guard: int) -> void:
	_update_all_enemy_intents()


func _on_actor_conditions_changed() -> void:
	update_turn_order()

func _on_action_button_pressed(button: ActionButton):
	if current_state in [State.LOADING, State.FORCED_TARGET]: return

	var action = button.action
	if current_actor.current_focus < button.focus_cost:
		return

	AudioManager.play_sfx("terminal")
	preview_action_turn_order(current_actor, action)
	_focus_button(button)
	set_current_action(action)

func _on_hero_clicked(target_hero: HeroCard):
	if executing_action: return
	if not target_hero.is_valid_target: return

	print("Target selected: ", target_hero.actor_name)
	change_state(State.EXECUTING_ACTION)
	if not current_action.is_shift_action:
		action_bar.hide_bar()

	var target_list = [target_hero]
	await execute_action(current_actor, current_action, target_list, true, not current_action.is_shift_action)
	await _finish_hero_turn()

func _on_enemy_clicked(target_enemy: EnemyCard):
	if executing_action: return
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

	await execute_action(current_actor, current_action, targets_array, true, not current_action.is_shift_action)
	await _finish_hero_turn()

func _on_target_hovered(actor: ActorCard) -> void:
	target_hovered.emit(actor)


func _on_target_unhovered(actor: ActorCard) -> void:
	target_unhovered.emit(actor)

func _on_shift_button_pressed(direction: String):
	var current_hero = current_actor as HeroCard
	if current_state in [State.LOADING, State.FORCED_TARGET]: return
	_clear_all_targeting_ui()
	if focused_button:
		release_focused_button()
	if current_action_panel:
		current_action_panel.hide()
	change_state(State.LOADING)
	current_action = null
	AudioManager.play_sfx("radiate")
	await action_bar.slide_out()
	await current_actor.shift_role(direction)
	update_turn_order()
	action_bar.update_action_bar(current_hero, true)
	await action_bar.slide_in()
	await _apply_role_passive(current_hero)
	print("Shift complete. Returning to player's action.")
	if current_hero.get_current_role().shift_action:
		var action = current_hero.get_current_role().shift_action
		if action.auto_target:
			print("Auto-executing shift action...")
			var target_list = get_targets(
				action.target_type, true, [], null, action.can_revive_targets,
			)

			await execute_action(current_actor, action, target_list)
			change_state(State.PLAYER_ACTION)
			return

		change_state(State.FORCED_TARGET)
		print("Action requires a target. Waiting for click...")
		set_current_action(action)
	else:
		change_state(State.PLAYER_ACTION)

func get_targets(
	target_type: Action.TargetType,
	friendly: bool,
	parent_targets: Array = [],
	attacker: ActorCard = null,
	include_defeated_heroes: bool = false,
) -> Array:
	var enemies = []
	var heroes = []
	enemies = get_living_enemies()
	heroes = get_living_heroes()
	if include_defeated_heroes and is_instance_valid(hero_area):
		for child in hero_area.get_children():
			if child is HeroCard and not heroes.has(child):
				heroes.append(child)

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
	for actor in _all_actor_cards():
		var new_tween = actor.sync_visual_health()
		if new_tween:
			tweens_to_await.append(new_tween)

	if tweens_to_await.is_empty(): return
	print("flushing health animations")

	for tween in tweens_to_await:
		await tween.finished

func _clear_all_targeting_ui():
	for actor: ActorCard in _all_actor_cards():
		actor.is_valid_target = false
		actor.set_target_presentation(ActorCard.TargetPresentation.NORMAL)


func _all_actor_cards() -> Array[ActorCard]:
	var cards: Array[ActorCard] = []
	for area: Control in [hero_area, enemy_area]:
		if not is_instance_valid(area):
			continue
		for child in area.get_children():
			if child is ActorCard and not cards.has(child):
				cards.append(child)
	for actor in actor_list:
		if is_instance_valid(actor) and actor is ActorCard and not cards.has(actor):
			cards.append(actor)
	return cards

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

func preview_action_turn_order(actor: ActorCard, action: Action, selected_target: ActorCard = null) -> void:
	var adjustments: Dictionary = {}
	if not action.is_shift_action:
		adjustments[actor] = get_action_recovery_adjustment(actor, action)
	var primary_targets: Array = []
	if is_instance_valid(selected_target):
		primary_targets.append(selected_target)
	elif is_group_target_action(action):
		primary_targets = get_targets(
			action.target_type, actor is HeroCard, [], actor, action.can_revive_targets,
		)

	for effect: ActionEffect in action.effects:
		if not effect is Effect_ModifyCT:
			continue
		if effect.target_type == Action.TargetType.PARENT and primary_targets.is_empty():
			continue
		for target: ActorCard in get_targets(effect.target_type, actor is HeroCard, primary_targets, actor):
			adjustments[target] = int(adjustments.get(target, 0)) \
				+ int(TARGET_CT * effect.ct_change_percent)
	turn_order_updated.emit(_display_projection(adjustments), TurnOrderUpdate.PREVIEW)

func _get_effect_targets(effect: ActionEffect, user: ActorCard, selected_target: ActorCard = null) -> Array:
	"""Helper to resolve who an action will target"""
	match effect.target_type:
		Action.TargetType.SELF, Action.TargetType.ATTACKER:
			return [user]
		Action.TargetType.ONE_ENEMY:
			return [selected_target] if selected_target else []
		Action.TargetType.ALL_ENEMIES:
			return get_living_enemies()
		Action.TargetType.ALL_ALLIES:
			return get_living_heroes()
		_:
			return []

func _get_rich_description(action: Action, target: ActorCard = null) -> String:
	var presentation_target: ActorCard = null
	var presentation_targets: Array[ActorCard] = []
	if action_uses_exact_selected_target(action) \
		and is_instance_valid(target) \
		and target.current_stats != null:
		presentation_target = target
		presentation_targets.append(target)
	elif is_group_target_action(action):
		var resolved_targets := get_targets(
			action.target_type,
			current_actor is HeroCard,
			[],
			current_actor,
			action.can_revive_targets,
		)
		for resolved_target: ActorCard in resolved_targets:
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
	var heroes_alive = not get_living_heroes().is_empty()
	var enemies_alive = not get_living_enemies().is_empty()

	if not enemies_alive:
		_clear_executing_action_recovery()
		print("--- VICTORY ---")
		change_state(State.BATTLE_OVER)
		AudioManager.stop_music(1.0)
		action_bar.slide_out()
		var xp_reward = 150
		RunManager.add_run_xp(xp_reward)
		await wait(0.5)
		await _fade_out()
		battle_ended.emit(true)
		return true

	if not heroes_alive:
		_clear_executing_action_recovery()
		print("--- DEFEAT ---")
		change_state(State.BATTLE_OVER)
		AudioManager.stop_music(2.0)
		await wait(0.5)
		await _fade_out()
		await wait(2.0)
		battle_ended.emit(false) # Player Lost
		return true

	return false
