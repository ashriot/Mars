extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const TitleScene = preload("res://src/core/title_screen.tscn")
const LoadingScene = preload("res://src/core/loading_screen.tscn")
const GameManagerScene = preload("res://src/battle/game_manager.tscn")
const TooltipScene = preload("res://src/core/tooltip_panel.tscn")
const EndScreenScene = preload("res://src/map/dungeon_end_screen.tscn")

const ACCEPTANCE_OUTPUTS: Array[Vector2i] = [
	Vector2i(1280, 800),
	Vector2i(1920, 1080),
]


func test_global_shell_controls_fit_acceptance_outputs() -> void:
	for window_size in ACCEPTANCE_OUTPUTS:
		var title_fixture := _add_scene_fixture(TitleScene, window_size, true)
		var title := title_fixture.instance as Control
		var loading_fixture := _add_scene_fixture(LoadingScene, window_size, true)
		var loading := loading_fixture.instance as Control
		var end_fixture := _add_scene_fixture(EndScreenScene, window_size, true)
		var end_screen := end_fixture.instance as Control
		var tooltip_fixture := _add_scene_fixture(TooltipScene, window_size)
		var tooltip := tooltip_fixture.instance as TooltipPanel
		tooltip.set_text("Responsive tooltip")
		await get_tree().process_frame

		var logical_size := ResponsiveFixture.logical_size_for(window_size)
		assert_eq(title.get_node("TextureRect").get_global_rect(), Rect2(Vector2.ZERO, logical_size))
		assert_eq(title.get_node("TextureRect/Title").get_global_rect(), title.get_node("Title").get_global_rect())
		assert_true(ResponsiveFixture.fits_output(title.get_node("MenuButtons"), window_size))
		assert_eq(loading.get_node("ColorRect").get_global_rect(), Rect2(Vector2.ZERO, logical_size))
		assert_true(ResponsiveFixture.fits_output(end_screen.get_node("Panel"), window_size))
		assert_true(ResponsiveFixture.fits_output(tooltip, window_size))
		assert_gte(ResponsiveFixture.physical_rect(end_screen.get_node("Panel/Button"), window_size).size.y, 48.0)


func test_transition_fader_fills_acceptance_viewports() -> void:
	for window_size in ACCEPTANCE_OUTPUTS:
		var viewport := _add_viewport(window_size)
		var manager := GameManagerScene.instantiate()
		var fader := manager.get_node("CanvasLayer/Fader") as ColorRect
		fader.get_parent().remove_child(fader)
		manager.free()
		viewport.add_child(fader)
		await get_tree().process_frame

		assert_eq(fader.get_global_rect(), Rect2(Vector2.ZERO, viewport.size))


func test_tooltip_refits_when_viewport_width_changes() -> void:
	var fixture := _add_scene_fixture(TooltipScene, Vector2i(1920, 1080))
	var viewport := fixture.viewport as SubViewport
	var tooltip := fixture.instance as TooltipPanel
	viewport.size = Vector2i(560, 480)
	await get_tree().process_frame

	assert_eq(tooltip.label.custom_minimum_size.x, 464.0)
	assert_lte(tooltip.size.x, 560.0)


func _add_scene_fixture(scene: PackedScene, window_size: Vector2i, strip_root_script := false) -> Dictionary:
	var viewport := _add_viewport(window_size)
	var instance := scene.instantiate()
	if strip_root_script:
		instance.set_script(null)
	viewport.add_child(instance)
	return {viewport = viewport, instance = instance}


func _add_viewport(window_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ResponsiveFixture.logical_size_for(window_size))
	add_child_autofree(viewport)
	return viewport
