class_name DrawingBoard
extends Node2D

const COLOR_BOARD_FILL := Color(0.11, 0.13, 0.20, 1.0)
const COLOR_BOARD_RING := Color(0.30, 0.35, 0.45, 0.5)
const COLOR_DEAD_ZONE := Color(0.03, 0.03, 0.06, 0.55)
const COLOR_DIVIDER := Color(0.45, 0.52, 0.66, 0.45)
const COLOR_WARN := Color(0.95, 0.30, 0.35)
const COLOR_NODE := Color(0.40, 0.70, 1.00)
const COLOR_NODE_ACTIVE := Color(0.20, 0.95, 0.50)
const COLOR_INK := Color(0.95, 0.75, 0.20, 0.95)
const COLOR_CLEARED := Color(0.20, 0.95, 0.50)

var board_def: BoardDefinition
var current_surviving_geometry: VectorGeometry

# The region wiped at the end of the previous turn: already gone, shown as a dead zone.
var applied_erasure_phase: int = -1
# The region that will be wiped at the end of THIS turn. This is the single most
# important thing on screen, so it pulses and is hatched rather than merely tinted.
var upcoming_erasure_phase: int = -1

var is_cleared: bool = false
var active_swipe_nodes: Array[int] = []
var _pulse_t: float = 0.0

var node_screen_positions: Array[Vector2] = []
var board_center_screen: Vector2 = Vector2(270, 490)
var board_radius_screen: float = 170.0

func _ready() -> void:
	if board_def == null:
		board_def = BoardDefinition.new(8)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	recompute_screen_positions()
	set_process(true)

func _process(delta: float) -> void:
	# Only animate when there is something to warn about
	if upcoming_erasure_phase < 0 and not is_cleared:
		return
	_pulse_t += delta
	queue_redraw()

func _on_viewport_size_changed() -> void:
	recompute_screen_positions()
	queue_redraw()

func set_board_definition(p_board_def: BoardDefinition) -> void:
	self.board_def = p_board_def
	recompute_screen_positions()
	queue_redraw()

func set_surviving_geometry(geom: VectorGeometry) -> void:
	self.current_surviving_geometry = geom
	queue_redraw()

func set_erasure_phases(p_applied: int, p_upcoming: int) -> void:
	self.applied_erasure_phase = p_applied
	self.upcoming_erasure_phase = p_upcoming
	queue_redraw()

func set_cleared(p_cleared: bool) -> void:
	self.is_cleared = p_cleared
	queue_redraw()

func set_active_swipe(nodes: Array[int]) -> void:
	self.active_swipe_nodes = nodes.duplicate()
	queue_redraw()

func recompute_screen_positions() -> void:
	node_screen_positions.clear()
	if board_def == null:
		return

	var vp_rect := get_viewport_rect()
	if vp_rect.size.x > 0 and vp_rect.size.y > 0:
		board_center_screen = Vector2(vp_rect.size.x * 0.5, vp_rect.size.y * 0.52)
		board_radius_screen = min(vp_rect.size.x, vp_rect.size.y) * 0.32
	else:
		board_center_screen = Vector2(270, 490)
		board_radius_screen = 170.0

	var N := board_def.node_count
	for i in range(N):
		var angle := -PI / 2.0 + (i * TAU / float(N))
		var pos := board_center_screen + Vector2(cos(angle), sin(angle)) * board_radius_screen
		node_screen_positions.append(pos)

# Converts internal grid Vector2 to screen Vector2
func grid_to_screen(grid_pos: Vector2) -> Vector2:
	if board_def == null:
		return grid_pos
	var offset := grid_pos - board_def.center
	var scale_factor := board_radius_screen / board_def.radius
	return board_center_screen + offset * scale_factor

func _is_wedge_mode() -> bool:
	return board_def != null and board_def.erasure_shape == EraserSystem.ErasureShape.DIAGONAL_WEDGE

