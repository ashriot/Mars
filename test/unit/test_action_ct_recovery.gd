extends GutTest

class RecoveryTrait extends Trait:
	var multiplier := 1.0

	func get_action_ct_multiplier(_action: Action) -> float:
		return multiplier


class ImmediateBattleManager extends BattleManager:
	func wait(_duration: float = 0.01) -> void:
		return

	func update_turn_order() -> void:
		return


func _actor() -> HeroCombatant:
	var actor := HeroCombatant.new()
	var stats := ActorStats.new()
	stats.speed = 100
	actor.setup_base(stats, BattleCombatant.Faction.HERO)
	return actor


func test_action_ct_modifiers_multiply_round_and_clamp() -> void:
	var actor := _actor()
	var action := Action.new()
	action.ct_cost_percent = 80
	var condition := Condition.new()
	condition.action_ct_multiplier = 0.9
	actor.active_conditions = [condition]
	var recovery_trait := RecoveryTrait.new()
	recovery_trait.multiplier = 0.8
	actor.active_traits = [recovery_trait]
	assert_eq(actor.get_action_ct_percent(action), 58)
	action.ct_cost_percent = 10
	condition.action_ct_multiplier = 0.1
	assert_eq(actor.get_action_ct_percent(action), 10)
	action.ct_cost_percent = 200
	condition.action_ct_multiplier = 2.0
	recovery_trait.multiplier = 2.0
	assert_eq(actor.get_action_ct_percent(action), 200)
	actor.free()


func test_recovery_adjustment_uses_signed_ct() -> void:
	var manager := BattleManager.new()
	var actor := _actor()
	var action := Action.new()
	action.ct_cost_percent = 75
	assert_eq(manager.get_action_recovery_adjustment(actor, action), 1000)
	action.ct_cost_percent = 125
	assert_eq(manager.get_action_recovery_adjustment(actor, action), -1000)
	manager.free()
	actor.free()


func test_recovery_adjustment_uses_exact_boundary_percentages() -> void:
	var manager := BattleManager.new()
	var actor := _actor()
	var action := Action.new()
	for boundary in [
		[10, 3600],
		[100, 0],
		[200, -4000],
	]:
		action.ct_cost_percent = boundary[0]
		assert_eq(
			manager.get_action_recovery_adjustment(actor, action),
			boundary[1],
			"%d%% recovery uses the exact boundary adjustment" % boundary[0],
		)
	manager.free()
	actor.free()


func test_repeated_direct_ten_percent_delays_accumulate_below_zero() -> void:
	var manager := ImmediateBattleManager.new()
	var actor := _actor()
	manager.actor_list = [actor]
	manager.current_actor = actor
	var delay := Effect_ModifyCT.new()
	delay.ct_change_percent = -0.1

	await delay.execute(actor, [actor], manager)
	await delay.execute(actor, [actor], manager)

	assert_eq(actor.current_ct, -800)
	manager.free()
	actor.free()
