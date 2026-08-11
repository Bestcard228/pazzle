class_name TargetDisplay
extends Control

# Shows the goal on a faint copy of the play field -- same ring, same eight dots -- so the
# target can be read positionally ("that edge runs from the top node to the lower right")
# instead of as a floating scribble.

const COLOR_TARGET := Color(0.3, 0.85, 1.0)
const COLOR_MATCHED := Color(0.2, 0.95, 0.5)
const COLOR_FIELD := Color(0.45, 0.52, 0.66, 0.28)
const COLOR_DOT := Color(0.40, 0.70, 1.00, 0.55)

var target_geometry: VectorGeometry
var board_def: BoardDefinition
var is_matched: bool = false
var widget_size: Vector2 = Vector2(125, 125)

func _ready() -> void:
	custom_minimum_size = widget_size

func set_target(p_target: VectorGeometry, p_board_def: BoardDefinition) -> void:
	self.target_geometry = p_target
	self.board_def = p_board_def
	self.is_matched = false
	queue_redraw()

# Turns the goal card green once the board matches it, so the match is visible where the
# player is already looking rather than only in a status line.
func set_matched(p_matched: bool) -> void:
	self.is_matched = p_matched
	queue_redraw()

func _draw() -> void:
	_draw_card_background(Rect2(Vector2.ZERO, size))

	if board_def == null:
		return

	var center := size / 2.0
	var scale_factor := (size.x * 0.38) / board_def.radius

	_draw_field(center, scale_factor)
	_draw_target(center, scale_factor)

# The board ring and its input nodes, kept faint so the goal still reads as the subject.
func _draw_field(center: Vector2, scale_factor: float) -> void:
	var ring_radius := board_def.radius * scale_factor
	draw_arc(center, ring_radius, 0, TAU, 40, COLOR_FIELD, 1.5)

	for i in range(board_def.node_count):
		var pos := center + (board_def.get_node_position(i) - board_def.center) * scale_factor
		draw_circle(pos, 3.0, COLOR_DOT)

func _draw_target(center: Vector2, scale_factor: float) -> void:
	if target_geometry == null or target_geometry.is_empty():
		return

	var ink := COLOR_MATCHED if is_matched else COLOR_TARGET
	for seg in target_geometry.segments:
		var p1 := center + (seg.p1 - board_def.center) * scale_factor
		var p2 := center + (seg.p2 - board_def.center) * scale_factor

		draw_line(p1, p2, Color(ink.r, ink.g, ink.b, 0.3), 8.0)
		draw_line(p1, p2, ink, 4.0)

func _draw_card_background(rect: Rect2) -> void:
	var border_color := COLOR_MATCHED if is_matched else Color(0.3, 0.4, 0.6, 0.45)
	var border_width := 3.0 if is_matched else 2.0

	# Barely-there plate: the field and goal carry the card, not a filled panel
	draw_rect(rect, Color(0.1, 0.12, 0.18, 0.25))
	draw_rect(rect, border_color, false, border_width)
