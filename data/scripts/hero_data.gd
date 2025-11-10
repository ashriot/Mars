extends Resource
class_name HeroData

@export var portrait: Texture
@export var stats: ActorStats # <-- The hero's base stats

# This is where you'll store all the roles they have unlocked
@export var unlocked_roles: Array[Role]

# You can also store their equipment here
# @export var equipped_weapon: Resource
# @export var equipped_chassis: Resource
# @export var equipped_mods: Array[Resource]