# Screen-space polygon for an erasure phase. In wedge mode this is the 90-degree slice cut
# by the X; in half-plane mode it is the old half of the board. Either way it matches the
# area the simulator actually clips against.
func _phase_polygon(phase: int) -> PackedVector2Array:
	var reach := board_radius_screen * 1.35
	var c := board_center_screen

	if _is_wedge_mode():
		var axis := EraserSystem.get_phase_axis(phase)
		# Reach past the corner so the wedge always covers the visible field
		var corner_reach := reach * 1.45
		return PackedVector2Array([
			c,
			c + axis.rotated(-PI / 4.0) * corner_reach,
			c + axis * corner_reach,
			c + axis.rotated(PI / 4.0) * corner_reach,
		])

	var r := _phase_rect(phase)
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])

# Screen-space rect for a half-plane erasure phase.
func _phase_rect(phase: int) -> Rect2:
	var extent := board_radius_screen * 1.35
	var c := board_center_screen

	match posmod(phase, EraserSystem.PHASE_COUNT):
		EraserSystem.ErasureRegion.TOP:
			return Rect2(c.x - extent, c.y - extent, extent * 2.0, extent)
		EraserSystem.ErasureRegion.RIGHT:
			return Rect2(c.x, c.y - extent, extent, extent * 2.0)
		EraserSystem.ErasureRegion.BOTTOM:
			return Rect2(c.x - extent, c.y, extent * 2.0, extent)
		EraserSystem.ErasureRegion.LEFT:
			return Rect2(c.x - extent, c.y - extent, extent, extent * 2.0)
		_:
			return Rect2()

# Unit vector pointing from the board centre into the middle of a phase's region.
func _phase_direction(phase: int) -> Vector2:
	match posmod(phase, EraserSystem.PHASE_COUNT):
		EraserSystem.ErasureRegion.TOP: return Vector2(0, -1)
		EraserSystem.ErasureRegion.RIGHT: return Vector2(1, 0)
		EraserSystem.ErasureRegion.BOTTOM: return Vector2(0, 1)
		EraserSystem.ErasureRegion.LEFT: return Vector2(-1, 0)
		_: return Vector2.ZERO

func _draw() -> void:
	if board_def == null:
		return

	_draw_board_face()
	_draw_division_lines()
	_draw_dead_zone()
	_draw_upcoming_erasure()
	_draw_node_ring()
	_draw_surviving_geometry()
	_draw_active_swipe()
	_draw_cleared_glow()

func _draw_board_face() -> void:
	draw_circle(board_center_screen, board_radius_screen * 1.12, COLOR_BOARD_FILL)
	draw_arc(board_center_screen, board_radius_screen, 0, TAU, 64, COLOR_BOARD_RING, 2.0)

# What is already gone. Flat and dark so it reads as "dead", never confused with the
# pulsing warning for what is about to go.
func _draw_dead_zone() -> void:
	if applied_erasure_phase < 0:
		return
	draw_colored_polygon(_phase_polygon(applied_erasure_phase), COLOR_DEAD_ZONE)

# The standing division of the field: an X through the centre in wedge mode, a single
# axis in half-plane mode. Always visible, so the player can see which slice any part of
# their drawing sits in before committing to it.
func _draw_division_lines() -> void:
	var reach := board_radius_screen * 1.12
	var c := board_center_screen

	if _is_wedge_mode():
		for diagonal in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
			draw_line(c - diagonal * reach, c + diagonal * reach, COLOR_DIVIDER, 2.0)
	else:
		draw_line(c - Vector2(reach, 0), c + Vector2(reach, 0), COLOR_DIVIDER, 2.0)
		draw_line(c - Vector2(0, reach), c + Vector2(0, reach), COLOR_DIVIDER, 2.0)

func _draw_upcoming_erasure() -> void:
	if upcoming_erasure_phase < 0:
		return

	var pulse := 0.5 + 0.5 * sin(_pulse_t * 3.0)
	var wash := Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, lerp(0.10, 0.22, pulse))
	var stripe := Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, 0.30)
	var edge := Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, 0.85)

	# Body: soft warning wash that breathes
	draw_colored_polygon(_phase_polygon(upcoming_erasure_phase), wash)

	var dir := _phase_direction(upcoming_erasure_phase)
	var reach := board_radius_screen * 1.28

	if _is_wedge_mode():
		# Radial teeth fanning across the wedge, plus its two arms of the X lit up. Texture
		# keeps the doomed slice legible without relying on the red wash alone.
		var arm_a := dir.rotated(-PI / 4.0)
		var arm_b := dir.rotated(PI / 4.0)
		for i in range(1, 8):
			var ray := arm_a.rotated((PI / 2.0) * (float(i) / 8.0))
			draw_line(board_center_screen, board_center_screen + ray * reach, stripe, 2.0)
		draw_line(board_center_screen, board_center_screen + arm_a * reach, edge, 3.0)
		draw_line(board_center_screen, board_center_screen + arm_b * reach, edge, 3.0)
	else:
		var rect := _phase_rect(upcoming_erasure_phase)
		_draw_hatch(rect, stripe, 16.0, 2.0)
		# The cut line itself, along the centre axis
		var axis := Vector2(dir.y, dir.x).abs()
		draw_line(board_center_screen - axis * reach, board_center_screen + axis * reach, edge, 3.0)

	# A blade marker riding the outer edge, pointing at what it is about to remove
	_draw_blade_marker(dir, pulse)

