extends ActorCard
class_name HeroCard

# --- UNIQUE Signals ---
signal hero_clicked(hero_card)
@warning_ignore("unused_signal")
signal passive_fired
signal focus_updated

# --- NEW: Animation Vars ---
@export var slide_offset_y: int = -30
@export var duration: float = 0.2

# --- UNIQUE UI Node References ---
@onready var focus_bar: HBoxContainer = $Panel/FocusBar
@onready var role_label: Label = $Panel/Role
@onready var role_icon: TextureRect = $Panel/RoleIcon

# --- UNIQUE Data ---
var hero_data: HeroData
var loaded_roles: Array[RoleData] = []
var current_role_index: int
var current_focus: int = 0
var shifted_this_turn: bool


func setup(data: HeroData):
	hero_data = data as HeroData
	hero_data.calculate_stats()
	_ensure_battle_manager()
	var model := BattleCombatant.new()
	add_child(model)
	model.setup_base(hero_data.stats, BattleCombatant.Faction.HERO, battle_manager)
	bind_combatant(model)
	current_role_index = hero_data.active_role_index
	if hero_data.portrait:
		portrait_rect.texture = hero_data.portrait

	loaded_roles.clear()
	for def in data.role_definitions:
		var role = data.get_battle_role(def.role_id)
		if role:
			loaded_roles.append(role)

	await _setup_card_visuals()

	# --- LOAD TRAITS ---
	active_traits.clear()
	if data.weapon and data.weapon.unique_trait:
		_add_trait(data.weapon.unique_trait, data.weapon.tier)
	if data.armor and data.armor.unique_trait:
		_add_trait(data.armor.unique_trait, data.armor.tier)

	duration /= battle_manager.battle_speed
	name_label.text = hero_data.stats.actor_name
	current_focus = hero_data.stats.starting_focus

	if hero_data.boon_focused:
		current_focus = clamp(current_focus + 5, 0, 10)
		print("Boon Applied: +5 Focus")
		hero_data.boon_focused = false

	if hero_data.boon_armored:
		current_guard = clamp(current_guard + 5, 0, 10)
		print("Boon Applied: +5 Guard")
		hero_data.boon_armored = false
		update_guard_bar(false)


	if hero_data.injuries > 0:
		var penalty_percent = 0.34 * hero_data.injuries
		penalty_percent = min(penalty_percent, 1.0)
		var penalty_amount = int(hero_data.stats.max_hp * penalty_percent)
		#hero_data.stats.max_hp = max(0, hero_data.stats.max_hp - penalty_amount)
		current_hp = max(0, hero_data.stats.max_hp - penalty_amount)
		print(hero_data.hero_name, " starts with Injury penalty!! HP: ", current_hp)
		if current_hp <= 0:
			current_hp = 0
			defeated()

	update_focus_bar(false)
	update_current_role()
	panel.self_modulate.a = 1.0

func on_turn_started() -> void:
	#if current_focus < 10:
		#modify_focus(1)
	shifted_this_turn = false
	await _slide_up()
	await battle_manager.action_bar.load_actions(self, false)
	await super.on_turn_started()
	if is_breached:
		recover_breach()
	return

func on_turn_ended() -> void:
	_slide_down()
	await super.on_turn_ended()

func take_healing(heal_amount: int, is_revive: bool = false):
	var was_defeated := is_defeated
	await super.take_healing(heal_amount, is_revive)
	if was_defeated and is_revive and heal_amount > 0 and current_hp > 0:
		combatant.revive()

func defeated():
	super.defeated()


func _show_defeated_visual(_immediate: bool = false) -> void:
	self_modulate.a = 0.25


func _show_revived_visual() -> void:
	print(actor_name, " is revived!")
	self_modulate = Color.WHITE

func get_current_role() -> RoleData:
	if loaded_roles.is_empty(): return null
	return loaded_roles[current_role_index]

func get_previous_role() -> RoleData:
	if loaded_roles.is_empty(): return null
	var prev_index = (current_role_index - 1 + loaded_roles.size()) % loaded_roles.size()
	return loaded_roles[prev_index]

func get_next_role() -> RoleData:
	if loaded_roles.is_empty(): return null
	var next_index = (current_role_index + 1) % loaded_roles.size()
	return loaded_roles[next_index]

func shift_role(direction: String):
	shifted_this_turn = true
	var role_count = hero_data.unlocked_role_ids.size()
	if role_count == 0: return

	if direction == "left":
		current_role_index = (current_role_index - 1 + role_count) % role_count
	else:
		current_role_index = (current_role_index + 1) % role_count
	update_current_role()
	await _fire_condition_event(Trigger.TriggerType.ON_SHIFT)

func update_current_role():
	role_label.text = get_current_role().role_name
	role_icon.texture = get_current_role().icon
	recolor()

func modify_focus(amount: int, context: Dictionary = {}) -> void:
	var paid_focus_cost := maxi(0, int(context.get("paid_focus_cost", -amount)))
	var is_zero_cost_action_payment := amount == 0 \
		and context.has("paid_focus_cost") \
		and context.has("action")
	var is_focus_spend := amount < 0 or is_zero_cost_action_payment
	var should_refund := is_focus_spend and active_conditions.any(
		func(condition: Condition) -> bool:
			return condition != null and condition.refund_focus_cost_on_spend
	)
	current_focus = clampi(current_focus + amount, 0, 10)
	update_focus_bar()
	focus_updated.emit()
	if is_focus_spend:
		var spend_context := context.duplicate(true)
		spend_context["paid_focus_cost"] = paid_focus_cost
		await _fire_condition_event(Trigger.TriggerType.ON_SPENDING_FOCUS, spend_context)
	if should_refund and paid_focus_cost > 0:
		await modify_focus(paid_focus_cost)

func update_focus_bar(animate: bool = true):
	var pips = focus_bar.get_children()

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_focus:
			if not pip_node.visible or pip_tweens.has(pip_node):
				_animate_pip_gain(pip_node, animate)
		elif pip_node.visible or pip_tweens.has(pip_node):
			_animate_pip_loss(pip_node, animate)

func get_scaled_focus_cost(cost: int) -> int:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar -= condition.focus_cost_reduction
	return int(cost * scalar)

func _add_trait(trait_res: Trait, tier: int):
	_require_combatant()._add_trait(trait_res, tier)
	print("Added Trait: ", trait_res.trait_name, " (Tier ", tier, ")")

func highlight(value: bool):
	highlight_panel.visible = value

func _slide_up():
	var tween = create_tween().set_parallel()
	tween.tween_property(
		panel,
		"position",
		panel_home_position + Vector2(0, slide_offset_y),
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "self_modulate:a", 1.0, duration)

func _slide_down():
	var tween = create_tween().set_parallel()
	tween.tween_property(
		panel,
		"position",
		panel_home_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "self_modulate:a", 1.0, duration)

func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		print("Clicked on: ", actor_name)
		hero_clicked.emit(self)
		get_viewport().set_input_as_handled()

func recolor():
	var color = get_current_role().color
	panel.self_modulate = color
	#$Panel/HP/HeartIcon.self_modulate = color
	#name_label.self_modulate = color
	role_label.self_modulate = color
	role_icon.self_modulate = color
	focus_bar.modulate = color
	guard_bar.modulate = color
	highlight_panel.modulate = Color.WHITE
