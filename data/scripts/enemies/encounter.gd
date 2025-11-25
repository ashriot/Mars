extends Resource
class_name Encounter

@export_group("Composition")
# The list of enemies in this fight
@export var enemies: Array[EnemyData]

@export_group("Settings")
# Which dungeon tiers can this appear in?
@export var min_tier: int = 1
@export var max_tier: int = 10
# Is this an Elite fight?
@export var is_elite: bool = false
# Is this a Boss fight?
@export var is_boss: bool = false
