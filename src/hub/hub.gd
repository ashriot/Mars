extends Control
class_name Hub

signal head_out

@onready var head_out_button: Button = $Actions/HeadOut

func _ready():
	AudioManager.play_music("hub")


func _on_head_out_pressed() -> void:
	head_out.emit()
