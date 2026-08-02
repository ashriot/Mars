extends RefCounted
class_name PresentationOperation

signal completed

var is_completed := false


static func already_completed() -> PresentationOperation:
	var operation := PresentationOperation.new()
	operation.complete()
	return operation


func complete() -> void:
	if is_completed:
		return
	is_completed = true
	completed.emit()
