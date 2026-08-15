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

# Press animation constants
const PRESS_SCALE_MIN := 1.0
const PRESS_SCALE_MAX := 1.3
const PRESS_PULSE_SPEED := 8.0  # Oscillations per second
const PRESS_COLOR_SHIFT := 0.3  # Amount to shift toward white during press

var board_def: BoardDefinition
var current_surviving_geometry: VectorGeometry

# The region wiped at the end of the previous turn: already gone, shown as a dead zone.
var applied_erasure_phase: int = -1
# The region that will be wiped at the end of THIS turn. This is the single most
# important hing on screen, so it pulses and is hatched rather than merely tinted.
var upcoming_erasure_phase: int = -1

var is_cleared: bool = false
var active_swipe_nodes: Array[int] = []
var _pulse_t: float = 0.0
var _press_t: float = 0.0  # Dedicated timer for press effects

# Smooth drawing animation
var draw_progress: float = 0.0          # How much of the current swipe has been drawn (0-1)
var draw_progress_target: float = 0.0   # Target progress to animate towards
var draw_speed: float = 10.0            # Segments drawn per second (~0.1s per segment)
var last_swipe_count: int = 0           # Track swipe length to detect changes

# Press animation tracking
var active_presses: Dictionary  # node_id -> animation progress (0-1)
var hover_guidance_id := -1     # For auto-linking visualization


# Preview position for finger-following line
var preview_position: Vector2 = Vector2.ZERO
var is_preview_active: bool = false
var _is_loop_closed: bool = false

# Reward flash for a shape that has just been committed
const COMMIT_FLASH_TIME := 0.45
var _commit_flash_nodes: Array[int] = []
var _commit_flash_t: float = COMMIT_FLASH_TIME

# Hint ghost
const COLOR_HINT := Color(1.00, 0.85, 0.35)
const HINT_SHOW_TIME := 4.5
const HINT_DRAW_TIME := 0.8
var _hint_nodes: Array[int] = []
var _hint_t: float = HINT_SHOW_TIME

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
	# Update press animations
	var keys_to_remove := []
	for node_id in active_presses.keys():
		active_presses[node_id] += delta * PRESS_PULSE_SPEED
		if active_presses[node_id] >= 1.0:
			keys_to_remove.append(node_id)
		else:
			queue_redraw()  # Redraw while animating

	for node_id in keys_to_remove:
		active_presses.erase(node_id)

	# Update dedicated press timer for any continuous effects
	_press_t += delta

	# Commit flash and hint ghost both run themselves out and stop asking for redraws
	if _commit_flash_t < COMMIT_FLASH_TIME:
		_commit_flash_t += delta
		queue_redraw()
	if _hint_t < HINT_SHOW_TIME:
		_hint_t += delta
		queue_redraw()

	# Update smooth drawing animation. Only the newest segment draws itself in; every
	# segment already linked stays solid, so the animation never hides committed geometry.
	var target_swipe_count := active_swipe_nodes.size()
	if target_swipe_count != last_swipe_count:
		var grew := target_swipe_count > last_swipe_count
		last_swipe_count = target_swipe_count
		if target_swipe_count < 2:
			# Nothing to draw yet (or the path was cleared)
			draw_progress = 0.0
			draw_progress_target = 0.0
		elif grew:
			# Start of the newest segment: everything before it is already complete
			draw_progress = float(target_swipe_count - 2) / float(target_swipe_count - 1)
			draw_progress_target = 1.0
		else:
			# Backtracking undoes instantly -- no catch-up lag on the line
			draw_progress = 1.0
			draw_progress_target = 1.0

	# Animate progress towards target. draw_speed is per segment, so scale by segment count.
	var segment_count: int = max(1, active_swipe_nodes.size() - 1)
	var step := delta * draw_speed / float(segment_count)
	if draw_progress < draw_progress_target:
		draw_progress = min(draw_progress_target, draw_progress + step)
		queue_redraw()
	elif draw_progress > draw_progress_target:
		draw_progress = max(draw_progress_target, draw_progress - step)
		queue_redraw()

	# Only animate when there is something to warn about (existing erasure warnings)
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

# A closed shape has no loose end, so the rubber band to the finger is dropped.
func set_loop_closed(closed: bool) -> void:
	_is_loop_closed = closed
	queue_redraw()

func flash_committed_shape(nodes: Array[int]) -> void:
	_commit_flash_nodes = nodes.duplicate()
	_commit_flash_t = 0.0
	queue_redraw()

