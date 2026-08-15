class_name IconButton
extends Button

# A button that paints its own glyph instead of carrying a text label. Drawing the icons
# procedurally keeps them crisp at any size and lets the eraser icon show the literal
# division of the field, which no word can do as directly.
#
# The script's _draw runs on top of the theme's background, so press and hover states
# still come from the normal Button styling.

enum IconKind {
	DIFFICULTY,   # state: 1-based rank on the difficulty ladder, 0 = Auto (shuffles tiers)
	TURN_COUNT,   # state: 0 = random, otherwise the fixed turn count
	ERASER_SHAPE, # state: EraserSystem.ErasureShape value
	REVEAL,       # state: 0 = solution hidden, 1 = solution shown
	HINT,         # state: 0 = dormant, 1 = offered
	PIXEL,        # state: 0 = filter off, 1 = filter on
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
		IconKind.REVEAL: _draw_reveal(box)
		IconKind.HINT: _draw_hint(box)
		IconKind.PIXEL: _draw_pixel(box)

# Rising bars, one per rung of the ladder: Easy, Easy+, Easy++, Medium. State 0 is Auto,
# where the ladder is drawn empty with the shuffle arrow over it.
func _draw_difficulty(box: Rect2) -> void:
	var bars := 4
	if icon_state <= 0:
		_draw_difficulty_bars(box, 0)
		_draw_cycle_arrow(box.position + box.size * 0.5, minf(box.size.x, box.size.y) * 0.26)
		return
	_draw_difficulty_bars(box, clampi(icon_state, 1, bars))

func _draw_difficulty_bars(box: Rect2, lit: int) -> void:
	var bars := 4
	var bar_w := 5.0
	var gap := 4.0
	var total := bar_w * bars + gap * (bars - 1)
	var x := box.position.x + (box.size.x - total) * 0.5
	var base := box.position.y + box.size.y * 0.74

	for i in range(bars):
		var h: float = 7.0 + i * 5.0
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

# An eye: open when the solution is showing, struck through when it is hidden.
func _draw_reveal(box: Rect2) -> void:
	var center := box.position + box.size * 0.5
	var w := minf(box.size.x, box.size.y) * 0.38
	var h := w * 0.62
	var shown := icon_state == 1
	var color := COLOR_ON if shown else COLOR_OFF

	# Lid outlines, drawn as two arcs bulging away from the centre line
	var steps := 14
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in range(steps + 1):
		var tx := -1.0 + 2.0 * (float(i) / float(steps))
		var bulge := (1.0 - tx * tx) * h
		upper.append(center + Vector2(tx * w, -bulge))
		lower.append(center + Vector2(tx * w, bulge))

	for i in range(steps):
		draw_line(upper[i], upper[i + 1], color, 2.0)
		draw_line(lower[i], lower[i + 1], color, 2.0)

	if shown:
		draw_circle(center, h * 0.62, color)
	else:
		draw_line(center + Vector2(-w, h), center + Vector2(w, -h), color, 2.5)

# A lamp: dark while the player is still working it out, lit once a hint is on offer.
func _draw_hint(box: Rect2) -> void:
	var center := box.position + box.size * 0.5
	var offered := icon_state == 1
	var color := Color(1.00, 0.85, 0.35) if offered else COLOR_OFF
	var r := minf(box.size.x, box.size.y) * 0.20

	var bulb := center - Vector2(0, r * 0.35)
	draw_arc(bulb, r, 0, TAU, 24, color, 2.0)
	if offered:
		draw_circle(bulb, r * 0.55, Color(color.r, color.g, color.b, 0.45))

	# Screw base
	var base_w := r * 0.8
	var base_y := bulb.y + r * 0.9
	for i in range(2):
		var y := base_y + i * 4.0
		draw_line(Vector2(center.x - base_w, y), Vector2(center.x + base_w, y), color, 2.0)

	# Rays only when the lamp is lit
	if not offered:
		return
	for i in range(6):
		var a := -PI + (float(i) + 0.5) * (PI / 6.0)
		var dir := Vector2(cos(a), sin(a))
		draw_line(bulb + dir * (r * 1.35), bulb + dir * (r * 1.85), color, 2.0)

# A circle rendered two ways across the diagonal: smooth on one side, stepped into blocks
# on the other -- the icon shows the filter's own effect.
func _draw_pixel(box: Rect2) -> void:
	var center := box.position + box.size * 0.5
	var r := minf(box.size.x, box.size.y) * 0.30
	var on := icon_state == 1
	var color := COLOR_ON if on else COLOR_OFF

	var cell := r * 0.5
	var steps := 3
	for gx in range(-steps, steps):
		for gy in range(-steps, steps):
			var cell_pos := center + Vector2(gx, gy) * cell
			var cell_center := cell_pos + Vector2(cell, cell) * 0.5
			if cell_center.distance_to(center) > r:
				continue
			# Below the diagonal stays smooth, above it breaks into blocks
			var stepped := (gx + gy) < 0 or on
			if stepped:
				draw_rect(Rect2(cell_pos + Vector2.ONE * 0.5, Vector2(cell - 1.0, cell - 1.0)), color)
			else:
				draw_circle(cell_center, cell * 0.34, color)

	if not on:
		draw_arc(center, r * 1.25, 0, TAU, 28, COLOR_OFF, 1.5)

func _draw_sector(center: Vector2, radius: float, start_angle: float, span: float, color: Color) -> void:
	var steps := 16
	var pts := PackedVector2Array()
	pts.append(center)
	for i in range(steps + 1):
		var a := start_angle + span * (float(i) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
