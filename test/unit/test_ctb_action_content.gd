extends GutTest

const BATTLE_SCENE := preload("res://src/battle/battle_scene.tscn")
const MIGRATED := {
	"res://data/enemies/actions/brace.tres": 75,
	"res://data/heroes/asher/actions/fusion_ammo.tres": 85,
	"res://data/heroes/asher/actions/mark_target.tres": 25,
	"res://data/heroes/asher/actions/targeting_laser.tres": 75,
	"res://data/heroes/echo/actions/energize.tres": 50,
}


func test_self_acceleration_is_action_recovery_only() -> void:
	for path: String in MIGRATED:
		var action := load(path) as Action
		assert_eq(action.ct_cost_percent, MIGRATED[path], path)
		assert_false(action.effects.any(func(effect):
			return effect is Effect_ModifyCT and effect.target_type in [
				Action.TargetType.SELF, Action.TargetType.ATTACKER,
			]
		), "%s no longer double-applies self acceleration" % path)


func test_other_actor_and_conditional_ct_effects_remain_direct() -> void:
	for path in [
		"res://data/heroes/sands/actions/tempo.tres",
		"res://data/heroes/sands/actions/advantage.tres",
		"res://data/heroes/asher/actions/concussive_shot.tres",
	]:
		var action := load(path) as Action
		assert_eq(action.ct_cost_percent, 100)
		assert_true(_contains_ct_effect(action), path)


func test_action_ct_color_compares_final_recovery_to_authored_base() -> void:
	assert_eq(BattleManager._action_ct_color(65, 65), Color.WHITE)
	assert_eq(BattleManager._action_ct_color(65, 52), Color("67e88a"))
	assert_eq(BattleManager._action_ct_color(65, 80), Color("f87171"))


func test_selected_action_shows_final_effective_ct() -> void:
	var scene := BATTLE_SCENE.instantiate() as BattleScene
	var manager := scene.get_node("BattleManager") as BattleManager
	var actor := HeroCard.new()
	actor.current_stats = ActorStats.new()
	var role := RoleData.new()
	role.source_definition = RoleDefinition.new()
	role.source_definition.color = Color.CORNFLOWER_BLUE
	actor.loaded_roles = [role]
	manager.current_actor = actor
	manager.set_current_action(load(
		"res://data/heroes/asher/actions/targeting_laser.tres"
	) as Action)
	var panel := scene.get_node("UI/CurrentAction") as PanelContainer
	var ct_label := panel.get_node_or_null("HBoxContainer/CTPercent") as Label
	if not assert_not_null(ct_label):
		actor.free()
		scene.free()
		return
	assert_eq(ct_label.text, "75% CT")
	assert_eq(panel.modulate, Color.WHITE)
	actor.free()
	scene.free()


func _contains_ct_effect(action: Action) -> bool:
	for effect: ActionEffect in action.effects:
		if effect is Effect_ModifyCT:
			return true
		if effect is Effect_Damage:
			for trigger in effect.on_hit_triggers:
				for nested: ActionEffect in trigger.effects_to_run:
					if nested is Effect_ModifyCT:
						return true
	return false