func show_hint_path(nodes: Array[int]) -> void:
	_hint_nodes = nodes.duplicate()
	_hint_t = 0.0
	queue_redraw()

func clear_hint() -> void:
	_hint_nodes.clear()
	_hint_t = HINT_SHOW_TIME
	queue_redraw()

func is_hint_showing() -> bool:
	return _hint_nodes.size() >= 2 and _hint_t < HINT_SHOW_TIME

# Signal handlers for enhanced input feedback
func _on_node_pressed(node_id: int, touch_pos: Vector2) -> void:
	# Initialize or reset animation progress for this node
	active_presses[node_id] = 0.0
	# Optional: Could add particle effect or sound here
	queue_redraw()

func _on_node_released(node_id: int) -> void:
	# Remove node from active press tracking
	active_presses.erase(node_id)
	queue_redraw()

func _on_hover_updated(node_id: int) -> void:
	# Update hover guidance for auto-linking visualization
	hover_guidance_id = node_id
	queue_redraw()

# Signal handlers for preview functionality
func _on_input_position_updated(position: Vector2, is_dragging: bool) -> void:
	is_preview_active = is_dragging
	if not is_dragging:
		preview_position = Vector2.ZERO
	queue_redraw()

func _on_input_preview_position_updated(position: Vector2) -> void:
	if is_preview_active:
		preview_position = position
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
	_draw_hint_path()
	_draw_active_swipe()
	_draw_commit_flash()
	_draw_cleared_glow()

# The shape the player just committed, echoed as an expanding bright ghost. The turn is
# resolved instantly, so without this the swipe simply vanishes and nothing acknowledges it.
func _draw_commit_flash() -> void:
	if _commit_flash_nodes.size() < 2 or _commit_flash_t >= COMMIT_FLASH_TIME:
		return

	var t := _commit_flash_t / COMMIT_FLASH_TIME
	var alpha := (1.0 - t) * 0.9
	var width := lerpf(7.0, 2.0, t)

	for i in range(_commit_flash_nodes.size() - 1):
		var a: int = _commit_flash_nodes[i]
		var b: int = _commit_flash_nodes[i + 1]
		if a < 0 or b < 0 or a >= node_screen_positions.size() or b >= node_screen_positions.size():
			continue
		draw_line(node_screen_positions[a], node_screen_positions[b],
			Color(1.0, 1.0, 1.0, alpha), width)

	# A ring blooming off each node the shape used
	for n in _commit_flash_nodes:
		var idx: int = n
		if idx < 0 or idx >= node_screen_positions.size():
			continue
		draw_arc(node_screen_positions[idx], lerpf(16.0, 44.0, t), 0, TAU, 24,
			Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, alpha * 0.7), 2.0)

# The hint: the path the intended solution wants this turn, drawn in as a dashed ghost
# that keeps breathing until it times out or the player acts.
func _draw_hint_path() -> void:
	if _hint_nodes.size() < 2 or _hint_t >= HINT_SHOW_TIME:
		return

	# Draws itself in over the first stretch, then holds and fades at the end
	var draw_in := clampf(_hint_t / HINT_DRAW_TIME, 0.0, 1.0)
	var tail := clampf((HINT_SHOW_TIME - _hint_t) / 0.6, 0.0, 1.0)
	var breathe := 0.65 + 0.35 * sin(_hint_t * 4.0)
	var alpha := 0.85 * tail * breathe

	var total_segments := _hint_nodes.size() - 1
	var drawn := draw_in * float(total_segments)

	for i in range(total_segments):
		var a: int = _hint_nodes[i]
		var b: int = _hint_nodes[i + 1]
		if a < 0 or b < 0 or a >= node_screen_positions.size() or b >= node_screen_positions.size():
			continue
		var p1 := node_screen_positions[a]
		var p2 := node_screen_positions[b]
		var seg_progress := clampf(drawn - float(i), 0.0, 1.0)
		if seg_progress <= 0.0:
			break
		draw_line(p1, p1.lerp(p2, seg_progress), Color(COLOR_HINT.r, COLOR_HINT.g, COLOR_HINT.b, alpha), 5.0)

	# Halo the nodes so the player can see which dots to touch, in order
	for i in range(_hint_nodes.size()):
		var idx: int = _hint_nodes[i]
		if idx < 0 or idx >= node_screen_positions.size():
			continue
		if float(i) > drawn:
			break
		draw_arc(node_screen_positions[idx], 24.0, 0, TAU, 24,
			Color(COLOR_HINT.r, COLOR_HINT.g, COLOR_HINT.b, alpha * 0.8), 2.5)

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

		# Base node color and size
		var node_color := COLOR_NODE_ACTIVE if is_selected else COLOR_NODE
		var node_size := 18.0

		# Apply press animation if active
		if active_presses.has(i):
			var progress: float = active_presses[i]
			var pulse := 0.5 + 0.5 * sin(progress * TAU * PRESS_PULSE_SPEED)  # Oscillating pulse
			var scale = lerp(PRESS_SCALE_MIN, PRESS_SCALE_MAX, pulse)
			node_size *= scale

			# Color shift toward white during press
			node_color = Color(
				lerp(node_color.r, 1.0, pulse * PRESS_COLOR_SHIFT),
				lerp(node_color.g, 1.0, pulse * PRESS_COLOR_SHIFT),
				lerp(node_color.b, 0.8, pulse * PRESS_COLOR_SHIFT),
				node_color.a
			)

		draw_circle(pos, node_size, node_color)
		draw_circle(pos, node_size * 0.78, COLOR_BOARD_FILL)  # Inner circle size scales with outer
		if is_selected:
			draw_circle(pos, node_size * 0.44, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.8))

