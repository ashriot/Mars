extends Resource
class_name ActorStats

enum Stats {
	HP,
	GRD,
	ATK,
	PSY,
	OVR,
	SPD,
	PRC,
	KIN_DEF,
	NRG_DEF
}

# --- Core Stats ---
@export var actor_name: String
@export var level: int = 1
@export var max_hp: int = 100
@export var guard: int = 5
@export var attack: int = 20
@export var psyche: int = 20
@export var overload: int = 20
@export var speed: int = 20
@export var precision: int = 10
@export var kinetic_defense: int = 10
@export var energy_defense: int = 10
