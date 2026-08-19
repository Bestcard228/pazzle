class_name MiniBoard
extends RefCounted

# Drawing a small copy of the play field.
#
# The goal card, the solution strip and the turn timeline all show the same thing at
# different sizes: the ring, its input nodes, and some geometry laid over them. Each used
# to work out its own scale factor and then repeat `center + (p - board.center) * scale`
# at every point it drew, which is the sort of duplication that drifts -- one widget gets
# a fix and the others quietly keep the bug.
#
# These are static and draw into whichever CanvasItem is passed in, so a widget keeps its
# own colours and layout and only borrows the arithmetic.

# How much of the box the field fills, as a fraction of the smaller side.
static func scale_for(board_def: BoardDefinition, box_size: float, fill: float) -> float:
	if board_def == null or board_def.radius <= 0.0:
		return 1.0
	return (box_size * fill) / board_def.radius

static func to_screen(board_def: BoardDefinition, center: Vector2, scale: float, point: Vector2) -> Vector2:
	return center + (point - board_def.center) * scale

static func node_position(board_def: BoardDefinition, center: Vector2, scale: float, node_id: int) -> Vector2:
	return to_screen(board_def, center, scale, board_def.get_node_position(node_id))

static func radius(board_def: BoardDefinition, scale: float) -> float:
	return board_def.radius * scale

# The ring on its own.
static func draw_ring(canvas: CanvasItem, board_def: BoardDefinition, center: Vector2,
		scale: float, color: Color, width: float = 1.0) -> void:
	canvas.draw_arc(center, radius(board_def, scale), 0, TAU, 32, color, width)

# The ring and its nodes. `lit` maps a node id to the colour and size it should take;
# anything not in it is drawn in `dot_color` at `dot_size`. That one map covers all three
# callers: nobody lit, the nodes one shape uses, and the nodes each colour layer uses.
static func draw_field(canvas: CanvasItem, board_def: BoardDefinition, center: Vector2,
		scale: float, ring_color: Color, dot_color: Color, dot_size: float = 2.0,
		lit: Dictionary = {}) -> void:
	draw_ring(canvas, board_def, center, scale, ring_color)

	for i in range(board_def.node_count):
		var pos := node_position(board_def, center, scale, i)
		if lit.has(i):
			var mark: Dictionary = lit[i]
			canvas.draw_circle(pos, float(mark.get("size", dot_size + 1.0)), mark.get("color", dot_color))
		else:
			canvas.draw_circle(pos, dot_size, dot_color)

static func draw_geometry(canvas: CanvasItem, board_def: BoardDefinition, center: Vector2,
		scale: float, geometry: VectorGeometry, color: Color, width: float) -> void:
	if geometry == null:
		return
	for seg in geometry.segments:
		canvas.draw_line(
			to_screen(board_def, center, scale, seg.p1),
			to_screen(board_def, center, scale, seg.p2),
			color, width)

# A dashed ring: this turn is a deliberate skip, not a turn with nothing planned on it.
static func draw_skip_ring(canvas: CanvasItem, center: Vector2, ring_radius: float,
		color: Color, width: float = 2.0) -> void:
	var segments := 10
	for i in range(segments):
		if i % 2 == 1:
			continue
		var a0 := TAU * (float(i) / float(segments))
		var a1 := TAU * (float(i + 1) / float(segments))
		canvas.draw_arc(center, ring_radius, a0, a1, 4, color, width)

# One quarter of the field, pointing along `axis` -- the slice a wedge erasure takes.
static func wedge_polygon(center: Vector2, ring_radius: float, axis: Vector2,
		steps: int = 10) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(center)
	var start := axis.angle() - PI * 0.25
	for i in range(steps + 1):
		var angle := start + (PI * 0.5) * (float(i) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * ring_radius)
	return points

static func draw_wedge(canvas: CanvasItem, center: Vector2, ring_radius: float,
		axis: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(wedge_polygon(center, ring_radius, axis), color)

# The X the wedge eraser cuts the field along.
static func draw_division_cross(canvas: CanvasItem, center: Vector2, ring_radius: float,
		color: Color, width: float = 1.0) -> void:
	for d in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
		canvas.draw_line(center - d * ring_radius, center + d * ring_radius, color, width)
