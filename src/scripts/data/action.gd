extends Resource
class_name Action

enum HeroType { ALL, ASHER, ECHO, SANDS }
enum PowerType { ATTACK, PSYCHE }
enum DamageType { KINETIC, ENERGY, PIERCING, NONE }
enum TargetType {
	ONE_ENEMY,			#0
	ALL_ENEMIES,		#1
	ENEMY_GROUP,		#2
	RANDOM_ENEMY,		#3
	SELF,				#4
	ONE_ALLY,			#5
	ALLY_ONLY,			#6
	ALL_ALLIES,			#7
	ALLIES_ONLY,		#8
	PARENT,				#9
	LEAST_GUARD_ALLY,	#10
	ATTACKER,			#11
	LEAST_FOCUS_ALLY,	#12

}

@export var action_name: String = "New Action"
@export var icon: Texture
@export_multiline var description: String = ""
@export var focus_cost: int = 0
@export var auto_target: bool = false
@export_range(10, 200, 1) var ct_cost_percent: int = 100
@export var is_shift_action: bool = false

@export var target_type: TargetType = TargetType.ONE_ENEMY
@export var effects: Array[ActionEffect]

var _expression = Expression.new()
var _regex = RegEx.new()

var is_attack: bool :
	get:
		for effect in effects:
			if effect is Effect_Damage:
				return true
		return false

func get_rich_description(
	user: ActorCard,
	target: ActorCard = null,
	presentation_targets: Array[ActorCard] = [],
	battle_manager: BattleManager = null,
) -> String:
	_init_regex()
	var final_desc := _compose_effect_presentations(
		description, user, target, presentation_targets, battle_manager,
	)

	var input_names = PackedStringArray(["atk", "psy", "hp", "spd", "focus", "grd"])

	var current_foc = 0.0
	if user is HeroCard:
		current_foc = float(user.current_focus)

	var input_values = Array([
		float(user.get_power(PowerType.ATTACK)),
		float(user.get_power(PowerType.PSYCHE)),
		float(user.current_stats.max_hp),
		float(user.current_stats.speed),
		current_foc,
		float(user.current_guard)
	])

	for match_result in _regex.search_all(final_desc):
		var full_tag = match_result.get_string(0) # "{atk * 0.5}"
		var formula_string = match_result.get_string(1) # "atk * 0.5"
		if formula_string in ["foc", "grd", "kin", "nrg", "prc", "ct_effect", "cost"]:
			continue

		# A. Parse the formula
		var error = _expression.parse(formula_string, input_names)

		if error != OK:
			# It wasn't a math formula (maybe it's an icon tag like {kin}?)
			# Ignore it and let the icon replacer handle it later.
			continue

		# B. Execute the math
		var result = _expression.execute(input_values, null, false)

		if not _expression.has_execute_failed():
			# C. Replace the tag with the result
			var final_val = int(result)
			final_desc = final_desc.replace(full_tag, str(final_val))

	final_desc = final_desc.replace("{cost}", str(focus_cost))
	final_desc = final_desc.replace("{foc}", _get_bbcode_icon("focus"))
	final_desc = final_desc.replace("{grd}", _get_bbcode_icon("guard"))
	final_desc = final_desc.replace("{kin}", _get_bbcode_icon("kinetic"))
	final_desc = final_desc.replace("{nrg}", _get_bbcode_icon("energy"))
	final_desc = final_desc.replace("{prc}", _get_bbcode_icon("pierce"))
	final_desc = final_desc.replace("{ct_effect}", get_ct_description())

	return final_desc


