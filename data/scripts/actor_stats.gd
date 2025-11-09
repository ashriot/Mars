extends Resource
class_name ActorStats

# --- Core Stats ---
@export var actor_name: String
@export var max_hp: int = 100
@export var starting_guard: int = 5
@export var attack: int = 20
@export var psyche: int = 20
@export var precision: int = 10
@export var overload: int = 20
@export var speed: int = 20

# --- Defensive Stats ---
@export_range(0.0, 1.0) var kinetic_defense: float = 0.25 # 25% reduction
@export_range(0.0, 1.0) var energy_defense: float = 0.25 # 25% reduction
