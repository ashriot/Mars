# TraitDatabase.gd (Autoload)
extends Node

# We define the groups here so they are globally accessible
enum Group {
	# Weapons
	BARRAGE, SPREAD, IMPACT,
	# Armor
	CLOTHES, JACKETS, VESTS,
	# Misc
	NONE
}

# --- CONFIGURATION ---
# Assign these in the Inspector or preload("res://...")
@export var trait_barrage: Trait
@export var trait_spread: Trait
@export var trait_impact: Trait
@export var trait_clothes: Trait
@export var trait_jackets: Trait
@export var trait_vests: Trait

# --- LOOKUP ---
func get_shared_trait(group: Group) -> Trait:
	match group:
		Group.BARRAGE: return trait_barrage
		Group.SPREAD: return trait_spread
		Group.IMPACT: return trait_impact
		Group.CLOTHES: return trait_clothes
		Group.JACKETS: return trait_jackets
		Group.VESTS: return trait_vests
	return null
