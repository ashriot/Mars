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


func test_healing_effect_heals_living_enemy_without_hero_focus_scaling() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := EnemyCard.new()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.psyche = 20
	var target := EnemyCard.new()
	target.current_stats = ActorStats.new()
	target.current_stats.max_hp = 100
	target.hp_bar_ghost = ProgressBar.new()
	target.current_hp = 25
	target.is_defeated = false
	var effect := Effect_Healing.new()
	effect.potency = 1.5
	effect.focus_scalar = 1.0
	effect.is_revive = false

	await effect.execute(attacker, [target], manager)

	assert_eq(target.current_hp, 55)
	manager.free()
	attacker.free()
	target.hp_bar_ghost.free()
	target.free()
