extends GutTest


class RecoveryTrait extends Trait:
	var multiplier := 1.0

	func get_action_ct_multiplier(_action: Action) -> float:
		return multiplier


func _actor() -> HeroCard:
	var actor := HeroCard.new()
	actor.current_stats = ActorStats.new()
	actor.current_stats.speed = 100
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
	assert_eq(manager.get_action_recovery_adjustment(actor, action), 1250)
	action.ct_cost_percent = 125
	assert_eq(manager.get_action_recovery_adjustment(actor, action), -1250)
	manager.free()
	actor.free()