func _draw_surviving_geometry() -> void:
	if current_surviving_geometry == null or current_surviving_geometry.is_empty():
		return

	for seg in current_surviving_geometry.segments:
		var s1 := grid_to_screen(seg.p1)
		var s2 := grid_to_screen(seg.p2)
		draw_line(s1, s2, Color(1.0, 0.85, 0.3, 0.35), 8.0)
		draw_line(s1, s2, COLOR_INK, 4.0)

func _draw_active_swipe() -> void:
	# Draw preview line and guidance line - these can work with just one node
	if is_preview_active and not _is_loop_closed and active_swipe_nodes.size() > 0 and preview_position != Vector2.ZERO:
		var last_confirmed_pos := node_screen_positions[active_swipe_nodes.back()]
		draw_line(last_confirmed_pos, preview_position, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.6), 3.0)

	if hover_guidance_id >= 0 and active_swipe_nodes.size() > 0:
		var last_active_pos := node_screen_positions[active_swipe_nodes.back()]
		var hover_pos := node_screen_positions[hover_guidance_id]

		# Draw dashed line for guidance
		var dash_length := 5.0
		var gap_length := 3.0
		var total_length := dash_length + gap_length
		var distance := last_active_pos.distance_to(hover_pos)
		var dash_count := int(distance / total_length)

		var direction := (hover_pos - last_active_pos).normalized()
		for i in range(dash_count):
			var start := last_active_pos + direction * (i * total_length)
			var end := start + direction * dash_length
			draw_line(start, end, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.4), 2.0)

	# Draw the main active swipe - need at least 2 nodes for this
	if active_swipe_nodes.size() < 2:
		return

	# Calculate how much of the swipe to draw based on progress
	var total_segments := active_swipe_nodes.size() - 1
	var segments_to_draw_float := draw_progress * float(total_segments)
	var full_segments_to_draw := int(segments_to_draw_float)
	var partial_segment_progress := segments_to_draw_float - float(full_segments_to_draw)

	# Draw the main active swipe
	for i in range(full_segments_to_draw):
		var p1 := node_screen_positions[active_swipe_nodes[i]]
		var p2 := node_screen_positions[active_swipe_nodes[i + 1]]
		draw_line(p1, p2, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.9), 4.0)

	# Draw partial segment if there's progress in the current segment
	if full_segments_to_draw < total_segments and partial_segment_progress > 0.0:
		var p1 := node_screen_positions[active_swipe_nodes[full_segments_to_draw]]
		var p2 := node_screen_positions[active_swipe_nodes[full_segments_to_draw + 1]]
		var interim_pos = p1.lerp(p2, partial_segment_progress)
		draw_line(p1, interim_pos, Color(COLOR_NODE_ACTIVE.r, COLOR_NODE_ACTIVE.g, COLOR_NODE_ACTIVE.b, 0.9), 4.0)

func _draw_cleared_glow() -> void:
	if not is_cleared:
		return
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 4.0)
	draw_arc(board_center_screen, board_radius_screen * 1.12, 0, TAU, 72,
		Color(COLOR_CLEARED.r, COLOR_CLEARED.g, COLOR_CLEARED.b, lerp(0.35, 0.9, pulse)), 5.0)
