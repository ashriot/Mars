extends Resource
class_name EnemyData

enum AIPattern { LOOP, RANDOM, SETUP }

@export var portrait: Texture
@export var stats: ActorStats # <-- THE BIG CHANGE
@export var action_deck: Array[Action]
@export var ai_script_indices: Array[int]
@export var ai_pattern: AIPattern = AIPattern.LOOP
