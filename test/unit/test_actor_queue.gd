extends GutTest


func test_enemy_abbreviation_preserves_duplicate_suffix() -> void:
	assert_eq(ActorQueue.enemy_abbreviation("Scout Drone A"), "SD A")
	assert_eq(ActorQueue.enemy_abbreviation("Marauder"), "MA")
