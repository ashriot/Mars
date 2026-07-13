extends Node2D
class_name DungeonMap

const SaveCodec = preload("res://src/map/dungeon_save_codec.gd")

signal interaction_requested(node: MapNode)
signal map_generation_progress(current, total)
signal scan_performed
signal scan_canceled

enum MapState { LOADING, PLAYING, LOCKED, TARGETING }
enum AlertState { SAFE, CAUTION, DANGER }

const ALERT_LOW_THRESHOLD = 26
const ALERT_MED_THRESHOLD = 75
const CONTROLLER_CANDIDATE_SWITCH_MARGIN := 0.05
const RETICLE_CENTER_HOLD_SECONDS := 0.25
const SCAN_REVEAL_LOCK_SECONDS := 0.25

const NODE_DENSITY = {
	"terminal": 2.0,
	"combat": 3.0,
	"elite": 0.5,
	"reward_common": 1,
	"reward_uncommon": 0.45,
	"reward_rare": 0.15,
	"reward_epic": 0.05,
	"event": 1.25
}

# Base Costs
const COST_MOVE_BASE = 2.0
const PENALTY_NORMAL_MOVE = 2.0
const PENALTY_ELITE_MOVE = 4.0
const PENALTY_BOSS_MOVE = 2.0

@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $CanvasLayer/HUD
@onready var alert_gauge: ProgressBar = $CanvasLayer/HUD/AlertGauge
@onready var alert_label: Label = $CanvasLayer/HUD/AlertGauge/Percent/Value
@onready var parallax_bg: Parallax2D = $Parallax2D
@onready var bg_sprite: Sprite2D = $Parallax2D/Sprite2D
@onready var grid: Node2D = $Grid
@onready var player_cursor: Node2D = $Player/Cursor
@onready var player_reticle: Node2D = $Player/Reticle
@onready var scanner_cursor: Node2D = $Player/ScannerCursor

@onready var team_status := $CanvasLayer/HUD/TeamStatus/VBox
@onready var bits_found: Label = $CanvasLayer/HUD/BitsFound/Value
@onready var node_gauge: ProgressBar = $CanvasLayer/HUD/NodeGauge/Gauge
@onready var nodes_done_label: Label = $CanvasLayer/HUD/NodeGauge/Nodes
@onready var total_nodes_label: Label = $CanvasLayer/HUD/NodeGauge/Panel/Total
@onready var warning_label: Label = $CanvasLayer/HUD/Warning

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_length: int = 20
@export var map_height: int = 15

# --- Game Rules ---
@export_group("Map Rules")
@export var vision_range: int = 1

# --- Node Distribution Settings ---
@export_group("Node Counts")
@export var dungeon_has_boss: bool = false

# --- Camera Settings ---
@export_group("Camera")
@export var zoom_step: float = 0.25
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.5
@export var camera_smooth_speed: float = 0.3
@export var camera_edge_margin: float = 850.0
@export var camera_pan_speed: float = 600.0

@export_group("Scanner")
@export var scan_cursor_speed := 600.0
@export_range(0.1, 0.9, 0.05) var scan_dead_zone_ratio := 0.6
@export var scan_camera_follow_response := 8.0

# --- Visuals ---
@export_group("Visuals")
@export var hero_status_scene: PackedScene
@export var map_node_scene: PackedScene
@export var selection_texture: Texture2D
@export var background_texture: Texture2D
@export_range(0.0, 5.0) var background_blur: float = 3.0

# --- Internal Data ---
var map_size: int
var hex_width: float
var hex_height: float
var total_nodes: int
var grid_nodes = {}
var _map_center_pos: Vector2 = Vector2.ZERO
var _pre_battle_zoom: Vector2 = Vector2.ONE
var _pre_battle_camera_pos: Vector2 = Vector2.ZERO
var _calculated_depth_scale: Vector2 = Vector2.ONE
var terminal_memory: Dictionary = {}
var encounter_memory: Dictionary = {}
var reward_memory: Dictionary = {}
var _last_alert_state: int = -1
var _controller_preview_node: MapNode = null
var _controller_direction_engaged := false
var scan_controller := DungeonScanController.new()

# --- Hex Values ---
var hex_size: float = 50.0
var gap: float = 40.0

# --- Dungeon Stats ---
var total_moves: int = 0
var nodes_done: int = 0
var current_node: MapNode = null
var current_alert: float = 0.0
var current_move_cost: float = 0.0
var pending_scan_radius: int = 0

# --- Player Cursor ---
var cursor_pulse_tween: Tween
var cursor_move_tween: Tween
var warning_tween: Tween
var alert_tween: Tween
var _zoom_tween: Tween
var reticle_move_tween: Tween
var reticle_color_tween: Tween

# --- Bits Found ---
var _visual_bits: float = 0.0
var _bits_tween: Tween

var current_map_state: MapState = MapState.LOADING

func _ready():
	RunManager.active_dungeon_map = self
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	player_cursor.visible = false
	player_reticle.visible = false
	_setup_camera()

	alert_gauge.modulate = Color.MEDIUM_SEA_GREEN
	alert_gauge.value = 0
	bits_found.text = "0"
	alert_label.text = "0%"
	_visual_bits = float(RunManager.run_bits)
	_update_bits_text(_visual_bits)
	RunManager.run_bits_changed.connect(_on_run_bits_changed)

	hud.modulate.a = 0.0
	for hero_data in RunManager.party_roster:
		var status_ui = hero_status_scene.instantiate()
		team_status.add_child(status_ui)
		status_ui.setup(hero_data)
	_start_cursor_pulse()
	set_process(true)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.set_adapter(self)
	_publish_controller_hints()


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		if navigation._adapter == self:
			navigation.set_adapter(null)
		navigation.publish_hints([])


func _navigation_ux_layer() -> NavigationUXLayer:
	if not is_inside_tree() or get_tree() == null:
		return null
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer


func _publish_controller_hints() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		var enabled := current_map_state != MapState.LOADING and current_map_state != MapState.LOCKED
		var confirm_label := "Scan" if current_map_state == MapState.TARGETING else "Move"
		navigation.publish_hints([
			{action = &"confirm", label = confirm_label, enabled = enabled and _controller_preview_node != null},
			{action = &"cancel", label = "Clear / Cancel", enabled = enabled and (_controller_preview_node != null or current_map_state == MapState.TARGETING)},
			{action = &"camera_pan_right", label = "Pan", enabled = enabled},
			{action = &"zoom_in", label = "Zoom In", enabled = enabled},
			{action = &"zoom_out", label = "Zoom Out", enabled = enabled},
			{action = &"recenter", label = "Recenter", enabled = enabled},
		])


