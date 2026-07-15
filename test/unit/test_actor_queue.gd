extends GutTest


func test_all_queue_entries_use_one_square_size() -> void:
	assert_eq(ActorQueue.ITEM_SIZE, Vector2(72, 72))


func test_enemy_abbreviation_preserves_duplicate_suffix() -> void:
	assert_eq(ActorQueue.enemy_abbreviation("Scout Drone A"), "SD A")
	assert_eq(ActorQueue.enemy_abbreviation("Marauder"), "MA")
