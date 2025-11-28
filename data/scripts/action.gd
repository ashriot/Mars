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

var is_attack: bool :
	get:
		for effect in effects:
			if effect is Effect_Damage:
				return true
		return false

func get_rich_description(user: ActorCard) -> String:
	var final_desc = description

	final_desc = final_desc.replace("{atk}", str(user.get_power(PowerType.ATTACK)))
	final_desc = final_desc.replace("{psy}", str(user.get_power(PowerType.PSYCHE)))

	var focus_icon = _get_bbcode_icon("focus")
	var kinetic_dmg = _get_bbcode_icon("kinetic")
	var energy_dmg = _get_bbcode_icon("energy")
	var pierce_dmg = _get_bbcode_icon("pierce")

	final_desc = final_desc.replace("{atk}", str(user.current_stats.attack))
	final_desc = final_desc.replace("{psy}", str(user.current_stats.psyche))
	final_desc = final_desc.replace("{foc}", focus_icon)
	final_desc = final_desc.replace("{focus_cost}", str(focus_cost))
	final_desc = final_desc.replace("{kin}", kinetic_dmg)
	final_desc = final_desc.replace("{nrg}", energy_dmg)
	final_desc = final_desc.replace("{prc}", pierce_dmg)

	# 3. --- THIS IS THE NEW "NO-SHORTCUT" LOGIC ---
	# Loop through our effects and replace their *specific* values
	for i in effects.size():
		var effect = effects[i]
		var effect_num_str = str(i + 1) # "1" for the first effect, "2" for the second

		# --- A. Check if it's a Damage Effect ---
		if effect is Effect_Damage:
			var damage_tag = "{dmg" + effect_num_str + "}" # e.g., "{dmg1}"

			# Check if the description *wants* this value
			if final_desc.find(damage_tag) != -1:
				# It does! We'll ask the effect to calculate its damage.
				var damage_string = _get_damage_string(effect, user)
				final_desc = final_desc.replace(damage_tag, damage_string)

		# --- B. Check if it's a Grant Guard Effect ---
		elif effect is Effect_ModifyGuard:
			var guard_tag = "{guard" + effect_num_str + "}" # e.g., "{guard2}"

			if final_desc.find(guard_tag) != -1:
				var guard_string = str(effect.guard_amount)
				final_desc = final_desc.replace(guard_tag, guard_string)

		# --- C. Check if it's a Healing Effect ---
		elif effect is Effect_Healing:
			var heal_tag = "{heal" + effect_num_str + "}" # e.g., "{heal1}"

			if final_desc.find(heal_tag) != -1:
				# (This is a simplified version, it doesn't
				# account for "missing HP" scaling in the preview)
				var base_power = user.get_power(effect.power_type)
				var heal_string = str(roundi(base_power * effect.potency))
				final_desc = final_desc.replace(heal_tag, heal_string)

		# (Add 'elif' checks here for other effects you create)

	return final_desc

func _get_damage_string(damage_effect: Effect_Damage, attacker: ActorCard) -> String:
	var dynamic_potency = damage_effect._get_dynamic_potency(attacker, null)

	# 2. Get the base power
	var base_power = attacker.get_power(damage_effect.power_type)

	# 3. Calculate the damage
	# (This preview doesn't account for Overload or Defenses)
	var final_damage = roundi(base_power * dynamic_potency)

	return str(final_damage)


static var ICON_PATHS = {
	"focus": "res://assets/graphics/icons/textures/bolt_sm.png",
	"kinetic": "res://assets/graphics/icons/textures/bullet.png",
	"energy": "res://assets/graphics/icons/textures/fire.png",
	"piercing": "res://assets/graphics/icons/textures/pierce.png",
}

static func _get_bbcode_icon(icon_name: String, size: int = 24) -> String:
	if ICON_PATHS.has(icon_name):
		return "[img width=%d height=%d]%s[/img]" % [size, size, ICON_PATHS[icon_name]]
	return ""
