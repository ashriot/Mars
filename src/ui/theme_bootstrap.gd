extends Node

const ARCHIVO_PATH := "res://data/theme/fonts/archivo.tres"
const ARCHIVO_ITALIC_PATH := "res://data/theme/fonts/archivo_italic.tres"
const SUSE_MONO_BOLD_PATH := "res://data/theme/fonts/suse_mono_bold.tres"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not hydrate_project_theme():
		push_error("ThemeBootstrap could not hydrate the project theme fonts.")


func hydrate_project_theme() -> bool:
	var project_theme := ThemeDB.get_project_theme()
	var archivo := load(ARCHIVO_PATH) as Font
	var archivo_italic := load(ARCHIVO_ITALIC_PATH) as Font
	var suse_mono_bold := load(SUSE_MONO_BOLD_PATH) as Font
	if project_theme == null \
		or archivo == null \
		or archivo_italic == null \
		or suse_mono_bold == null:
		return false
	project_theme.default_font = suse_mono_bold
	project_theme.set_font(&"normal_font", &"RichTextLabel", archivo)
	project_theme.set_font(&"italics_font", &"RichTextLabel", archivo_italic)
	return true
