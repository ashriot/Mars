extends GutTest

const FIXTURES := "res://test/fixtures/progression/"

class FailingNestedCatalog extends ProgressionCatalog:
	var blocked_suffix := ""
	func _open_directory(path: String) -> DirAccess:
		if not blocked_suffix.is_empty() and path.ends_with(blocked_suffix):
			return null
		return DirAccess.open(path)


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


func test_load_result_and_catalog_diagnostics_are_defensive_and_exclusive() -> void:
	var success = ProgressionJsonLoader.load_file(FIXTURES + "valid_role.json")
	var exposed_success_errors: Array = success.errors
	exposed_success_errors.append(ProgressionContentError.new("fake", "", "fake", "fake"))
	assert_not_null(success.tree)
	assert_eq(success.errors.size(), 0)
	var factory_success = ProgressionJsonLoader.LoadResult.success(success.tree)
	assert_true(is_same(factory_success.tree, success.tree))
	assert_eq(factory_success.errors.size(), 0)

	var failure = ProgressionJsonLoader.load_file(FIXTURES + "invalid_effect.json")
	var exposed_failure_errors: Array = failure.errors
	exposed_failure_errors.clear()
	assert_null(failure.tree)
	assert_gt(failure.errors.size(), 0)
	var factory_failure = ProgressionJsonLoader.LoadResult.failure(failure.errors)
	assert_null(factory_failure.tree)
	assert_gt(factory_failure.errors.size(), 0)
	var invalid_success = ProgressionJsonLoader.LoadResult.success(null)
	var invalid_failure = ProgressionJsonLoader.LoadResult.failure([])
	assert_null(invalid_success.tree)
	assert_gt(invalid_success.errors.size(), 0)
	assert_null(invalid_failure.tree)
	assert_gt(invalid_failure.errors.size(), 0)

	var catalog := ProgressionCatalog.new()
	assert_eq(catalog.load_directory(FIXTURES), ERR_INVALID_DATA)
	var exposed_catalog_errors: Array = catalog.errors
	exposed_catalog_errors.clear()
	assert_gt(catalog.errors.size(), 0)


func test_bare_load_result_constructor_is_an_exclusive_sentinel_failure() -> void:
	var result := ProgressionJsonLoader.LoadResult.new()
	assert_null(result.tree)
	assert_eq(result.errors.size(), 1)
	assert_eq(result.errors[0].field, "result")
	assert_string_contains(result.errors[0].reason, "factory")


func test_content_errors_are_immutable_and_defensive_arrays_cannot_replace_them() -> void:
	var result = ProgressionJsonLoader.load_file(FIXTURES + "invalid_effect.json")
	var retained_error: ProgressionContentError = result.errors[0]
	var original_reason := retained_error.reason
	retained_error.set("reason", "changed by caller")
	assert_eq(retained_error.reason, original_reason)

	var exposed_errors: Array[ProgressionContentError] = result.errors
	exposed_errors[0] = ProgressionContentError.new("fake", "", "fake", "fake")
	assert_true(is_same(result.errors[0], retained_error))


func test_failed_catalog_reload_preserves_previously_committed_roles() -> void:
	var valid_directory := "user://progression_reload_valid"
	_write_document(_valid_document(), "progression_reload_valid/gun.json")
	var catalog := ProgressionCatalog.new()
	assert_eq(catalog.load_directory(valid_directory), OK)
	var committed_tree = catalog.get_role("gun")

	assert_eq(catalog.load_directory(FIXTURES), ERR_INVALID_DATA)
	assert_true(is_same(catalog.get_role("gun"), committed_tree))


func test_catalog_rejects_duplicate_roles_and_orders_cross_file_errors_by_filename() -> void:
	var duplicate_directory := "user://progression_duplicate_roles"
	_write_document(_valid_document(), "progression_duplicate_roles/zeta.json")
	_write_document(_valid_document(), "progression_duplicate_roles/alpha.json")
	var catalog := ProgressionCatalog.new()
	assert_eq(catalog.load_directory(duplicate_directory), ERR_INVALID_DATA)
	assert_string_contains(_combined_errors(catalog.errors), "Duplicate role ID 'gun'")
	assert_null(catalog.get_role("gun"))

	var ordered_directory := "user://progression_ordered_errors"
	var alpha := _valid_document()
	alpha.nodes[0].xp_cost = 0
	var zeta := _valid_document()
	zeta.nodes[0].effect.stat = "LUCK"
	_write_document(zeta, "progression_ordered_errors/zeta.json")
	_write_document(alpha, "progression_ordered_errors/alpha.json")
	assert_eq(catalog.load_directory(ordered_directory), ERR_INVALID_DATA)
	assert_eq(catalog.errors[0].source_path.get_file(), "alpha.json")
	assert_eq(catalog.errors[-1].source_path.get_file(), "zeta.json")


func test_passive_and_shift_action_validate_expected_resource_class_independently() -> void:
	for node_index in [2, 3]:
		var document := _valid_document()
		document.nodes[node_index].effect.resource = "res://data/heroes/asher/asher.tres"
		var path := _write_document(document, "resource_class_%d.json" % node_index)
		_assert_error(path, str(document.nodes[node_index].id), "effect.resource", "Action")


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

func test_nested_directory_open_failure_is_reported_and_preserves_committed_roles() -> void:
	var valid_directory := "user://progression_nested_open_valid"
	_write_document(_valid_document(), "progression_nested_open_valid/gun.json")
	var catalog := FailingNestedCatalog.new()
	assert_eq(catalog.load_directory(valid_directory), OK)
	var committed_tree := catalog.get_role("gun")

	var nested_directory := "user://progression_nested_open_failure"
	_write_document(_valid_document(), "progression_nested_open_failure/visible/gun.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(nested_directory.path_join("blocked")))
	catalog.blocked_suffix = "/blocked"
	assert_eq(catalog.load_directory(nested_directory), ERR_CANT_OPEN)
	assert_true(is_same(catalog.get_role("gun"), committed_tree))
	assert_eq(catalog.errors.size(), 1)
	if not catalog.errors.is_empty():
		assert_eq(catalog.errors[0].source_path, nested_directory.path_join("blocked"))
		assert_eq(catalog.errors[0].field, "directory")


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
