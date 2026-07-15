extends Control
class_name CTBGauge


enum Faction { HERO, ENEMY }

const TICKS_PER_BAND := 20
const ANIMATION_DURATION := 0.30
const GAUGE_WIDTH := 6.0
const CORNER_RADIUS := 10.0
const HERO_COLORS := [
	Color("56e5ff"),
	Color("24b9e8"),
	Color("127da8"),
]
const ENEMY_COLORS := [
	Color("ff5bc8"),
	Color("d52d9b"),
	Color("941a70"),
]
const CURRENT_COLOR := Color("ffc94a")
const TRACK_COLOR := Color(0.12, 0.15, 0.2, 0.9)

var displayed_ticks := 0.0
var _start_ticks := 0.0
var _target_ticks := 0.0
var _animation_elapsed := 0.0
var _is_animating := false
var _faction := Faction.HERO
var _is_current := false


static func band_fills(ticks: float) -> Array[float]:
	var fills: Array[float] = []
	for band in 3:
		fills.append(clampf(float(ticks - band * TICKS_PER_BAND) / TICKS_PER_BAND, 0.0, 1.0))
	return fills


static func partial_polyline(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	if points.size() < 2 or fraction <= 0.0:
		return PackedVector2Array()
	if fraction >= 1.0:
		return points
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	var target := total * fraction
	var traversed := 0.0
	var result := PackedVector2Array([points[0]])
	for index in range(1, points.size()):
		var segment := points[index - 1].distance_to(points[index])
		if traversed + segment >= target:
			var weight := (target - traversed) / segment
			result.append(points[index - 1].lerp(points[index], weight))
			break
		result.append(points[index])
		traversed += segment
	return result


static func rounded_rect_path(
	rect: Rect2,
	radius: float,
	segments_per_corner: int = 8,
) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	var points := PackedVector2Array()
	for corner in 4:
		for step in segments_per_corner + 1:
			var angle: float = starts[corner] + PI * 0.5 * float(step) / segments_per_corner
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	points.append(points[0])
	return points


func configure(
	ticks: int,
	faction: Faction,
	is_current: bool,
	animate := false,
) -> void:
	_faction = faction
	_is_current = is_current
	_target_ticks = float(maxi(ticks, 0))
	if animate and not is_equal_approx(displayed_ticks, _target_ticks):
		_start_ticks = displayed_ticks
		_animation_elapsed = 0.0
		_is_animating = true
		set_process(true)
	else:
		displayed_ticks = _target_ticks
		_start_ticks = displayed_ticks
		_animation_elapsed = ANIMATION_DURATION
		_is_animating = false
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_advance_animation(delta)


func _advance_animation(delta: float) -> void:
	if not _is_animating:
		return
	_animation_elapsed = minf(_animation_elapsed + maxf(delta, 0.0), ANIMATION_DURATION)
	var weight := _animation_elapsed / ANIMATION_DURATION
	displayed_ticks = lerpf(_start_ticks, _target_ticks, weight)
	queue_redraw()
	if is_equal_approx(_animation_elapsed, ANIMATION_DURATION):
		displayed_ticks = _target_ticks
		_is_animating = false
		set_process(false)


func _draw() -> void:
	var inset := GAUGE_WIDTH * 0.5
	var path := rounded_rect_path(
		Rect2(Vector2.ONE * inset, size - Vector2.ONE * GAUGE_WIDTH),
		CORNER_RADIUS,
	)
	draw_polyline(path, TRACK_COLOR, GAUGE_WIDTH, true)
	if _is_current:
		draw_polyline(path, CURRENT_COLOR, GAUGE_WIDTH, true)
		return
	var colors := HERO_COLORS if _faction == Faction.HERO else ENEMY_COLORS
	var fills := band_fills(displayed_ticks)
	for band in 3:
		var partial := partial_polyline(path, fills[band])
		if partial.size() >= 2:
			draw_polyline(partial, colors[band], GAUGE_WIDTH - band * 2.0, true)
