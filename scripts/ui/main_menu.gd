class_name MainMenu
extends Control

# The first screen. Four ways in:
#
#   CLASSIC  the long ladder: tutorial levels first, then difficulty rises every
#            100 levels, progress saved to disk
#   STORY    the curated run: tasks in a fixed order, each introducing one thing
#   COLOR    colour mode: layers that never overlap, the multi-colour strip
#   TIMER    timed mode: every turn has a clock, running out counts as a skip
#   MIXED    everything at once: colours, timer, erasers, layered goals
#   DEBUG    everything unlocked at once (the original game before the run existed)
#
# The title plate is deliberately empty for now -- the game has no name yet, and a
# placeholder name is worse than no name.

signal mode_chosen(mode: int)
signal settings_applied(language: String, mode: String, color_mode: bool, sound_enabled: bool)

const COLOR_EDGE := Color(0.30, 0.40, 0.60, 0.5)

# Mode values, mirrors GameUI.AppMode
const MODE_CLASSIC := 1
const MODE_STORY := 2
const MODE_COLOR := 3
const MODE_TIMER := 4
const MODE_MIXED := 5
const MODE_DEBUG := 6

@onready var btn_classic: Button = $BtnClassic
@onready var btn_story: Button = $BtnStory
@onready var btn_color: Button = $BtnColor
@onready var btn_timer: Button = $BtnTimer
@onready var btn_mixed: Button = $BtnMixed
@onready var btn_debug: Button = $BtnDebug
@onready var btn_settings: Button = $BtnSettings
@onready var label_progress: Label = $ProgressLabel
@onready var settings_panel: Control = $SettingsPanel

var _t: float = 0.0

func _ready() -> void:
	set_process(true)
	btn_classic.pressed.connect(func(): _choose_mode(MODE_CLASSIC))
	btn_story.pressed.connect(func(): _choose_mode(MODE_STORY))
	btn_color.pressed.connect(func(): _choose_mode(MODE_COLOR))
	btn_timer.pressed.connect(func(): _choose_mode(MODE_TIMER))
	btn_mixed.pressed.connect(func(): _choose_mode(MODE_MIXED))
	btn_debug.pressed.connect(func(): _choose_mode(MODE_DEBUG))
	btn_settings.pressed.connect(func(): _open_settings())
	# Connect signals from the settings panel
	settings_panel.settings_applied.connect(_on_settings_applied)
	settings_panel.settings_cancelled.connect(func(): settings_panel.hide())

func _choose_mode(mode: int) -> void:
	var audio_manager = Engine.get_singleton("AudioManager")
	if audio_manager:
			audio_manager.play_mode_select()
	mode_chosen.emit(mode)

func _open_settings() -> void:
	var audio_manager = Engine.get_singleton("AudioManager")
	if audio_manager:
			audio_manager.play_menu_open()
	settings_panel.visible = true

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

# Where the run has got to, so the buttons are not blind doors.
func set_story_progress(task_index: int) -> void:
	if StoryCampaign.is_finished(task_index):
		label_progress.text = tr("STORY COMPLETE")
		return
	label_progress.text = tr("%s  -  TASK %d / %d") % [
		StoryCampaign.title_for_task(task_index),
		task_index + 1,
		StoryCampaign.total_tasks(),
	]

# Classic ladder progress display.
func set_classic_progress(level: int) -> void:
	label_progress.text = tr("CLASSIC  -  %s") % ClassicCampaign.progress_label(level)

func set_default_progress() -> void:
	label_progress.text = ""

# The board itself, turning slowly behind the buttons: the menu says what the game is
# without needing a word for it.
func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.22)
	var radius: float = minf(size.x, size.y) * 0.16

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
		draw_circle(pos, 3.0, Color(0.40, 0.70, 1.00, 0.55))

	var path: Array[int] = [0, 3, 5, 0]
	for i in range(path.size() - 1):
		draw_line(nodes[path[i]], nodes[path[i + 1]], Color(0.95, 0.75, 0.20, 0.9), 2.5)

func _draw_wedge(center: Vector2, radius: float, axis: Vector2, color: Color) -> void:
	var steps := 12
	var pts := PackedVector2Array()
	pts.append(center)
	var start := axis.angle() - PI * 0.25
	for i in range(steps + 1):
		var a := start + (PI * 0.5) * (float(i) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)

func _on_settings_applied(language: String, mode: String, color_mode: bool, sound_enabled: bool) -> void:
	# Forward the settings signal so other parts of the game can react.
	settings_applied.emit(language, mode, color_mode, sound_enabled)
	# Apply the sound setting immediately
	var audio_manager = Engine.get_singleton("AudioManager")
	if audio_manager:
			audio_manager.set_sound_enabled(sound_enabled)
