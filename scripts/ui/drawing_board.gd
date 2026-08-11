class_name DrawingBoard
extends Node2D

var board_def: BoardDefinition
var current_surviving_geometry: VectorGeometry
var current_erasure_phase: int = -1 # -1 means no erasure visible yet
var active_swipe_nodes: Array[int] = []

var node_screen_positions: Array[Vector2] = []
var board_center_screen: Vector2 = Vector2(270, 490)
var board_radius_screen: float = 170.0

func _ready() -> void:
	if board_def == null:
		board_def = BoardDefinition.new(8)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	recompute_screen_positions()

func _on_viewport_size_changed() -> void:
	recompute_screen_positions()
	queue_redraw()

func set_board_definition(p_board_def: BoardDefinition) -> void:
	self.board_def = p_board_def
	recompute_screen_positions()
	queue_redraw()

func set_surviving_geometry(geom: VectorGeometry, erasure_phase: int) -> void:
	self.current_surviving_geometry = geom
	self.current_erasure_phase = erasure_phase
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
	var offset := grid_pos - board_def.center
	var scale_factor := board_radius_screen / board_def.radius
	return board_center_screen + offset * scale_factor

func _draw() -> void:
	if board_def == null:
		return

	_draw_erasure_overlay()
	_draw_node_ring()
	_draw_surviving_geometry()
	_draw_active_swipe()

func _draw_erasure_overlay() -> void:
	if current_erasure_phase < 0:
		return

	var rect_size := board_radius_screen * 2.4
	var phase := current_erasure_phase % 4

	var overlay_color := Color(0.9, 0.2, 0.3, 0.18)
	var border_color := Color(0.95, 0.3, 0.4, 0.6)

	var overlay_rect: Rect2
	match phase:
		EraserSystem.ErasureRegion.TOP:
			overlay_rect = Rect2(board_center_screen.x - rect_size / 2, board_center_screen.y - rect_size / 2, rect_size, rect_size / 2)
		EraserSystem.ErasureRegion.RIGHT:
			overlay_rect = Rect2(board_center_screen.x, board_center_screen.y - rect_size / 2, rect_size / 2, rect_size)
		EraserSystem.ErasureRegion.BOTTOM:
			overlay_rect = Rect2(board_center_screen.x - rect_size / 2, board_center_screen.y, rect_size, rect_size / 2)
		EraserSystem.ErasureRegion.LEFT:
			overlay_rect = Rect2(board_center_screen.x - rect_size / 2, board_center_screen.y - rect_size / 2, rect_size / 2, rect_size)

	draw_rect(overlay_rect, overlay_color)

	match phase:
		EraserSystem.ErasureRegion.TOP, EraserSystem.ErasureRegion.BOTTOM:
			draw_line(Vector2(board_center_screen.x - rect_size / 2, board_center_screen.y), Vector2(board_center_screen.x + rect_size / 2, board_center_screen.y), border_color, 3.0)
		EraserSystem.ErasureRegion.RIGHT, EraserSystem.ErasureRegion.LEFT:
			draw_line(Vector2(board_center_screen.x, board_center_screen.y - rect_size / 2), Vector2(board_center_screen.x, board_center_screen.y + rect_size / 2), border_color, 3.0)

func _draw_node_ring() -> void:
	draw_arc(board_center_screen, board_radius_screen, 0, TAU, 64, Color(0.3, 0.35, 0.45, 0.4), 2.0)

	for i in range(node_screen_positions.size()):
		var pos := node_screen_positions[i]
		var is_selected := active_swipe_nodes.has(i)

		var node_color := Color(0.4, 0.7, 1.0) if not is_selected else Color(0.2, 0.95, 0.5)
		var bg_color := Color(0.12, 0.14, 0.22)

		draw_circle(pos, 18.0, node_color)
		draw_circle(pos, 14.0, bg_color)
		if is_selected:
			draw_circle(pos, 8.0, Color(0.2, 0.95, 0.5, 0.8))

func _draw_surviving_geometry() -> void:
	if current_surviving_geometry == null or current_surviving_geometry.is_empty():
		return

	var line_color := Color(0.95, 0.75, 0.2, 0.95)
	var glow_color := Color(1.0, 0.85, 0.3, 0.35)

	for seg in current_surviving_geometry.segments:
		var s1 := grid_to_screen(seg.p1)
		var s2 := grid_to_screen(seg.p2)

		draw_line(s1, s2, glow_color, 8.0)
		draw_line(s1, s2, line_color, 4.0)

func _draw_active_swipe() -> void:
	if active_swipe_nodes.size() < 2:
		return

	var active_color := Color(0.2, 0.95, 0.5, 0.9)
	for i in range(active_swipe_nodes.size() - 1):
		var p1 := node_screen_positions[active_swipe_nodes[i]]
		var p2 := node_screen_positions[active_swipe_nodes[i + 1]]
		draw_line(p1, p2, active_color, 4.0)
