extends Node

const CONTENT_ROOT := "res://data/progression/"

var catalog: ProgressionCatalog
var service: ProgressionService


func get_content_revisions() -> Dictionary:
	var revisions := {}
	if catalog == null:
		return revisions
	for role_id: String in catalog.role_ids:
		var tree := catalog.get_role(role_id)
		if tree != null:
			revisions[role_id] = tree.version
	return revisions


func initialize_fresh_hero(hero: HeroData) -> bool:
	if catalog == null:
		return false
	return ProgressionInitializer.initialize_hero(hero, catalog).success


func _ready() -> void:
	var loaded_catalog := ProgressionCatalog.new()
	var result := loaded_catalog.load_directory(CONTENT_ROOT)
	if result != OK:
		for content_error: ProgressionContentError in loaded_catalog.errors:
			push_error(str(content_error))
		return
	catalog = loaded_catalog
	service = ProgressionService.new(catalog)
