extends GutTest

const PROJECT_THEME_PATH := "res://data/theme/default_theme.tres"
const ARCHIVO := preload("res://data/theme/fonts/archivo.tres")
const ARCHIVO_ITALIC := preload("res://data/theme/fonts/archivo_italic.tres")
const SUSE_MONO_BOLD := preload("res://data/theme/fonts/suse_mono_bold.tres")


func test_project_theme_is_bootstrap_safe_before_imported_fonts_exist() -> void:
	var source := FileAccess.get_file_as_string(PROJECT_THEME_PATH)

	assert_false(source.contains("res://data/theme/fonts/base_fonts/"))
	assert_false(source.contains("res://data/theme/fonts/archivo.tres"))
	assert_false(source.contains("res://data/theme/fonts/archivo_italic.tres"))
	assert_false(source.contains("res://data/theme/fonts/suse_mono_bold.tres"))


func test_runtime_project_theme_hydrates_the_authored_fonts() -> void:
	var project_theme := ThemeDB.get_project_theme()

	assert_not_null(project_theme)
	assert_same(project_theme.default_font, SUSE_MONO_BOLD)
	assert_same(project_theme.get_font(&"normal_font", &"RichTextLabel"), ARCHIVO)
	assert_same(project_theme.get_font(&"italics_font", &"RichTextLabel"), ARCHIVO_ITALIC)
