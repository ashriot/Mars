class_name RichTooltip
extends Node

# Multi-line text box in Inspector
@export_multiline var bbcode_text: String = ""


var _parent_control: Control

func _ready():
	# 1. Find the parent
	var parent = get_parent()
	if not parent is Control:
		push_warning("RichTooltip must be a child of a Control node!")
		return

	_parent_control = parent

	# 2. Connect to parent's signals
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)

	# 3. Disable default tooltip to prevent double-ups
	_parent_control.tooltip_text = ""

func _on_mouse_entered():
	var text_to_show = bbcode_text
	if text_to_show != "":
		TooltipManager.request_tooltip(text_to_show)

func _on_mouse_exited():
	TooltipManager.hide_tooltip()