func _compose_effect_presentations(
	template: String,
	user: ActorCard,
	target: ActorCard,
	presentation_targets: Array[ActorCard],
	battle_manager: BattleManager,
) -> String:
	if template.is_empty():
		var clauses: Array[String] = []
		for effect_index in effects.size():
			var presentation := _get_effect_presentation(
				effect_index, user, target, presentation_targets, battle_manager,
			)
			if presentation != null:
				clauses.append(presentation.render())
		return "[p]".join(clauses)

	var composed := template
	for match_result in _regex.search_all(template):
		var binding := match_result.get_string(1)
		if not binding.begins_with("effect:"):
			continue
		var index_text := binding.trim_prefix("effect:")
		if not index_text.is_valid_int():
			continue
		var effect_index := index_text.to_int() - 1
		var presentation := _get_effect_presentation(
			effect_index, user, target, presentation_targets, battle_manager,
		)
		if presentation != null:
			composed = composed.replace(match_result.get_string(0), presentation.render())
	return composed


func _get_effect_presentation(
	effect_index: int,
	user: ActorCard,
	target: ActorCard,
	presentation_targets: Array[ActorCard],
	battle_manager: BattleManager,
) -> EffectPresentation:
	if effect_index < 0 or effect_index >= effects.size():
		return null
	var effect := effects[effect_index]
	if effect == null:
		return null
	var resolved_targets: Array[ActorCard] = []
	resolved_targets.assign(presentation_targets)
	if target != null and resolved_targets.is_empty():
		resolved_targets.append(target)
	var distribution_count := 1
	var presentation_is_complete := not resolved_targets.is_empty()
	var is_group_target := target_type in [
		TargetType.ALL_ENEMIES,
		TargetType.ENEMY_GROUP,
		TargetType.ALL_ALLIES,
		TargetType.ALLIES_ONLY,
	]
	if effect is Effect_Damage:
		var damage_effect := effect as Effect_Damage
		if damage_effect._requires_battlefield_context() \
			and battle_manager == null:
			presentation_is_complete = false
		var resolved_hit_count := damage_effect._resolve_hit_count(user)
		if not resolved_targets.is_empty():
			var plan := damage_effect._build_hit_plan(
				resolved_targets, self, resolved_hit_count,
			)
			distribution_count = plan.distribution_count
		elif damage_effect.split_damage and not is_group_target:
			distribution_count = maxi(1, resolved_hit_count)
	var context := EffectPresentationContext.new(
		user, target, self, effect_index, distribution_count, false,
		null, resolved_targets, battle_manager, presentation_is_complete,
	)
	return effect.get_presentation(context)

func _init_regex():
	if _regex.get_pattern() == "":
		_regex.compile("\\{([^}]+)\\}")

func get_ct_description() -> String:
	"""Get human-readable CT effect description"""
	for effect in effects:
		if effect is Effect_ModifyCT:
			var percent = int(abs(effect.ct_change_percent * 100))

			# Determine who it affects
			var target_text = ""
			match target_type:
				TargetType.SELF, TargetType.ATTACKER:
					target_text = "your"
				TargetType.ONE_ENEMY, TargetType.ALL_ENEMIES:
					target_text = "enemy's"
				TargetType.ONE_ALLY, TargetType.ALL_ALLIES:
					target_text = "ally's"
				_:
					target_text = "target's"

			if effect.ct_change_percent > 0:
				return "Boost %s next turn by %d%%" % [target_text, percent]
			else:
				return "Delay %s next turn by %d%%" % [target_text, percent]
	return ""

static var ICON_PATHS = {
	"focus": "res://assets/graphics/icons/textures/bolt_sm.png",
	"guard": "res://assets/graphics/icons/textures/shield_sm.png",
	"kinetic": "res://assets/graphics/icons/img/bullet_out.png",
	"energy": "res://assets/graphics/icons/img/energy_out.png",
	"pierce": "res://assets/graphics/icons/img/pierce_out.png",
}

static func _get_bbcode_icon(icon_name: String, size: int = 24) -> String:
	if ICON_PATHS.has(icon_name):
		return "[img width=%d height=%d]%s[/img]" % [size, size, ICON_PATHS[icon_name]]
	return ""
