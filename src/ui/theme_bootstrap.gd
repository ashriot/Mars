extends Node

const OXANIUM_PATH := "res://data/theme/fonts/oxanium.tres"
const OXANIUM_ITALIC_PATH := "res://data/theme/fonts/oxanium_italic.tres"
const OXANIUM_BOLD_PATH := "res://data/theme/fonts/oxanium_bold.tres"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not hydrate_project_theme():
		push_error("ThemeBootstrap could not hydrate the project theme fonts.")


func hydrate_project_theme() -> bool:
	var project_theme := ThemeDB.get_project_theme()
	var oxanium := load(OXANIUM_PATH) as Font
	var oxanium_italic := load(OXANIUM_ITALIC_PATH) as Font
	var oxanium_bold := load(OXANIUM_BOLD_PATH) as Font
	if project_theme == null \
		or oxanium == null \
		or oxanium_italic == null \
		or oxanium_bold == null:
		return false
	project_theme.default_font = oxanium_bold
	project_theme.set_font(&"normal_font", &"RichTextLabel", oxanium)
	project_theme.set_font(&"italics_font", &"RichTextLabel", oxanium_italic)
	return true
