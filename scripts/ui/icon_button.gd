class_name IconButton
extends Button

# A button that paints its own glyph instead of carrying a text label. Drawing the icons
# procedurally keeps them crisp at any size and lets the eraser icon show the literal
# division of the field, which no word can do as directly.
#
# The script's _draw runs on top of the theme's background, so press and hover states
# still come from the normal Button styling.

enum IconKind {
	DIFFICULTY,   # state: 0 = normal, 1 = easy
	TURN_COUNT,   # state: 0 = random, otherwise the fixed turn count
	ERASER_SHAPE, # state: EraserSystem.ErasureShape value
}

const COLOR_ON := Color(0.55, 0.80, 1.00)
const COLOR_OFF := Color(0.42, 0.47, 0.58)
const COLOR_WARN := Color(0.95, 0.30, 0.35)

@export var icon_kind: int = IconKind.DIFFICULTY

var icon_state: int = 0

func set_icon_state(p_state: int) -> void:
	icon_state = p_state
	queue_redraw()

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match icon_kind:
		IconKind.DIFFICULTY: _draw_difficulty(box)
		IconKind.TURN_COUNT: _draw_turn_count(box)
		IconKind.ERASER_SHAPE: _draw_eraser_shape(box)

# Rising bars: one lit for easy, all three for normal.
func _draw_difficulty(box: Rect2) -> void:
	var lit := 1 if icon_state == 1 else 3
	var bar_w := 6.0
	var gap := 5.0
	var total := bar_w * 3.0 + gap * 2.0
	var x := box.position.x + (box.size.x - total) * 0.5
	var base := box.position.y + box.size.y * 0.72

	for i in range(3):
		var h: float = 8.0 + i * 7.0
		var r := Rect2(x + i * (bar_w + gap), base - h, bar_w, h)
		if i < lit:
			draw_rect(r, COLOR_ON)
		else:
			draw_rect(r, COLOR_OFF, false, 1.5)

# A row of turn cells for a fixed count, or a cycle arrow for "random".
func _draw_turn_count(box: Rect2) -> void:
	var center := box.position + box.size * 0.5

	if icon_state <= 0:
		_draw_cycle_arrow(center, minf(box.size.x, box.size.y) * 0.30)
		return

	var count: int = icon_state
	var cell := 5.0
	var gap := 3.0
	var total := cell * count + gap * (count - 1)
	var x := center.x - total * 0.5
	var y := center.y - cell * 0.5

	for i in range(count):
		draw_rect(Rect2(x + i * (cell + gap), y, cell, cell), COLOR_ON)

func _draw_cycle_arrow(center: Vector2, radius: float) -> void:
	var start := -PI * 0.65
	var end := PI * 0.75
	draw_arc(center, radius, start, end, 24, COLOR_ON, 2.5)

	# Arrowhead at the open end of the arc, tangent to it
	var tip_angle := end
	var tip := center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
	var tangent := Vector2(-sin(tip_angle), cos(tip_angle))
	var normal := Vector2(cos(tip_angle), sin(tip_angle))
	draw_colored_polygon(PackedVector2Array([
		tip + tangent * 5.0,
		tip - tangent * 2.0 + normal * 4.0,
		tip - tangent * 2.0 - normal * 4.0,
	]), COLOR_ON)

# The field itself, divided the way this eraser divides it, with one slice lit.
func _draw_eraser_shape(box: Rect2) -> void:
	var center := box.position + box.size * 0.5
	var radius := minf(box.size.x, box.size.y) * 0.32
	var is_wedge := icon_state == EraserSystem.ErasureShape.DIAGONAL_WEDGE

	# The lit slice: a 90-degree wedge pointing up, or the whole top half
	var span: float = PI * 0.5 if is_wedge else PI
	_draw_sector(center, radius, -PI * 0.5 - span * 0.5, span, Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, 0.55))

	# The division lines: an X for wedges, an upright cross for half-planes
	var dirs: Array[Vector2] = []
	if is_wedge:
		dirs = [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]
	else:
		dirs = [Vector2(1, 0), Vector2(0, 1)]
	for d in dirs:
		draw_line(center - d * radius, center + d * radius, COLOR_ON, 1.5)

	draw_arc(center, radius, 0, TAU, 32, COLOR_ON, 2.0)

func _draw_sector(center: Vector2, radius: float, start_angle: float, span: float, color: Color) -> void:
	var steps := 16
	var pts := PackedVector2Array()
	pts.append(center)
	for i in range(steps + 1):
		var a := start_angle + span * (float(i) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
