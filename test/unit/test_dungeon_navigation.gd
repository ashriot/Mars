extends GutTest

const DungeonNavigation = preload("res://src/map/dungeon_navigation.gd")
const MAP_NODE_SCENE = preload("res://src/map/map_node.tscn")


func _node(pos: Vector2, coords: Vector2i = Vector2i.ZERO) -> MapNode:
	var node := MAP_NODE_SCENE.instantiate() as MapNode
	node.position = pos
	node.grid_coords = coords
	add_child_autofree(node)
	return node


func test_closest_by_angle_prefers_alignment_before_distance() -> void:
	var aligned := _node(Vector2(100, 0))
	var nearer_off_angle := _node(Vector2(10, 5))

	assert_same(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.RIGHT, [nearer_off_angle, aligned]), aligned)


func test_closest_by_angle_breaks_equal_angle_by_distance_then_coordinates() -> void:
	var far := _node(Vector2(20, 0), Vector2i(0, 0))
	var near_high_coord := _node(Vector2(10, 0), Vector2i(2, 0))
	var near_low_coord := _node(Vector2(10, 0), Vector2i(1, 0))

	assert_same(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.RIGHT, [far, near_high_coord, near_low_coord]), near_low_coord)


func test_closest_by_angle_excludes_ineligible_nodes() -> void:
	var hidden := _node(Vector2(20, 0))
	hidden.navigation_eligible = false
	var visible := _node(Vector2(20, 10))

	assert_same(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.RIGHT, [hidden, visible]), visible)


func test_closest_by_angle_returns_null_for_neutral_or_no_candidates() -> void:
	assert_null(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.ZERO, [_node(Vector2.RIGHT)]))
	assert_null(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.RIGHT, []))


func test_closest_by_angle_rejects_behind_origin_and_orthogonal_candidates() -> void:
	var behind := _node(Vector2.LEFT * 10.0)
	var above := _node(Vector2.UP * 10.0)

	assert_null(DungeonNavigation.closest_by_angle(Vector2.ZERO, Vector2.RIGHT, [behind, above]))
