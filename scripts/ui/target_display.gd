class_name TargetDisplay
extends Control

var target_geometry: VectorGeometry
var board_def: BoardDefinition
var widget_size: Vector2 = Vector2(125, 125)

func _ready() -> void:
	custom_minimum_size = widget_size

func set_target(p_target: VectorGeometry, p_board_def: BoardDefinition) -> void:
	self.target_geometry = p_target
	self.board_def = p_board_def
	queue_redraw()

func _draw() -> void:
	# Background card
	var card_rect := Rect2(Vector2.ZERO, size)
	_draw_card_background(card_rect)

	if target_geometry == null or board_def == null or target_geometry.is_empty():
		return

	var center := size / 2.0
	var scale_factor := (size.x * 0.38) / board_def.radius

	var target_color := Color(0.3, 0.85, 1.0)
	var glow_color := Color(0.3, 0.85, 1.0, 0.3)

	for seg in target_geometry.segments:
		var p1 := center + (seg.p1 - board_def.center) * scale_factor
		var p2 := center + (seg.p2 - board_def.center) * scale_factor

		draw_line(p1, p2, glow_color, 8.0)
		draw_line(p1, p2, target_color, 4.0)

func _draw_card_background(rect: Rect2) -> void:
	var bg_color := Color(0.1, 0.12, 0.18, 0.85)
	var border_color := Color(0.3, 0.4, 0.6, 0.5)

	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
