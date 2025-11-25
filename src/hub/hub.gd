extends Control
class_name Hub

signal head_out

@onready var bits_label: Label = $UI/BitsLabel
@onready var head_out_button: Button = $Actions/HeadOut


func _ready():
	bits_label.text = "Bits: %d" % SaveSystem.bits

func _on_head_out_pressed() -> void:
	head_out.emit()