func _process(delta: float) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		_clear_controller_navigation(true)
		scanner_cursor.visible = false
		return
	var navigation := _navigation_ux_layer()
	if navigation and navigation.has_open_modal():
		_clear_controller_navigation(false)
		scanner_cursor.visible = false
		return
	var direction := Input.get_vector(&"nav_left", &"nav_right", &"nav_up", &"nav_down")
	var pan_direction := Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down"
	)
	if current_map_state == MapState.TARGETING:
		_process_scan_navigation(direction, pan_direction, delta)
		return
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_reconcile_controller_navigation(direction)
	else:
		_clear_controller_navigation(
			InputManager.get_cursor_behavior() == InputManager.CursorBehavior.SNAPPED
		)
	process_controller_camera(pan_direction, delta)

func _start_cursor_pulse():
	if cursor_pulse_tween: cursor_pulse_tween.kill()

	cursor_pulse_tween = create_tween()
	cursor_pulse_tween.set_loops()
	cursor_pulse_tween.set_trans(Tween.TRANS_SINE)
	cursor_pulse_tween.set_ease(Tween.EASE_IN_OUT)

	cursor_pulse_tween.tween_property(player_cursor, "modulate", Color("e06d2b"), 0.6)
	cursor_pulse_tween.tween_property(player_cursor, "modulate", Color("e0a684ff"), 0.6)

func initialize_map() -> bool:
	if RunManager.is_run_active:
		print("Resuming active run...")
		if not await RunManager.restore_run():
			push_error("DungeonMap: Active run restore failed.")
			return false

		AudioManager.play_music("map_1", 1.0, false, true)
		hud.modulate.a = 1.0

		player_cursor.visible = true
		current_map_state = MapState.PLAYING

		if current_node and current_node.state != MapNode.NodeState.COMPLETED:
			await get_tree().create_timer(1.0).timeout
			print("Resuming interrupted event at ", current_node.grid_coords)
			interaction_requested.emit(current_node)

	else:
		print("Starting fresh run...")
		randomize()
		RunManager.current_run_seed = randi()
		seed(RunManager.current_run_seed)
		var map_data = await generate_hex_grid()
		current_node = map_data.start_node
		node_gauge.max_value = total_nodes
		RunManager.is_run_active = true
		RunManager.auto_save()

		AudioManager.play_music("map_1", 1.0, false, false)
		await play_intro_sequence(map_data)
		AudioManager.play_sfx("radiate")

		var tween = create_tween()
		tween.tween_property(hud, "modulate:a", 1.0, 0.15)

		current_map_state = MapState.PLAYING
		print("Map ready.")
	refresh_team_status()
	return true

func load_from_save_data(data: Variant) -> bool:
	if not SaveCodec.is_valid_map_data(data):
		return false

	map_length = int(data.width)
	map_height = int(data.height)
	var restored_types: Dictionary = SaveCodec.extract_node_types(data)
	await generate_hex_grid(false, restored_types)

	for key_str in data.node_data.keys():
		var coords = str_to_var(key_str)
		var saved_info = data.node_data[key_str]

		if grid_nodes.has(coords):
			var node = grid_nodes[coords] as MapNode

			# Restore logical state
			node.has_been_visited = saved_info.visited
			node.is_aware = saved_info.aware
			node.set_state(int(saved_info.state))

			node.modulate.a = 1.0

	terminal_memory.clear()
	for key in data.terminal_memory.keys():
		var coords = str_to_var(key)
		terminal_memory[coords] = data.terminal_memory[key]

	encounter_memory.clear()
	for key in data.encounter_memory.keys():
		var coords = str_to_var(key)
		encounter_memory[coords] = data.encounter_memory[key]

	reward_memory.clear()
	for key in data.reward_memory.keys():
		var coords = str_to_var(key)
		reward_memory[coords] = data.reward_memory[key]

	total_nodes = int(data.total_nodes)
	nodes_done = int(data.nodes_done)
	node_gauge.max_value = total_nodes
	node_gauge.value = nodes_done
	nodes_done_label.text = str(nodes_done)
	total_nodes_label.text = str(total_nodes)

	current_alert = float(data.current_alert)
	_last_alert_state = -1
	_update_alert_visuals()

	var player_coords = str_to_var(data.current_coords)
	if not grid_nodes.has(player_coords):
		return false
	var target_node = grid_nodes[player_coords]
	current_node = target_node
	player_cursor.position = target_node.position
	player_reticle.position = target_node.position
	camera.position = target_node.position
	camera.zoom = Vector2.ONE
	if parallax_bg:
		parallax_bg.scroll_scale = _calculated_depth_scale
	await _update_vision()

	_animate_bits_change(RunManager.run_bits)
	return true

func _setup_camera():
	camera.make_current()

