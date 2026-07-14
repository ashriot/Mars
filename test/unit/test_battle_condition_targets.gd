extends GutTest


class CapturingBattleManager extends BattleManager:
	var captured_targets: Array = []

	func wait(_duration: float = 0.01) -> void:
		pass

	func execute_triggered_effect(
		_actor: ActorCard,
		_effect: ActionEffect,
		targets: Array,
		_action: Action,
		_context: Dictionary = {},
	) -> void:
		captured_targets = targets


func test_off_turn_condition_self_target_resolves_to_condition_owner() -> void:
	var manager := CapturingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var hero := HeroCard.new()
	var enemy := EnemyCard.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = enemy
	hero.battle_manager = manager
	hero.is_defeated = false
	enemy.is_defeated = false
	hero_area.add_child(hero)
	enemy_area.add_child(enemy)

	var effect := ActionEffect.new()
	effect.target_type = Action.TargetType.SELF
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_REMOVED
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Off-turn self heal"
	condition.attacker = hero
	condition.triggers = [trigger]
	hero.active_conditions = [condition]

	await hero._fire_condition_event(Trigger.TriggerType.ON_REMOVED)

	assert_eq(manager.captured_targets, [hero])
	manager.free()
	hero_area.free()
	enemy_area.free()


func test_healing_effect_ignores_non_hero_target() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := HeroCard.new()
	var enemy := EnemyCard.new()
	var attacker_stats := ActorStats.new()
	attacker_stats.psyche = 10
	attacker.current_stats = attacker_stats
	var enemy_stats := ActorStats.new()
	enemy_stats.max_hp = 10
	enemy.current_stats = enemy_stats
	enemy.current_hp = 1
	enemy.is_defeated = false
	var effect := Effect_Healing.new()
	effect.potency = 1.0

	await effect.execute(attacker, [enemy], manager)

	assert_eq(enemy.current_hp, 1)
	manager.free()
	attacker.free()
	enemy.free()
