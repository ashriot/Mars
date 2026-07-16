class_name ResponsiveViewportFixture
extends RefCounted

const DisplayProfileServiceScript = preload("res://src/ui/display/display_profile_service.gd")


static func output_scale_for(window_size: Vector2i) -> float:
	return DisplayProfileServiceScript.output_scale_for(window_size)


static func logical_size_for(window_size: Vector2i) -> Vector2:
	return DisplayProfileServiceScript.expanded_logical_size_for(window_size)


static func physical_rect(control: Control, window_size: Vector2i) -> Rect2:
	var scale := output_scale_for(window_size)
	return Rect2(control.global_position * scale, control.size * scale)


static func fits_output(control: Control, window_size: Vector2i, tolerance := 1.0) -> bool:
	var rect := physical_rect(control, window_size)
	return rect.position.x >= -tolerance and rect.position.y >= -tolerance \
		and rect.end.x <= window_size.x + tolerance and rect.end.y <= window_size.y + tolerance
