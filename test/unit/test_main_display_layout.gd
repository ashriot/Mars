extends GutTest


class TestMain extends Main:
	func _ready() -> void:
		pass


func _main_fixture() -> Main:
	var main := TestMain.new()
	main.world_layer = Node2D.new()
	main.add_child(main.world_layer)
	autofree(main)
	return main


func test_deck_logical_viewport_centers_unscaled_world_in_safe_composition() -> void:
	var main := _main_fixture()
	main.apply_display_layout(Vector2(1920, 1200))
	assert_eq(main.world_layer.position, Vector2(0, 60))
	assert_eq(main.world_layer.scale, Vector2.ONE)


func test_small_direct_viewport_scales_world_uniformly_without_crop() -> void:
	var main := _main_fixture()
	main.apply_display_layout(Vector2(1280, 800))
	assert_eq(main.world_layer.position, Vector2(0, 40))
	assert_eq(main.world_layer.scale, Vector2(2.0 / 3.0, 2.0 / 3.0))
