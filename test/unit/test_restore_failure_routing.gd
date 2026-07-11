extends GutTest

class MainRouteDouble extends Main:
	var hub_route_invoked := false
	var game_scene_created := false

	func load_hub():
		hub_route_invoked = true

	func _change_content(_scene_packed: PackedScene, _target_parent: Node):
		game_scene_created = true


var _saved_data: Dictionary
var _saved_bits: int
var _saved_inventory: Dictionary
var _saved_active: bool


func before_each() -> void:
	_saved_data = SaveSystem.data
	_saved_bits = SaveSystem.bits
	_saved_inventory = SaveSystem.inventory
	_saved_active = RunManager.is_run_active


func after_each() -> void:
	SaveSystem.data = _saved_data
	SaveSystem.bits = _saved_bits
	SaveSystem.inventory = _saved_inventory
	RunManager.is_run_active = _saved_active


func test_game_manager_failed_initialization_emits_restore_failure_route() -> void:
	var manager := GameManager.new()
	assert_has_signal(manager, "restore_failed")
	if not manager.has_signal("restore_failed"):
		return
	watch_signals(manager)
	manager.call("_handle_map_initialization_result", false)
	assert_push_error("Dungeon map initialization failed")
	await get_tree().process_frame
	assert_signal_emitted(manager, "restore_failed")
	manager.free()


func test_invalid_continue_clears_only_active_run_and_routes_to_hub() -> void:
	SaveSystem.bits = 91
	SaveSystem.inventory = {"mat_arm_1": 7}
	SaveSystem.data = {
		"active_run": {"profile_path": "res://missing_profile.tres"},
		"permanent_marker": "keep-me",
		"bits": 91,
		"inventory": {"mat_arm_1": 7},
	}
	RunManager.is_run_active = true
	var main := MainRouteDouble.new()

	await main._on_continue_requested()

	assert_null(SaveSystem.data.active_run)
	assert_eq(SaveSystem.data.permanent_marker, "keep-me")
	assert_eq(SaveSystem.data.bits, 91)
	assert_eq(SaveSystem.data.inventory, {"mat_arm_1": 7})
	assert_eq(SaveSystem.bits, 91)
	assert_eq(SaveSystem.inventory, {"mat_arm_1": 7})
	assert_false(RunManager.is_run_active)
	assert_true(main.hub_route_invoked)
	assert_false(main.game_scene_created)
	main.free()
