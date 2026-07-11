extends Node

const CONTENT_ROOT := "res://data/progression/"

var catalog: ProgressionCatalog
var service: ProgressionService


func _ready() -> void:
	var loaded_catalog := ProgressionCatalog.new()
	var result := loaded_catalog.load_directory(CONTENT_ROOT)
	if result != OK:
		for content_error: ProgressionContentError in loaded_catalog.errors:
			push_error(str(content_error))
		return
	catalog = loaded_catalog
	service = ProgressionService.new(catalog)
