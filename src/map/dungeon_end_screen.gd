extends Control
class_name DungeonEndScreen

signal finished

@onready var title_label: Label = $Panel/Header/Label
@onready var continue_button: Button = $Panel/Button
@onready var bits_found: Label = $Panel/VBox/GridContainer/BitsValue
@onready var xp_earned: Label = $Panel/VBox/GridContainer/XpValue
@onready var modifier_label: Label = $Panel/VBox/GridContainer/ModValue
@onready var total_bits: Label = $Panel/VBox/GridContainer/TotalBitsValue
@onready var total_xp: Label = $Panel/VBox/GridContainer/TotalXpValue

var _result: RunManager.RunResult

func setup(result: RunManager.RunResult):
	modulate.a = 0.0
	_result = result

	var raw_bits = RunManager.run_bits
	var raw_xp = RunManager.run_xp
	var modifier = 1.0
	var title_text = ""
	var color = Color.WHITE

	match result:
		RunManager.RunResult.SUCCESS:
			title_text = "MISSION COMPLETE"
			color = Color.GREEN
			modifier = 1.0
		RunManager.RunResult.RETREAT:
			title_text = "TACTICAL RETREAT"
			color = Color.YELLOW
			modifier = 0.5
		RunManager.RunResult.DEFEAT:
			title_text = "CRITICAL FAILURE"
			color = Color.RED
			modifier = 0.0

	title_label.text = title_text
	title_label.modulate = color
	modifier_label.modulate = color
	modifier_label.text = str(modifier * 100) + "%"

	bits_found.text = str(int(raw_bits))
	xp_earned.text = str(int(raw_xp))
	total_bits.text = str(int(raw_bits * modifier))
	total_xp.text = str(int(raw_xp * modifier))

	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		0.25
	)

func _on_continue_pressed():
	RunManager.commit_rewards(_result)
	finished.emit()
