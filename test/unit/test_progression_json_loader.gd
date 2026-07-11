extends GutTest

const FIXTURES := "res://test/fixtures/progression/"


func test_valid_file_builds_complete_immutable_tree() -> void:
	var result = ProgressionJsonLoader.load_file(FIXTURES + "valid_role.json")
	assert_not_null(result.tree)
	assert_eq(result.errors.size(), 0)
	assert_eq(result.tree.role_id, "gun")
	assert_eq(result.tree.version, 3)
	assert_eq(result.tree.nodes.size(), 4)
	assert_eq(result.tree.get_node("gun.action").effect.type, ProgressionEffect.Type.ACTION)


func test_fixture_validation_errors_are_contextual() -> void:
	var cases := {
		"duplicate_node.json": ["gun.root", "id", "Duplicate"],
		"missing_parent.json": ["gun.child", "parent", "does not exist"],
		"multiple_roots.json": ["", "nodes", "exactly one root"],
		"cycle.json": ["gun.a", "parent", "cycle"],
		"invalid_effect.json": ["gun.root", "effect.type", "Unknown"],
	}
	for filename: String in cases:
		var result = ProgressionJsonLoader.load_file(FIXTURES + filename)
		assert_null(result.tree, filename)
		assert_gt(result.errors.size(), 0, filename)
		var expected: Array = cases[filename]
		var combined := _combined_errors(result.errors)
		assert_string_contains(combined, FIXTURES + filename)
		if not expected[0].is_empty():
			assert_string_contains(combined, expected[0])
		assert_string_contains(combined, expected[1])
		assert_string_contains(combined, expected[2])


func test_document_and_node_scalar_validation() -> void:
	var cases := [
		["schema_version", 2, "", "schema_version", "Unsupported"],
		["role_id", "snp", "gun.root", "id", "namespace"],
		["nodes.0.xp_cost", 0, "gun.root", "xp_cost", "positive"],
		["nodes.0.rank", 1.5, "gun.root", "rank", "integer"],
		["nodes.0.column", "0", "gun.root", "column", "integer"],
	]
	for case: Array in cases:
		var document := _valid_document()
		_set_path(document, case[0], case[1])
		var path := _write_document(document, "scalar_%s.json" % str(case[0]).replace(".", "_"))
		_assert_error(path, case[2], case[3], case[4])


func test_effect_fields_stats_resources_classes_and_slots_are_validated() -> void:
	var cases := [
		["nodes.0.effect.stat", "LUCK", "effect.stat", "recognized"],
		["nodes.1.effect.resource", "res://missing_action.tres", "effect.resource", "does not exist"],
		["nodes.1.effect.resource", "res://data/heroes/asher/asher.tres", "effect.resource", "Action"],
		["nodes.1.effect.slot", 0, "effect.slot", "between 1 and 4"],
		["nodes.1.effect.slot", 5, "effect.slot", "between 1 and 4"],
	]
	for index in cases.size():
		var case: Array = cases[index]
		var document := _valid_document()
		_set_path(document, case[0], case[1])
		var path := _write_document(document, "effect_%d.json" % index)
		_assert_error(path, "gun." + ("root" if index == 0 else "action"), case[2], case[3])


func test_unreachable_nodes_are_rejected_without_partial_tree() -> void:
	var result = ProgressionJsonLoader.load_file(FIXTURES + "cycle.json")
	assert_null(result.tree)
	assert_gt(result.errors.size(), 0)
	assert_string_contains(_combined_errors(result.errors).to_lower(), "unreachable")


func test_catalog_load_is_transactional_and_summary_is_deterministic() -> void:
	var catalog := ProgressionCatalog.new()
	assert_eq(catalog.load_directory(FIXTURES), ERR_INVALID_DATA)
	assert_null(catalog.get_role("gun"))

	var directory := "user://progression_catalog_valid"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_document(_valid_document(), "progression_catalog_valid/zeta.json")
	var other := _valid_document()
	other.role_id = "snp"
	for node: Dictionary in other.nodes:
		node.id = str(node.id).replace("gun.", "snp.")
		if node.parent != null:
			node.parent = str(node.parent).replace("gun.", "snp.")
	_write_document(other, "progression_catalog_valid/alpha.json")
	assert_eq(catalog.load_directory(directory), OK)
	assert_not_null(catalog.get_role("gun"))
	assert_eq(catalog.get_summary("gun"), {
		"role_id": "gun", "revision": 3, "node_count": 4, "total_xp": 750,
		"maximum_rank": 3, "branch_count": 1,
		"effect_counts": {"stat": 1, "action": 1, "passive": 1, "shift_action": 1},
	})


func _assert_error(path: String, node_id: String, field: String, reason: String) -> void:
	var result = ProgressionJsonLoader.load_file(path)
	assert_null(result.tree)
	assert_gt(result.errors.size(), 0)
	var combined := _combined_errors(result.errors)
	assert_string_contains(combined, path)
	if not node_id.is_empty():
		assert_string_contains(combined, node_id)
	assert_string_contains(combined, field)
	assert_string_contains(combined, reason)


func _combined_errors(errors: Array) -> String:
	return "\n".join(errors.map(func(error): return str(error)))


func _valid_document() -> Dictionary:
	var file := FileAccess.open(FIXTURES + "valid_role.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text())


func _write_document(document: Dictionary, filename: String) -> String:
	var path := "user://" + filename
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	return path


func _set_path(document: Dictionary, path: String, value: Variant) -> void:
	var parts := path.split(".")
	var target: Variant = document
	for index in parts.size() - 1:
		var part := parts[index]
		target = target[int(part)] if part.is_valid_int() else target[part]
	var final := parts[-1]
	if final.is_valid_int():
		target[int(final)] = value
	else:
		target[final] = value
