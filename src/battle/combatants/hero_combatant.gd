extends BattleCombatant
class_name HeroCombatant

signal focus_changed(hero: HeroCombatant)

const MAX_FOCUS := 10

var hero_data: HeroData
var loaded_roles: Array[RoleData] = []
var current_role_index := 0
var current_focus := 0
var shifted_this_turn := false


func setup(data: HeroData, manager: BattleManager = null) -> void:
	assert(data != null, "HeroCombatant requires HeroData.")
	hero_data = data
	hero_data.calculate_stats()
	setup_base(hero_data.stats, Faction.HERO, manager)
	current_role_index = hero_data.active_role_index
	loaded_roles.clear()
	for definition: RoleDefinition in data.role_definitions:
		var role := data.get_battle_role(definition.role_id)
		if role != null:
			loaded_roles.append(role)

	active_traits.clear()
	if data.weapon != null and data.weapon.unique_trait != null:
		_add_trait(data.weapon.unique_trait, data.weapon.tier)
	if data.armor != null and data.armor.unique_trait != null:
		_add_trait(data.armor.unique_trait, data.armor.tier)

	current_focus = hero_data.stats.starting_focus
	if hero_data.boon_focused:
		current_focus = clampi(current_focus + 5, 0, MAX_FOCUS)
		print("Boon Applied: +5 Focus")
		hero_data.boon_focused = false
	if hero_data.boon_armored:
		current_guard = clampi(current_guard + 5, 0, MAX_GUARD)
		print("Boon Applied: +5 Guard")
		hero_data.boon_armored = false

	if hero_data.injuries > 0:
		var penalty_percent := minf(0.34 * hero_data.injuries, 1.0)
		var penalty_amount := int(hero_data.stats.max_hp * penalty_percent)
		current_hp = maxi(0, hero_data.stats.max_hp - penalty_amount)
		print(hero_data.hero_name, " starts with Injury penalty!! HP: ", current_hp)
		if current_hp <= 0:
			current_hp = 0
			defeat()


func get_current_role() -> RoleData:
	if loaded_roles.is_empty():
		return null
	return loaded_roles[current_role_index]


func get_previous_role() -> RoleData:
	if loaded_roles.is_empty():
		return null
	var previous_index := (
		current_role_index - 1 + loaded_roles.size()
	) % loaded_roles.size()
	return loaded_roles[previous_index]


func get_next_role() -> RoleData:
	if loaded_roles.is_empty():
		return null
	var next_index := (current_role_index + 1) % loaded_roles.size()
	return loaded_roles[next_index]


func shift_role(direction: String) -> void:
	shifted_this_turn = true
	var role_count := hero_data.unlocked_role_ids.size()
	if role_count == 0:
		return
	if direction == "left":
		current_role_index = (current_role_index - 1 + role_count) % role_count
	else:
		current_role_index = (current_role_index + 1) % role_count
	presentation_event.emit(self, &"role_changed", {})
	await _fire_condition_event(Trigger.TriggerType.ON_SHIFT)


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
	current_focus = clampi(current_focus + amount, 0, MAX_FOCUS)
	focus_changed.emit(self)
	presentation_event.emit(self, &"focus_changed", {"amount": amount})
	if is_focus_spend:
		var spend_context := context.duplicate(true)
		spend_context["paid_focus_cost"] = paid_focus_cost
		await _fire_condition_event(Trigger.TriggerType.ON_SPENDING_FOCUS, spend_context)
	if should_refund and paid_focus_cost > 0:
		await modify_focus(paid_focus_cost)


func get_scaled_focus_cost(cost: int) -> int:
	var scalar := 1.0
	for condition: Condition in active_conditions:
		scalar -= condition.focus_cost_reduction
	return int(cost * scalar)


func take_healing(heal_amount: int, is_revive: bool = false) -> void:
	var was_defeated := is_defeated
	await super.take_healing(heal_amount, is_revive)
	if was_defeated and is_revive and heal_amount > 0 and current_hp > 0:
		revive()


func defeat() -> void:
	var was_defeated := is_defeated
	super.defeat()
	if not was_defeated and is_defeated:
		presentation_event.emit(self, &"defeated", {})


func revive() -> void:
	var was_defeated := is_defeated
	super.revive()
	if was_defeated and not is_defeated:
		presentation_event.emit(self, &"revived", {})
