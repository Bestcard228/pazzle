class_name TargetDisplay
extends Control

const COLOR_TARGET := Color(0.3, 0.85, 1.0)
const COLOR_MATCHED := Color(0.2, 0.95, 0.5)

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

	if target_geometry == null or board_def == null or target_geometry.is_empty():
		return

	var center := size / 2.0
	var scale_factor := (size.x * 0.38) / board_def.radius
	var ink := COLOR_MATCHED if is_matched else COLOR_TARGET

	for seg in target_geometry.segments:
		var p1 := center + (seg.p1 - board_def.center) * scale_factor
		var p2 := center + (seg.p2 - board_def.center) * scale_factor

		draw_line(p1, p2, Color(ink.r, ink.g, ink.b, 0.3), 8.0)
		draw_line(p1, p2, ink, 4.0)

func _draw_card_background(rect: Rect2) -> void:
	var border_color := COLOR_MATCHED if is_matched else Color(0.3, 0.4, 0.6, 0.5)
	var border_width := 3.0 if is_matched else 2.0

	draw_rect(rect, Color(0.1, 0.12, 0.18, 0.85))
	draw_rect(rect, border_color, false, border_width)
