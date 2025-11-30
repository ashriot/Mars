extends Resource
class_name ActionUpgrade

@export var upgrade_name: String = "Upgrade A"
@export_multiline var description: String = "Increases damage by 50%"
@export var icon: Texture

# The action this upgrade modifies
@export var target_action_id: String = "double_tap"

# What changes when this upgrade is selected
# These are example fields - adjust based on your Action structure
@export var damage_multiplier: float = 1.0  # 1.5 = +50% damage
@export var focus_cost_modifier: int = 0  # -1 = costs 1 less Focus
@export var additional_hits: int = 0  # Add extra hits
@export var grants_buff: String = ""  # e.g., "aim_boost"
@export var grants_heal: bool = false  # Does it now heal allies?
@export var changes_targeting: bool = false  # Does it hit all enemies now?

# Custom scripted behavior (if upgrades are complex)
@export var custom_effect_script: GDScript

func apply_to_action(action: Action):
	# This modifies the action when the upgrade is selected
	# Implementation depends on your Action class structure
	if damage_multiplier != 1.0:
		action.damage_modifier *= damage_multiplier
	if focus_cost_modifier != 0:
		action.focus_cost = max(0, action.focus_cost + focus_cost_modifier)
	# Add more modifications as needed