func _draw_blade_marker(dir: Vector2, pulse: float) -> void:
	var tip := board_center_screen + dir * (board_radius_screen * (1.20 + 0.05 * pulse))
	var side := Vector2(-dir.y, dir.x) * 14.0
	var back := tip + dir * 18.0

	var pts := PackedVector2Array([tip, back + side, back - side])
	draw_colored_polygon(pts, Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, lerp(0.6, 1.0, pulse)))

# 45-degree hatch lines clipped to `rect`.
func _draw_hatch(rect: Rect2, color: Color, spacing: float, width: float) -> void:
	var dir := Vector2(1, 1).normalized()
	var span := rect.size.x + rect.size.y
	var steps := int(span / spacing)

	for i in range(steps + 1):
		var origin := Vector2(rect.position.x - rect.size.y + i * spacing, rect.position.y)
		var seg := _clip_ray_to_rect(origin, dir, rect)
		if seg.size() == 2:
			draw_line(seg[0], seg[1], color, width)

# Slab clip of an infinite line through `origin` along `dir` against an axis-aligned rect.
func _clip_ray_to_rect(origin: Vector2, dir: Vector2, rect: Rect2) -> PackedVector2Array:
	var t_min := -INF
	var t_max := INF
	var lo := rect.position
	var hi := rect.position + rect.size

	for axis in 2:
		var o: float = origin[axis]
		var d: float = dir[axis]
		if absf(d) < 0.00001:
			if o < lo[axis] or o > hi[axis]:
				return PackedVector2Array()
			continue
		var t1 := (lo[axis] - o) / d
		var t2 := (hi[axis] - o) / d
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)

	if t_min >= t_max:
		return PackedVector2Array()
	return PackedVector2Array([origin + dir * t_min, origin + dir * t_max])

func _draw_node_ring() -> void:
	for i in range(node_screen_positions.size()):
		var pos := node_screen_positions[i]
		var is_selected := active_swipe_nodes.has(i)
		var node_color := COLOR_NODE_ACTIVE if is_selected else COLOR_NODE

		draw_circle(pos, 18.0, node_color)
		draw_circle(pos, 14.0, COLOR_BOARD_FILL)
		if is_selected:
			draw_circle(pos, 8.0, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.8))

func _draw_surviving_geometry() -> void:
	if current_surviving_geometry == null or current_surviving_geometry.is_empty():
		return

	for seg in current_surviving_geometry.segments:
		var s1 := grid_to_screen(seg.p1)
		var s2 := grid_to_screen(seg.p2)
		draw_line(s1, s2, Color(1.0, 0.85, 0.3, 0.35), 8.0)
		draw_line(s1, s2, COLOR_INK, 4.0)

func _draw_active_swipe() -> void:
	if active_swipe_nodes.size() < 2:
		return

	for i in range(active_swipe_nodes.size() - 1):
		var p1 := node_screen_positions[active_swipe_nodes[i]]
		var p2 := node_screen_positions[active_swipe_nodes[i + 1]]
		draw_line(p1, p2, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.9), 4.0)

func _draw_cleared_glow() -> void:
	if not is_cleared:
		return
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 4.0)
	draw_arc(board_center_screen, board_radius_screen * 1.12, 0, TAU, 72,
		Color(COLOR_CLEARED.r, COLOR_CLEARED.g, COLOR_CLEARED.b, lerp(0.35, 0.9, pulse)), 5.0)
