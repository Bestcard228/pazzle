class_name TargetDisplay
extends Control

# Shows the goal on a faint copy of the play field -- same ring, same eight dots -- so the
# target can be read positionally ("that edge runs from the top node to the lower right")
# instead of as a floating scribble.

const COLOR_TARGET := Color(0.3, 0.85, 1.0)
const COLOR_MATCHED := Color(0.2, 0.95, 0.5)
const COLOR_FIELD := Color(0.45, 0.52, 0.66, 0.28)
const COLOR_DOT := Color(0.40, 0.70, 1.00, 0.55)
const FADE_OUT_TIME := 0.8  # seconds to fade out
const FADE_IN_TIME := 0.35  # seconds for a fresh goal to arrive

# Lets the owner chain the next step onto the end of the celebration instead of guessing
# at a delay.
signal fade_out_finished

var target_geometry: VectorGeometry
var board_def: BoardDefinition
var is_matched: bool = false
var fade_timer: float = 0.0
var is_fading_out: bool = false
var fade_in_timer: float = FADE_IN_TIME
var widget_size: Vector2 = Vector2(125, 125)

func _ready() -> void:
	custom_minimum_size = widget_size

func _process(delta: float) -> void:
	if is_fading_out:
		fade_timer += delta
		if fade_timer >= FADE_OUT_TIME:
			is_fading_out = false
			fade_timer = FADE_OUT_TIME
			fade_out_finished.emit()
		queue_redraw()
	elif fade_in_timer < FADE_IN_TIME:
		fade_in_timer = min(FADE_IN_TIME, fade_in_timer + delta)
		queue_redraw()

func set_target(p_target: VectorGeometry, p_board_def: BoardDefinition) -> void:
	self.target_geometry = p_target
	self.board_def = p_board_def
	self.is_matched = false
	# A new goal arrives rather than blinking into place
	self.is_fading_out = false
	self.fade_timer = 0.0
	self.fade_in_timer = 0.0
	queue_redraw()

# Turns the goal card green once the board matches it, so the match is visible where the
# player is already looking rather than only in a status line.
func set_matched(p_matched: bool) -> void:
	self.is_matched = p_matched
	queue_redraw()

func start_fade_out() -> void:
	# Trigger fade-out to animate transition (can be used for matched or unmatched states)
	is_fading_out = true
	fade_timer = 0.0

func _draw() -> void:
	_draw_card_background(Rect2(Vector2.ZERO, size))

	if board_def == null:
		return

	var center := size / 2.0
	var scale_factor := (size.x * 0.38) / board_def.radius

	# Calculate fade alpha if fading out
	var fade_alpha := 1.0
	if is_fading_out:
		fade_alpha = 1.0 - (fade_timer / FADE_OUT_TIME)
		fade_alpha = max(0.0, fade_alpha)
	elif fade_in_timer < FADE_IN_TIME:
		# Ease-out so the goal settles in rather than ramping linearly
		var t := fade_in_timer / FADE_IN_TIME
		fade_alpha = 1.0 - pow(1.0 - t, 3.0)

	_draw_field(center, scale_factor)
	_draw_target(center, scale_factor, fade_alpha)

# The board ring and its input nodes, kept faint so the goal still reads as the subject.
func _draw_field(center: Vector2, scale_factor: float) -> void:
	var ring_radius := board_def.radius * scale_factor
	draw_arc(center, ring_radius, 0, TAU, 40, COLOR_FIELD, 1.5)

	for i in range(board_def.node_count):
		var pos := center + (board_def.get_node_position(i) - board_def.center) * scale_factor
		draw_circle(pos, 3.0, COLOR_DOT)

func _draw_target(center: Vector2, scale_factor: float, fade_alpha: float = 1.0) -> void:
	if target_geometry == null or target_geometry.is_empty():
		return

	var ink := COLOR_MATCHED if is_matched else COLOR_TARGET
	var final_alpha = ink.a * fade_alpha
	for seg in target_geometry.segments:
		var p1 := center + (seg.p1 - board_def.center) * scale_factor
		var p2 := center + (seg.p2 - board_def.center) * scale_factor

		draw_line(p1, p2, Color(ink.r, ink.g, ink.b, 0.3 * fade_alpha), 8.0)
		draw_line(p1, p2, Color(ink.r, ink.g, ink.b, final_alpha), 4.0)

func _draw_card_background(rect: Rect2) -> void:
	var border_color := COLOR_MATCHED if is_matched else Color(0.3, 0.4, 0.6, 0.45)
	var border_width := 3.0 if is_matched else 2.0

	# Barely-there plate: the field and goal carry the card, not a filled panel
	draw_rect(rect, Color(0.1, 0.12, 0.18, 0.25))
	draw_rect(rect, border_color, false, border_width)
