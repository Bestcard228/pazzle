class_name MainMenu
extends Control

# The first screen. Two ways in:
#
#   STORY   the run: tasks in a fixed order, each introducing one thing
#   DEBUG   everything unlocked at once, which is the game as it was before the run existed
#
# The title plate is deliberately empty for now -- the game has no name yet, and a
# placeholder name is worse than no name.

signal mode_chosen(story: bool)

const COLOR_EDGE := Color(0.30, 0.40, 0.60, 0.5)

@onready var btn_story: Button = $BtnStory
@onready var btn_debug: Button = $BtnDebug
@onready var label_progress: Label = $ProgressLabel

var _t: float = 0.0

func _ready() -> void:
	set_process(true)
	btn_story.pressed.connect(func(): mode_chosen.emit(true))
	btn_debug.pressed.connect(func(): mode_chosen.emit(false))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

# Where the run has got to, so STORY is not a blind door.
func set_story_progress(task_index: int) -> void:
	if StoryCampaign.is_finished(task_index):
		label_progress.text = "STORY COMPLETE"
		return
	label_progress.text = "%s  -  TASK %d / %d" % [
		StoryCampaign.title_for_task(task_index),
		task_index + 1,
		StoryCampaign.total_tasks(),
	]

# The board itself, turning slowly behind the buttons: the menu says what the game is
# without needing a word for it.
func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.33)
	var radius: float = minf(size.x, size.y) * 0.22

	draw_arc(center, radius, 0, TAU, 64, Color(COLOR_EDGE.r, COLOR_EDGE.g, COLOR_EDGE.b, 0.55), 2.0)

	# The X the wedge eraser cuts along, with one quarter lit and travelling
	var lit := int(_t * 0.5) % EraserSystem.PHASE_COUNT
	var axis := EraserSystem.get_phase_axis(EraserSystem.get_cycle(EraserSystem.CYCLE_CLOCKWISE)[lit])
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	_draw_wedge(center, radius, axis, Color(0.95, 0.30, 0.35, lerpf(0.12, 0.26, pulse)))

	for d in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
		draw_line(center - d * radius, center + d * radius, COLOR_EDGE, 1.5)

	# A shape standing on it, drawn from the same eight nodes the game uses
	var nodes: Array[Vector2] = []
	for i in range(8):
		var angle := -PI / 2.0 + (i * TAU / 8.0)
		nodes.append(center + Vector2(cos(angle), sin(angle)) * radius)

	for pos in nodes:
		draw_circle(pos, 4.0, Color(0.40, 0.70, 1.00, 0.55))

	var path: Array[int] = [0, 3, 5, 0]
	for i in range(path.size() - 1):
		draw_line(nodes[path[i]], nodes[path[i + 1]], Color(0.95, 0.75, 0.20, 0.9), 3.0)

func _draw_wedge(center: Vector2, radius: float, axis: Vector2, color: Color) -> void:
	var steps := 12
	var pts := PackedVector2Array()
	pts.append(center)
	var start := axis.angle() - PI * 0.25
	for i in range(steps + 1):
		var a := start + (PI * 0.5) * (float(i) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
