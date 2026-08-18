extends GutTest

const PROJECT_THEME_PATH := "res://data/theme/default_theme.tres"
const OXANIUM := preload("res://data/theme/fonts/oxanium.tres")
const OXANIUM_ITALIC := preload("res://data/theme/fonts/oxanium_italic.tres")
const OXANIUM_BOLD := preload("res://data/theme/fonts/oxanium_bold.tres")
const OXANIUM_REGULAR := preload("res://data/theme/fonts/oxanium_regular.tres")

# OpenType feature tags are stored (and exposed at runtime) as their 32-bit
# integer form, not as StringNames -- FontVariation.opentype_features always
# keys by tag int, even for resources authored entirely in the editor.
const TNUM_FEATURE_TAG := 1953396077


func test_project_theme_is_bootstrap_safe_before_imported_fonts_exist() -> void:
	var source := FileAccess.get_file_as_string(PROJECT_THEME_PATH)

	assert_false(source.contains("res://data/theme/fonts/base_fonts/"))
	assert_false(source.contains("res://data/theme/fonts/oxanium.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_italic.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_bold.tres"))
	assert_false(source.contains("res://data/theme/fonts/oxanium_regular.tres"))


func test_runtime_project_theme_hydrates_the_authored_fonts() -> void:
	var project_theme := ThemeDB.get_project_theme()

	assert_not_null(project_theme)
	assert_same(project_theme.default_font, OXANIUM_BOLD)
	assert_same(project_theme.get_font(&"normal_font", &"RichTextLabel"), OXANIUM)
	assert_same(project_theme.get_font(&"italics_font", &"RichTextLabel"), OXANIUM_ITALIC)


func test_authored_fonts_use_tabular_figures() -> void:
	for font: FontVariation in [OXANIUM, OXANIUM_ITALIC, OXANIUM_BOLD, OXANIUM_REGULAR]:
		assert_eq(font.opentype_features.get(TNUM_FEATURE_TAG, 0), 1)
