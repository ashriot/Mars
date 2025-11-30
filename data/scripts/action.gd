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
@export var update_turn_order: bool = false
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


func get_rich_description(user: ActorCard) -> String:
	_init_regex()
	var final_desc = description

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

	for match_result in _regex.search_all(description):
		var full_tag = match_result.get_string(0) # "{atk * 0.5}"
		var formula_string = match_result.get_string(1) # "atk * 0.5"

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
			var final_val = roundi(float(result))
			final_desc = final_desc.replace(full_tag, str(final_val))

	final_desc = final_desc.replace("{cost}", str(focus_cost))
	final_desc = final_desc.replace("{foc}", _get_bbcode_icon("focus"))
	final_desc = final_desc.replace("{grd}", _get_bbcode_icon("guard"))
	final_desc = final_desc.replace("{kin}", _get_bbcode_icon("kinetic"))
	final_desc = final_desc.replace("{nrg}", _get_bbcode_icon("energy"))
	final_desc = final_desc.replace("{prc}", _get_bbcode_icon("piercing"))

	return final_desc

func _get_damage_string(damage_effect: Effect_Damage, attacker: ActorCard) -> String:
	var dynamic_potency = damage_effect._get_dynamic_potency(attacker, null)
	var base_power = attacker.get_power(damage_effect.power_type)
	var final_damage = roundi(base_power * dynamic_potency)
	return str(final_damage)

static var ICON_PATHS = {
	"focus": "res://assets/graphics/icons/textures/bolt_sm.png",
	"guard": "res://assets/graphics/icons/textures/shield_sm.png",
	"kinetic": "res://assets/graphics/icons/textures/bullet.png",
	"energy": "res://assets/graphics/icons/textures/energy_sm.png",
	"piercing": "res://assets/graphics/icons/textures/pierce.png",
}

static func _get_bbcode_icon(icon_name: String, size: int = 24) -> String:
	if ICON_PATHS.has(icon_name):
		return "[img width=%d height=%d]%s[/img]" % [size, size, ICON_PATHS[icon_name]]
	return ""


func _init_regex():
	if _regex.get_pattern() == "":
		_regex.compile("\\{([^}]+)\\}")
