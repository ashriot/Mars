@tool
extends Node3D
class_name OptionalLocalModel3D

signal model_loaded(instance: Node3D)
signal model_unavailable(path: String)

@export_file("*.tscn", "*.gltf", "*.glb", "*.fbx") var local_resource_path := ""
@export var model_parent: Node3D
@export var placeholder: Node3D

var loaded_model: Node3D
var using_placeholder := true
static var _warned_paths: Dictionary = {}


func try_load() -> bool:
	clear_loaded_model()
	if not is_instance_valid(model_parent):
		push_warning("OptionalLocalModel3D requires a valid model_parent.")
		_show_placeholder()
		model_unavailable.emit(local_resource_path)
		return false
	if not is_instance_valid(placeholder):
		push_warning("OptionalLocalModel3D requires a valid placeholder.")
		model_unavailable.emit(local_resource_path)
		return false
	if local_resource_path.is_empty() or not ResourceLoader.exists(local_resource_path):
		return _use_placeholder_for_unavailable_model()
	var packed := load(local_resource_path) as PackedScene
	if packed == null:
		return _use_placeholder_for_unavailable_model()
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return _use_placeholder_for_unavailable_model()
	model_parent.add_child(instance)
	loaded_model = instance
	using_placeholder = false
	placeholder.visible = false
	model_loaded.emit(instance)
	return true


func clear_loaded_model() -> void:
	if is_instance_valid(loaded_model):
		loaded_model.free()
	loaded_model = null


func _use_placeholder_for_unavailable_model() -> bool:
	_show_placeholder()
	_warn_once(local_resource_path)
	model_unavailable.emit(local_resource_path)
	return false


func _show_placeholder() -> void:
	using_placeholder = true
	if is_instance_valid(placeholder):
		placeholder.visible = true


func _warn_once(path: String) -> void:
	if _warned_paths.has(path):
		return
	_warned_paths[path] = true
	push_warning("OptionalLocalModel3D could not load '%s'; using placeholder." % path)