func _unhandled_input(event):
	if _event_input_is_suppressed():
		return
	if event.is_action_pressed(&"confirm"):
		if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
			confirm_preview()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"cancel"):
		cancel_preview()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"zoom_in"):
		_zoom_camera(zoom_step)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"zoom_out"):
		_zoom_camera(-zoom_step)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"recenter"):
		recenter_camera()
		get_viewport().set_input_as_handled()
		return
	if current_map_state == MapState.TARGETING:
		# Check for "Back" (Controller B) or Right Click
		if event.is_action_pressed("ui_cancel") or \
		   (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			_cancel_targeting()
			get_viewport().set_input_as_handled()


func select_direction(direction: Vector2) -> void:
	if current_map_state == MapState.TARGETING:
		return
	_reconcile_controller_navigation(direction)


func _reconcile_controller_navigation(direction: Vector2) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or current_node == null:
		_clear_controller_navigation(true)
		return
	if direction.is_zero_approx():
		_clear_controller_navigation(true)
		return
	_controller_direction_engaged = true
	var selected := DungeonNavigation.closest_by_angle_stable(
		current_node.position,
		direction,
		_controller_candidates(),
		_controller_preview_node,
		CONTROLLER_CANDIDATE_SWITCH_MARGIN,
	)
	if selected == _controller_preview_node:
		return
	_controller_preview_node = selected
	if selected == null:
		_return_reticle_to_current()
	else:
		if current_map_state == MapState.TARGETING:
			_start_reticle_scan_pulse()
		_animate_reticle_to(selected.position)
	_clear_navigation_cursor()
	_publish_controller_hints()


func _clear_controller_navigation(return_to_current: bool) -> void:
	var had_state := _controller_direction_engaged or _controller_preview_node != null
	_controller_direction_engaged = false
	_controller_preview_node = null
	if not had_state:
		return
	if return_to_current:
		_return_reticle_to_current()
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()


func confirm_preview() -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		return
	if _controller_preview_node == null:
		return
	var selected := _controller_preview_node
	_controller_preview_node = null
	_on_node_clicked(selected)
	_clear_navigation_cursor()
	_publish_controller_hints()


func cancel_preview() -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		return
	_controller_preview_node = null
	if current_map_state == MapState.TARGETING:
		_cancel_targeting()
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()


func _clear_navigation_cursor() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and not navigation.has_open_modal():
		navigation.cursor.clear_target()


func navigation_focus_restored() -> void:
	_clear_navigation_cursor()
	_publish_controller_hints()


func _controller_candidates() -> Array[MapNode]:
	var candidates: Array[MapNode] = []
	for value in grid_nodes.values():
		var node := value as MapNode
		node.navigation_eligible = _is_controller_candidate(node)
		if node.navigation_eligible:
			candidates.append(node)
	return candidates


func _is_controller_candidate(node: MapNode) -> bool:
	return _is_normal_traversal_destination(node)


func _map_nodes() -> Array[MapNode]:
	var nodes: Array[MapNode] = []
	for value in grid_nodes.values():
		nodes.append(value as MapNode)
	return nodes


func _sync_scan_selection() -> void:
	scanner_cursor.position = scan_controller.position
	var selected := scan_controller.select_nearest(_map_nodes())
	if selected == _controller_preview_node:
		return
	_controller_preview_node = selected
	if selected:
		_animate_reticle_to(selected.position, false)
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()


func _process_scan_navigation(
	direction: Vector2,
	pan_direction: Vector2,
	delta: float,
) -> void:
	if not scan_controller.active:
		return
	var controller_mode := InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER
	scanner_cursor.visible = controller_mode
	if _controller_preview_node == null:
		_sync_scan_selection()
	if not controller_mode:
		process_controller_camera(pan_direction, delta)
		return
	if direction.is_zero_approx():
		process_controller_camera(pan_direction, delta)
		return
	scan_controller.move(direction, delta, camera.zoom)
	_sync_scan_selection()
	_approach_scan_camera(delta)


func _approach_scan_camera(delta: float) -> void:
	var desired := scan_controller.desired_camera_position(
		camera.position,
		get_viewport_rect().size,
		camera.zoom,
	)
	var weight := 1.0 - exp(-scan_camera_follow_response * maxf(delta, 0.0))
	camera.position = _get_clamped_camera_pos(
		camera.position.lerp(desired, weight),
		camera.zoom,
	)


func _is_normal_traversal_destination(node: MapNode) -> bool:
	if node == null or current_node == null or node == current_node or current_map_state != MapState.PLAYING:
		return false
	return _get_hex_distance(current_node.grid_coords, node.grid_coords) == 1


func process_controller_camera(direction: Vector2, delta: float) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or direction.is_zero_approx():
		return
	camera.position = _get_clamped_camera_pos(
		camera.position + direction.normalized() * camera_pan_speed * delta * camera.zoom.x,
		camera.zoom
	)


func recenter_camera() -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or current_node == null:
		return
	camera.position = _get_clamped_camera_pos(current_node.position, camera.zoom)


func _event_input_is_suppressed() -> bool:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		return true
	var navigation := _navigation_ux_layer()
	return navigation != null and navigation.has_open_modal()


func _input(event):
	if _event_input_is_suppressed():
		return

	# 1. MOUSE WHEEL (Your existing logic)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_step)

	# 2. PINCH TO ZOOM (Trackpad / Touchscreen)
	elif event is InputEventMagnifyGesture:
		var zoom_delta = (event.factor - 1.0) * zoom_step * 25
		_zoom_camera(zoom_delta)

	# 3. TWO-FINGER SCROLL (Trackpad Panning)
	elif event is InputEventPanGesture:
		# Use the delta to move the camera directly
		# You might need to multiply by camera.zoom.x to keep panning speed consistent
		var pan_velocity = event.delta * 20.0 * camera.zoom.x
		camera.position += pan_velocity

		# Clamp the position so they don't pan off the map
		# (Reuse your existing clamp logic helper if you have one exposed,
		#  or rely on the _zoom_camera/move logic to fix it later)
		camera.position = _get_clamped_camera_pos(camera.position, camera.zoom)

	#if event.is_action_pressed("ui_right"):
		## 1. Find the neighbor to the right of 'current_node'
		#var target = _find_neighbor(current_node, Vector2i(1, 0))
#
		#if target:
			## 2. Manually trigger the exact same visual function
			#_animate_reticle_to(target.position)
#
			## 3. Store this target as the "Selected Node" variable
			#_selected_node_for_controller = target
#
	#if event.is_action_pressed("ui_accept"):
		#if _selected_node_for_controller:
			#_on_node_clicked(_selected_node_for_controller)

func _get_clamped_camera_pos(target_pos: Vector2, zoom_level: Vector2) -> Vector2:
	var vp_size = get_viewport_rect().size
	var visible_world_size = vp_size / zoom_level
	var bg_size = bg_sprite.texture.get_size() * bg_sprite.scale
	var p_scale = Vector2.ONE

	if parallax_bg and parallax_bg.scroll_scale != Vector2.ZERO:
		p_scale = parallax_bg.scroll_scale

	var effective_bg_size = bg_size / p_scale
	var half_bg = effective_bg_size / 3.0
	var half_view = visible_world_size / 3.0
	var center = Vector2.ZERO
	var min_x = center.x - half_bg.x + half_view.x
	var max_x = center.x + half_bg.x - half_view.x
	var min_y = center.y - half_bg.y + half_view.y
	var max_y = center.y + half_bg.y - half_view.y

	if min_x > max_x:
		min_x = center.x
		max_x = center.x
	if min_y > max_y:
		min_y = center.y
		max_y = center.y

	# 6. Clamp
	var clamped_pos = Vector2()
	clamped_pos.x = clamp(target_pos.x, min_x, max_x)
	clamped_pos.y = clamp(target_pos.y, min_y, max_y)

	return clamped_pos

func _generate_static_terminal_data(coords: Vector2i, index: int):
	var scalar = RunManager.get_loot_scalar()
	var session = "0x%X-%X-%X" % [randi() % 0xFFFF, \
	randi() % 0xFFFF, randi() % 0xFFFF]

	# 1. DEFINE BASE VALUES
	var bits_val = int(50 * scalar)
	var alert_val = 50 # Standard reduction
	var upgrade_key = "" # "security", "scan", "medical", "finance"

	# 2. APPLY ROTATION LOGIC
	var rot = index % 4

	if rot == 0:
		upgrade_key = "security"
		alert_val = 75

	elif rot == 1:
		upgrade_key = "scan"

	elif rot == 2:
		upgrade_key = "medical"

	elif rot == 3:
		upgrade_key = "finance"
		bits_val = int(bits_val * 2)
		bits_val = roundi(bits_val * randf_range(0.8, 1.2))

	terminal_memory[coords] = {
		"facility_name": "ALPHA NODE " + str(index + 1),
		"session_id": session,
		"terminal_index": index,
		"bits": bits_val,
		"alert": alert_val,
		"upgrade_key": upgrade_key
	}

func generate_hex_grid(generate_data: bool = true, forced_types: Dictionary = {}) -> Dictionary:
	print("Generating Map Logic...")

	total_moves = 0
	total_nodes = 0
	nodes_done = 0
	current_node = null
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	terminal_memory.clear()
	encounter_memory.clear()
	reward_memory.clear()

	map_generation_progress.emit(0, 100)
	await get_tree().process_frame

	for child in grid.get_children():
		child.queue_free()
	grid_nodes.clear()
	alert_gauge.value = 0

	# --- Grid Math ---
	map_size = map_height * map_length
	var valid_coords = {}
	var start_pos = Vector2.ZERO
	var center_y = floor(map_height / 2.0)
	var visual_center_x = (map_length - 1) / 2.0 + \
		(0.5 if int(center_y) % 2 == 0 else 0.0)
	var min_bounds = Vector2(INF, INF)
	var max_bounds = Vector2(-INF, -INF)

	for y in range(map_height):
		var dist_y = abs(y - center_y)
		var x_count = map_length - dist_y
		if x_count <= 0: continue

		var current_shift = 0.5 if (y % 2 == 0) else 0.0
		var x_start = round(visual_center_x - current_shift - ((x_count - 1) / 2.0))

		for i in range(x_count):
			var x = x_start + i
			var grid_pos = Vector2i(x, y)

			var x_pos = x * (hex_width + gap)
			var y_pos = y * (hex_height * 0.67 + gap)
			if y % 2 == 0: x_pos += (hex_width + gap) / 2.0

			var final_pos = start_pos + Vector2(x_pos, y_pos)
			valid_coords[grid_pos] = final_pos

			min_bounds = min_bounds.min(final_pos)
			max_bounds = max_bounds.max(final_pos)

	# --- Node Instantiation ---
	# --- NODE TYPE DETERMINATION ---
	var node_types = {}

	if not forced_types.is_empty():
		node_types = forced_types
	else:
		node_types = await _distribute_node_types(valid_coords.keys(), center_y)
	var nodes_list: Array[MapNode] = []
	if generate_data:
		var tier = RunManager.current_dungeon_tier

		# --- TERMINAL GENERATION ---
		var sorted_coords = node_types.keys()
		sorted_coords.sort_custom(func(a, b):
			if a.x != b.x: return a.x < b.x
			return a.y < b.y
		)
		var terminal_counter = 0
		for coords in sorted_coords:
			if node_types[coords] == MapNode.NodeType.TERMINAL:
				_generate_static_terminal_data(coords, terminal_counter)
				terminal_counter += 1

		# --- ENCOUNTER GENERATION ---
		var profile: DungeonProfile = RunManager.dungeon_profile
		if profile:
			for coords in sorted_coords:
				var type = node_types[coords]
				var enc_res: Encounter
				if type == MapNode.NodeType.COMBAT:
					enc_res = profile.pick_encounter(tier, false)
					encounter_memory[coords] = [enc_res.encounter_id, false, false]
				elif type == MapNode.NodeType.ELITE:
					enc_res = profile.pick_encounter(tier, true)
					encounter_memory[coords] = [enc_res.encounter_id, true, false]
				elif type == MapNode.NodeType.BOSS:
					enc_res = profile.boss_encounter
					encounter_memory[coords] = [enc_res.encounter_id, false, true]
		else:
			push_error("DungeonMap: No DungeonProfile found in RunManager! Encounters will be empty.")

		# --- REWARD GENERATION ---
		for coords in sorted_coords:
			var type = node_types[coords]
			var rarity_mod = -1

			match type:
				MapNode.NodeType.REWARD: rarity_mod = 0
				MapNode.NodeType.REWARD_2: rarity_mod = 1
				MapNode.NodeType.REWARD_3: rarity_mod = 2
				MapNode.NodeType.REWARD_4: rarity_mod = 3

			if rarity_mod != -1:
				var loot = LootManager.roll_loot(tier, rarity_mod)
				reward_memory[coords] = loot

	# --- SPAWN NODES ---
	for coords in valid_coords.keys():
		var new_node = _create_map_node(coords.x, coords.y, valid_coords[coords], node_types[coords])
		nodes_list.append(new_node)

	var grid_center = (min_bounds + max_bounds) / 2.0

	var centering_offset = -grid_center

	for node in nodes_list:
		node.position += centering_offset

	min_bounds += centering_offset
	max_bounds += centering_offset

	_map_center_pos = Vector2.ZERO
	_update_background_transform(min_bounds, max_bounds)

	# --- Find Start Node ---
	var center_start_x = round(visual_center_x - (0.5 if int(center_y) % 2 == 0 else 0.0) - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)
	var start_node = grid_nodes.get(start_coords, grid_nodes.values()[0] if not grid_nodes.is_empty() else null)

	map_generation_progress.emit(100, 100)

	return {
		"start_node": start_node,
		"nodes": nodes_list,
		"min_bounds": min_bounds,
		"max_bounds": max_bounds
	}

func play_intro_sequence(map_data: Dictionary) -> void:
	var start_node: MapNode = map_data.start_node
	var nodes_to_animate = map_data.nodes

	if not camera: return

	# --- 1. SETUP "WIDE SHOT" CAMERA ---
	var grid_center = (map_data.min_bounds + map_data.max_bounds) / 2.0
	camera.position = grid_center

	# Disable parallax depth so the image centers perfectly
	parallax_bg.scroll_scale = Vector2.ONE

	# Calculate Wide Zoom
	var vp_size = get_viewport_rect().size
	# Note: Ensure bg_sprite is accessible here. If it's local to generate,
	# you might need to store it or get it from 'self'.
	var bg_current_size = bg_sprite.texture.get_size() * bg_sprite.scale
	var wide_zoom = max(vp_size.x / bg_current_size.x, vp_size.y / bg_current_size.y)
	camera.zoom = Vector2(wide_zoom, wide_zoom)

	# --- 2. ANIMATE "WAVE" REVEAL ---

	# Reveal Start Node immediately
	# --- FIX 1: Safety Check ---
	if start_node:
		var start_tween = create_tween()
		start_tween.tween_property(start_node, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
		await start_tween.finished
		AudioManager.play_sfx("terminal") # Nice touch!

	# Sort remaining nodes Left-to-Right
	nodes_to_animate.sort_custom(func(a, b):
		if a.grid_coords.x != b.grid_coords.x: return a.grid_coords.x < b.grid_coords.x
		return a.grid_coords.y < b.grid_coords.y
	)

	# Run Wave
	var wave_tween = create_tween().set_parallel(true)
	var current_col_x = -9999
	var delay_timer = 0.0

	for node in nodes_to_animate:
		if node == start_node: continue

		if node.grid_coords.x != current_col_x:
			current_col_x = node.grid_coords.x
			delay_timer += 0.05

		wave_tween.tween_property(node, "modulate:a", 1.0, 0.3)\
			.set_delay(delay_timer)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

	await wave_tween.finished

	# --- 3. ZOOM IN TO PLAYER ---
	if start_node:
		var cam_tween = create_tween().set_parallel(true)
		cam_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(camera, "position", start_node.position, 1.5)
		cam_tween.tween_property(camera, "zoom", Vector2.ONE, 1.5)

		cam_tween.tween_property(parallax_bg, "scroll_scale", _calculated_depth_scale, 1.5)

		var shader: ShaderMaterial = bg_sprite.material

		cam_tween.tween_method(
			func(val): shader.set_shader_parameter("blur_amount", val),
			0.0,
			background_blur,
			0.5
		)

		await cam_tween.finished

		# Hand over control
		_move_player_to(start_node, true)

func refresh_team_status():
	for hero_status in team_status.get_children():
		if hero_status.is_stats_popped:
			hero_status._toggle_stats_pop()
		hero_status.refresh_view()
	nodes_done_label.text = str(nodes_done)
	node_gauge.value = nodes_done
	total_nodes_label.text = str(total_nodes)

func complete_current_node():
	if current_node:
		current_node.set_state(MapNode.NodeState.COMPLETED)
		await _update_vision()
		if current_node.type != MapNode.NodeType.UNKNOWN:
			nodes_done += 1
		match current_node.type:
			MapNode.NodeType.COMBAT:
				await get_tree().create_timer(1.0).timeout
				modify_alert(-10.0)
				print("Enemy Defeated: Alert -10%")
			MapNode.NodeType.ELITE:
				await get_tree().create_timer(1.0).timeout
				modify_alert(-20.0)
				print("Elite Defeated: Alert -20%")
	refresh_team_status()

func _on_run_bits_changed(new_total_amount: int):
	# Start animation from current visual state to new total
	_animate_bits_change(new_total_amount)

func _animate_bits_change(target_value: int):
	if _bits_tween and _bits_tween.is_running():
		_bits_tween.kill()

	_bits_tween = create_tween()
	_bits_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bits_tween.tween_method(
		_update_bits_text,
		_visual_bits,        # Start from where we are right now
		float(target_value), # End at the new total
		0.5
	)

func _update_bits_text(val: float):
	_visual_bits = val
	bits_found.text = "%.1f" % (val / 10.0)

func enter_battle_visuals(duration: float = 1.5):
	# 1. Save state
	_pre_battle_zoom = camera.zoom
	_pre_battle_camera_pos = camera.position

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. Fade Elements
	tween.tween_property(grid, "modulate:a", 0.0, duration / 2)
	tween.tween_property($Player, "modulate:a", 0.0, duration / 2)
	tween.tween_property(hud, "modulate:a", 0.0, duration / 2)

	tween.tween_property(camera, "position", Vector2.ZERO, duration)

	# 5. Restore Parallax to 1.0 (Optional, but helps alignment)
	tween.tween_property(parallax_bg, "scroll_scale", Vector2.ONE, duration)

	# 6. --- USE HELPER ---
	var target_zoom = _get_cover_zoom_level()
	tween.tween_property(camera, "zoom", target_zoom, duration)

	# 6. Clear Blur
	tween.tween_method(
		func(val): (bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", val),
		background_blur,
		0.0,
		duration
	)
	await tween.finished

func battle_ended():
	exit_battle_visuals()

func exit_battle_visuals(duration: float = 1.0):
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(grid, "modulate:a", 1.0, duration)
	tween.tween_property($Player, "modulate:a", 1.0, duration)
	tween.tween_property(hud, "modulate:a", 1.0, duration)

	var target_pos = current_node.position if current_node else _pre_battle_camera_pos
	tween.tween_property(camera, "position", target_pos, duration)
	tween.tween_property(camera, "zoom", _pre_battle_zoom, duration)
	tween.tween_method(
		func(val): (bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", val),
		0.0,
		background_blur,
		duration
	)

func _update_background_transform(min_b: Vector2, max_b: Vector2):
	bg_sprite.texture = background_texture
	if bg_sprite.material is ShaderMaterial:
		(bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", background_blur)

	var padding = Vector2(hex_width * 4, hex_height * 4)
	var grid_size = (max_b - min_b) + padding

	# --- THE FIX: FORCE ZERO CENTER ---
	_map_center_pos = Vector2.ZERO
	parallax_bg.scroll_offset = Vector2.ZERO
	parallax_bg.position = Vector2.ZERO
	# ----------------------------------

	# Scale calculation (Existing logic is fine)
	var max_dimension = max(grid_size.x, grid_size.y)
	var depth_factor = clamp(1.0 - (max_dimension / 5000.0), 0.1, 0.9)
	_calculated_depth_scale = Vector2(depth_factor, depth_factor)
	parallax_bg.scroll_scale = _calculated_depth_scale

	var tex_size = background_texture.get_size()
	var required_scale = Vector2.ONE
	var world_coverage = grid_size * (1.0 + (1.0 - depth_factor))

	required_scale.x = world_coverage.x / tex_size.x
	required_scale.y = world_coverage.y / tex_size.y

	var final_scale = max(required_scale.x, required_scale.y)
	bg_sprite.scale = Vector2(final_scale, final_scale)

func _create_map_node(grid_x, grid_y, screen_pos, type) -> MapNode:
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]
	node.modulate.a = 0.0
	grid.add_child(node)
	node.setup(Vector2i(grid_x, grid_y), type)
	node.node_clicked.connect(_on_node_clicked)
	node.node_hovered.connect(_on_node_hovered)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

	return node

func start_targeting_mode(radius: int) -> void:
	_controller_direction_engaged = false
	_controller_preview_node = null
	current_map_state = MapState.TARGETING
	pending_scan_radius = radius
	scan_controller.cursor_speed = scan_cursor_speed
	scan_controller.dead_zone_ratio = Vector2.ONE * scan_dead_zone_ratio
	var origin := current_node.position if current_node else Vector2.ZERO
	scan_controller.begin(origin, DungeonScanController.bounds_for_nodes(_map_nodes()))
	scanner_cursor.visible = InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER
	_sync_scan_selection()
	_start_reticle_scan_pulse()
	_clear_navigation_cursor()
	_publish_controller_hints()

func _start_reticle_scan_pulse():
	if reticle_color_tween and reticle_color_tween.is_running():
		reticle_color_tween.kill()
	reticle_color_tween = create_tween().set_loops()
	reticle_color_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	reticle_color_tween.tween_property(player_reticle, "modulate", Color.ORANGE, 0.5)
	reticle_color_tween.tween_property(player_reticle, "modulate", Color.DODGER_BLUE, 0.5)

func _cancel_targeting() -> void:
	if current_map_state != MapState.TARGETING: return
	current_map_state = MapState.PLAYING
	pending_scan_radius = 0
	_controller_preview_node = null
	scan_controller.stop()
	scanner_cursor.visible = false
	_reset_reticle_visuals()
	scan_canceled.emit()
	_clear_navigation_cursor()
	_publish_controller_hints()

func _reset_reticle_visuals():
	if reticle_color_tween: reticle_color_tween.kill()
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	player_reticle.modulate = Color.ORANGE
	player_reticle.visible = false

func unlock_input():
	if current_map_state == MapState.TARGETING:
		return
	current_map_state = MapState.PLAYING
	_clear_navigation_cursor()
	_publish_controller_hints()

func _on_node_clicked(target_node: MapNode) -> void:
	if current_map_state == MapState.TARGETING:
		_finish_scan_target(target_node)
		return
	if target_node == current_node:
		return
	if not _is_normal_traversal_destination(target_node):
		return
	_move_player_to(target_node)


func _finish_scan_target(target_node: MapNode) -> void:
	if current_map_state != MapState.TARGETING or target_node == null:
		return
	var radius := pending_scan_radius
	current_map_state = MapState.LOCKED
	pending_scan_radius = 0
	_controller_preview_node = null
	scan_controller.stop()
	scanner_cursor.visible = false
	_reset_reticle_visuals()
	_clear_navigation_cursor()
	_publish_controller_hints()
	execute_camera_scan(target_node, radius)
	await get_tree().create_timer(SCAN_REVEAL_LOCK_SECONDS).timeout
	if not is_inside_tree():
		return
	current_map_state = MapState.PLAYING
	scan_performed.emit()
	_publish_controller_hints()

func _move_player_to(target_node: MapNode, is_start: bool = false):
	refresh_team_status()
	current_map_state = MapState.LOCKED
	current_node = target_node
	_clear_navigation_cursor()
	_publish_controller_hints()
	_move_camera_to_player(is_start)
	player_cursor.visible = true

	if is_start:
		player_cursor.position = target_node.position
		player_reticle.position = target_node.position
		target_node.has_been_visited = true
		await _update_vision()
		_update_alert_visuals()
		return

	total_moves += 1
	var is_revisit = target_node.has_been_visited
	target_node.has_been_visited = true
	var alert_gain = current_move_cost / (2.0 if is_revisit else 1.0)
	_update_vision()
	modify_alert(alert_gain)

	_animate_cursor_slide(target_node.position)

	if target_node.state != MapNode.NodeState.COMPLETED:
		interaction_requested.emit(target_node)
	else:
		current_map_state = MapState.PLAYING

func _animate_cursor_slide(target_pos: Vector2):
	if cursor_move_tween: cursor_move_tween.kill()

	cursor_move_tween = create_tween()
	cursor_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	cursor_move_tween.tween_property(player_cursor, "position", target_pos, 0.3)
	await cursor_move_tween.finished

func _calculate_alert_gain():
	var total_cost = COST_MOVE_BASE
	var threat_penalty = 0.0
	for node in grid_nodes.values():
		if node.state == MapNode.NodeState.REVEALED and node.is_aware:
			match node.type:
				MapNode.NodeType.COMBAT:
					threat_penalty += PENALTY_NORMAL_MOVE
				MapNode.NodeType.ELITE:
					threat_penalty += PENALTY_ELITE_MOVE
				MapNode.NodeType.BOSS:
					threat_penalty += PENALTY_BOSS_MOVE
	current_move_cost = total_cost + threat_penalty

func modify_alert(amount: float):
	current_alert = clamp(current_alert + amount, 0.0, 100.0)
	_update_alert_visuals()

func _update_alert_visuals():
	_calculate_alert_gain()
	var cost_text = str(int(current_move_cost)) + "%"

	var current_state = AlertState.SAFE
	var target_color = Color(0.419, 1.063, 0.419) # Green
	var prefix_text = "OK"
	var new_vision_range = 2

	if current_alert >= ALERT_MED_THRESHOLD:
		current_state = AlertState.DANGER
		target_color = Color(1.437, 0.234, 0.0, 1.0) # HDR Red
		prefix_text = "WARNING!" if current_alert < 100 else "DANGER!!"
		new_vision_range = 0
	elif current_alert >= ALERT_LOW_THRESHOLD:
		current_state = AlertState.CAUTION
		target_color = Color(1.437, 1.226, 0.0, 1.0) # HDR Gold
		prefix_text = "CAUTION"
		new_vision_range = 1

	warning_label.text = prefix_text + " +" + cost_text

	if alert_tween and alert_tween.is_running():
		alert_tween.kill()

	alert_tween = create_tween().set_parallel(true)
	alert_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	alert_tween.tween_method(
		_set_alert_display_value,
		alert_gauge.value,
		float(current_alert),
		0.5
	)
	alert_tween.tween_property(alert_gauge, "modulate", target_color, 0.5)

	if current_state != _last_alert_state:
		_last_alert_state = current_state
		vision_range = new_vision_range
		_update_warning_pulse(current_state, target_color)

func _update_warning_pulse(state: AlertState, color: Color):
	if warning_tween:
		warning_tween.kill()

	if state == AlertState.SAFE:
		warning_label.modulate = color
		return
	var duration = 0.75 / float(1 + int(state))
	warning_tween = create_tween()
	warning_tween.set_loops()

	warning_tween.tween_property(
		warning_label,
		"modulate",
		color,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	warning_tween.tween_property(
		warning_label,
		"modulate",
		Color.WHITE,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_alert_display_value(val: float):
	alert_gauge.value = val
	alert_label.text = str(roundi(val)) + "%"

func _zoom_camera(step: float):
	if not camera: return
	if _zoom_tween and _zoom_tween.is_running(): _zoom_tween.kill()

	var limit_zoom_vec = _get_cover_zoom_level()
	var min_allowed = max(min_zoom, limit_zoom_vec.x) # The "Wide" limit
	var max_allowed = max_zoom         # The "Close" limit (e.g. 2.5)

	# 1. Apply Zoom
	var current_z = camera.zoom.x
	var new_z = clamp(current_z + step, min_allowed, max_allowed)
	var final_zoom := Vector2(new_z, new_z)

	if current_map_state == MapState.TARGETING and scan_controller.active:
		camera.position = _get_clamped_camera_pos(
			scan_controller.desired_camera_position(
				camera.position,
				get_viewport_rect().size,
				final_zoom,
			),
			final_zoom,
		)

	# 2. Tween it
	_zoom_tween = create_tween().set_parallel(true)
	_zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var duration = 0.3

	_zoom_tween.tween_property(camera, "zoom", final_zoom, duration)
	if current_map_state == MapState.TARGETING and scan_controller.active:
		return

	# 3. Update Position (The Hybrid Logic)
	# We calculate where the camera *should* be at the NEW zoom level
	var target_pos = _calculate_hybrid_position(Vector2(new_z, new_z))

	_zoom_tween.tween_property(camera, "position", target_pos, duration)

func _move_camera_to_player(force_center: bool):
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()

	var target_pos = _calculate_hybrid_position(camera.zoom)

	if force_center:
		camera.position = target_pos
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", target_pos, camera_smooth_speed)

func _calculate_hybrid_position(at_zoom: Vector2) -> Vector2:
	if not current_node: return Vector2.ZERO

	var limit_zoom = _get_cover_zoom_level().x
	var lock_threshold = 1.0

	var influence = remap(at_zoom.x, limit_zoom, lock_threshold, 0.0, 1.0)

	influence = clamp(influence, 0.0, 1.0)
	var target_pos = lerp(Vector2.ZERO, current_node.position, influence)

	return target_pos

func _get_cover_zoom_level() -> Vector2:
	var vp_size = get_viewport_rect().size

	var bg_current_size = bg_sprite.texture.get_size() * bg_sprite.scale

	var x_ratio = vp_size.x / bg_current_size.x
	var y_ratio = vp_size.y / bg_current_size.y

	var zoom_val = max(x_ratio, y_ratio)

	return Vector2(zoom_val, zoom_val) * 1.02

func execute_camera_scan(center_node: MapNode, radius: int):
	AudioManager.play_sfx("radiate")
	var nodes_to_reveal = []
	for node in grid_nodes.values():
		var dist = _get_hex_distance(center_node.grid_coords, node.grid_coords)

		if dist <= radius:
			if node.state == MapNode.NodeState.HIDDEN:
				node.is_aware = false
				nodes_to_reveal.append(node)

	if not nodes_to_reveal.is_empty():
		var tween = create_tween().set_parallel(true)
		for node in nodes_to_reveal:
			node.set_state(MapNode.NodeState.REVEALED)
			node.modulate.a = 0.0
			var delay = _get_hex_distance(center_node.grid_coords, node.grid_coords) * 0.1
			tween.tween_property(node, "modulate:a", 1.0, 0.5).set_delay(delay)

func _update_vision():
	var center_coords = current_node.grid_coords
	var nodes_to_reveal: Array[MapNode] = []

	for node in grid_nodes.values():
		if node.is_aware: continue

		var dist = _get_hex_distance(center_coords, node.grid_coords)
		if dist <= vision_range:
			node.is_aware = true
			nodes_to_reveal.append(node)

	if nodes_to_reveal.is_empty():
		return

	var tween = create_tween().set_parallel(true)
	for node in nodes_to_reveal:
		node.modulate.a = 0.5
		node.set_state(MapNode.NodeState.REVEALED)
		var dist = _get_hex_distance(center_coords, node.grid_coords)
		var delay = max(0, (dist - 1) * 0.1)
		tween.tween_property(node, "modulate:a", 1.0, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	await tween.finished

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return max(abs(ac.x - bc.x), abs(ac.y - bc.y), abs(ac.z - bc.z))

func _offset_to_cube(hex: Vector2i) -> Vector3i:
	var q = hex.x - (hex.y + (hex.y & 1)) / 2
	var r = hex.y
	var s = -q - r
	return Vector3i(q, r, s)

func _distribute_node_types(all_coords: Array, center_y: int) -> Dictionary:
	var type_map = {}
	for c in all_coords: type_map[c] = MapNode.NodeType.UNKNOWN

	var counts = {
		"terminal": _calculate_node_count("terminal"),
		"combat": _calculate_node_count("combat"),
		"elite": _calculate_node_count("elite"),
		"reward_common": _calculate_node_count("reward_common"),
		"reward_uncommon": _calculate_node_count("reward_uncommon"),
		"reward_rare": _calculate_node_count("reward_rare"),
		"reward_epic": _calculate_node_count("reward_epic"),
		"event": _calculate_node_count("event"),
	}
	counts.terminal = DungeonRules.apply_minimum(counts.terminal, DungeonRules.MIN_TERMINALS)

	print("Total Nodes:\n")
	for node_type in counts:
		print("num_", node_type, ": ", counts[node_type])

	total_nodes = DungeonRules.actionable_total(counts, dungeon_has_boss)
	var total_heavy_items = DungeonRules.actionable_total(counts, false)

	# ----------------------------
	# 2. Determine Entrance & Exit
	# ----------------------------
	var min_x = 9999
	var start_node := Vector2i()
	for c in all_coords:
		if c.y == center_y and c.x < min_x:
			min_x = c.x
			start_node = c

	type_map[start_node] = MapNode.NodeType.ENTRANCE

	# Pick boss/exit far to the right but not too close
	var sorted_by_x = all_coords.duplicate()
	sorted_by_x.sort_custom(func(a, b): return a.x > b.x)

	var end_slice = max(3, int(map_size / 6))
	var end_candidates = sorted_by_x.slice(0, min(end_slice, sorted_by_x.size()))
	end_candidates.shuffle()

	var end_node = end_candidates[0]
	type_map[end_node] = (MapNode.NodeType.BOSS if dungeon_has_boss else MapNode.NodeType.EXIT)

	# Remove protected cells
	var available := all_coords.duplicate()
	available.erase(start_node)
	available.erase(end_node)

	# ----------------------------
	# 3. Safe Zone (buffer)
	# ----------------------------
	var buffer_zone := []
	var main_pool := []

	for c in available:
		if _get_hex_distance(start_node, c) <= 2:
			buffer_zone.append(c)
		else:
			main_pool.append(c)

	# ----------------------------
	# 4. Async Placement Helper
	# ----------------------------
	var progress_state = {"count": 0, "time": Time.get_ticks_msec()}
	var max_frame_time_ms = 8

	var all_pois := []    # Track spacing for all placed POIs

	var _place_batch = func(type_enum, count: int, spacing: int) -> void:
		for i in range(count):

			if main_pool.is_empty(): return

			# Try main pool with spacing
			var c = _pick_balanced_coord(main_pool, all_pois, spacing)

			# If spacing fails, degrade gracefully
			if c == null:
				c = main_pool.pick_random()

			type_map[c] = type_enum
			main_pool.erase(c)
			all_pois.append(c)

			# Update progress
			progress_state.count += 1
			if Time.get_ticks_msec() - progress_state.time > max_frame_time_ms:
				var pct = (float(progress_state.count) / total_heavy_items) * 99.0
				map_generation_progress.emit(pct, 100.0)
				await get_tree().process_frame
				progress_state.time = Time.get_ticks_msec()

	# ----------------------------
	# 5. Place POIs
	# ----------------------------
	await _place_batch.call(MapNode.NodeType.TERMINAL, counts.terminal, 4)
	await _place_batch.call(MapNode.NodeType.ELITE, counts.elite, 3)
	await _place_batch.call(MapNode.NodeType.REWARD_4, counts.reward_epic, 2)
	await _place_batch.call(MapNode.NodeType.REWARD_3, counts.reward_rare, 2)
	await _place_batch.call(MapNode.NodeType.REWARD_2, counts.reward_uncommon, 2)
	await _place_batch.call(MapNode.NodeType.REWARD, counts.reward_common, 2)
	await _place_batch.call(MapNode.NodeType.EVENT, counts.event, 1)

	# ----------------------------
	# 6. Fill with combats
	# ----------------------------
	var combat_pool = main_pool + buffer_zone
	var placed_combats := []
	var combat_spacing = 2

	for i in range(counts.combat):
		if combat_pool.is_empty(): break

		var c = _pick_balanced_coord(combat_pool, placed_combats, combat_spacing)
		if c == null:
			c = combat_pool.pick_random()

		type_map[c] = MapNode.NodeType.COMBAT
		combat_pool.erase(c)
		placed_combats.append(c)

		progress_state.count += 1
		if Time.get_ticks_msec() - progress_state.time > max_frame_time_ms:
			var pct = (float(progress_state.count) / total_heavy_items) * 99.0
			map_generation_progress.emit(pct, 100.0)
			await get_tree().process_frame
			progress_state.time = Time.get_ticks_msec()

	return type_map


func _calculate_node_count(node_type: String) -> int:
	var density = NODE_DENSITY[node_type]
	var multiplier := 1.0
	if RunManager.dungeon_profile:
		multiplier = RunManager.dungeon_profile.get_node_multiplier(node_type)
	return DungeonRules.calculate_count(map_size, density, multiplier)


func _pick_balanced_coord(candidate_pool: Array, existing_group: Array, min_dist: int) -> Vector2i:
	if existing_group.is_empty():
		return candidate_pool.pick_random()

	# --- 1. TRY STRICT DISTANCE ---
	# Try to find a spot that meets the ideal spacing (e.g. 2 or 3)
	var ideal_candidates = []
	for candidate in candidate_pool:
		var is_valid = true
		for existing in existing_group:
			if _get_hex_distance(candidate, existing) < min_dist:
				is_valid = false
				break
		if is_valid:
			ideal_candidates.append(candidate)

	if not ideal_candidates.is_empty():
		return ideal_candidates.pick_random()

	# --- 2. FALLBACK: MINIMIZE CLUMPING ---
	# We couldn't match the distance.
	# Instead of random, find the spots with the LOWEST neighbor count.
	var best_candidates = []
	var lowest_neighbor_count = 999

	for candidate in candidate_pool:
		var neighbors = _count_group_neighbors(candidate, existing_group)

		if neighbors < lowest_neighbor_count:
			# Found a better (lonelier) spot. Reset the list.
			lowest_neighbor_count = neighbors
			best_candidates = [candidate]
		elif neighbors == lowest_neighbor_count:
			# Found another equally good spot. Add to list.
			best_candidates.append(candidate)

	if not best_candidates.is_empty():
		return best_candidates.pick_random()

	return candidate_pool.pick_random()

func _count_group_neighbors(coord: Vector2i, group: Array) -> int:
	var count = 0
	for existing in group:
		if _get_hex_distance(coord, existing) == 1:
			count += 1
	return count

func _on_node_hovered(hovered_node: MapNode) -> void:
	if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE:
		var had_preview := _controller_direction_engaged or _controller_preview_node != null
		_controller_direction_engaged = false
		_controller_preview_node = null
		if had_preview:
			_clear_navigation_cursor()
			_publish_controller_hints()
	if current_map_state != MapState.PLAYING and current_map_state != MapState.TARGETING:
		return
	if current_map_state == MapState.TARGETING:
		scan_controller.set_position(hovered_node.position)
		scanner_cursor.position = scan_controller.position
		scanner_cursor.visible = false
		_controller_preview_node = hovered_node
		_animate_reticle_to(hovered_node.position, false)
		_publish_controller_hints()
		return
	if current_map_state == MapState.PLAYING:
		var dist = _get_hex_distance(current_node.grid_coords, hovered_node.grid_coords)
		if dist == 1:
			# Mouse Input = No Animation (Snap)
			_animate_reticle_to(hovered_node.position, false)
		else:
			_hide_reticle()

func _animate_reticle_to(target_pos: Vector2, animate: bool = true):
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	player_reticle.visible = true
	player_reticle.modulate.a = 1.0

	if animate:
		reticle_move_tween = create_tween()
		reticle_move_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reticle_move_tween.tween_property(player_reticle, "position", target_pos, 0.15)
		if current_map_state != MapState.TARGETING:
			reticle_move_tween.tween_property(player_reticle, "modulate:a", 1.0, 0.1)
	else:
		player_reticle.position = target_pos
		if current_map_state != MapState.TARGETING:
			player_reticle.modulate.a = 1.0

func _return_reticle_to_current() -> void:
	if current_node == null:
		_hide_reticle()
		return
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	if reticle_color_tween and reticle_color_tween.is_running():
		reticle_color_tween.kill()
	player_reticle.visible = true
	player_reticle.modulate.a = 1.0
	reticle_move_tween = create_tween()
	reticle_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reticle_move_tween.tween_property(player_reticle, "position", current_node.position, 0.15)
	reticle_move_tween.tween_interval(RETICLE_CENTER_HOLD_SECONDS)
	reticle_move_tween.tween_property(player_reticle, "modulate:a", 0.0, 0.2)
	reticle_move_tween.finished.connect(func() -> void:
		player_reticle.visible = false
		player_reticle.modulate = Color.ORANGE
	)


func _hide_reticle() -> void:
	if not player_reticle.visible:
		return
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	if reticle_color_tween and reticle_color_tween.is_running():
		reticle_color_tween.kill()

	reticle_move_tween = create_tween()
	reticle_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reticle_move_tween.tween_property(player_reticle, "modulate:a", 0.0, 0.2)
	reticle_move_tween.finished.connect(func() -> void:
		player_reticle.visible = false
		player_reticle.modulate = Color.ORANGE
	)

func get_save_data() -> Dictionary:
	var node_states = {}

	for coords in grid_nodes:
		var node = grid_nodes[coords]
		var key = var_to_str(coords)
		node_states[key] = {
			"state": node.state,
			"visited": node.has_been_visited,
			"aware": node.is_aware,
			"type": node.type
		}

	var serializable_terminals = {}
	for coords in terminal_memory:
		var key = var_to_str(coords)
		serializable_terminals[key] = terminal_memory[coords]

	var serializable_encounters = {}
	for coords in encounter_memory:
		serializable_encounters[var_to_str(coords)] = encounter_memory[coords]

	var serializable_rewards = {}
	for coords in reward_memory:
		serializable_rewards[var_to_str(coords)] = reward_memory[coords]

	return {
		"current_alert": current_alert,
		"total_nodes": total_nodes,
		"nodes_done": nodes_done,
		"current_coords": var_to_str(current_node.grid_coords),
		"width": map_length,
		"height": map_height,
		"node_data": node_states,
		"terminal_memory": serializable_terminals,
		"encounter_memory": serializable_encounters,
		"reward_memory": serializable_rewards
	}
