class_name StoryCampaign
extends RefCounted

# The story: one ordered run of tasks that introduces the game a piece at a time.
#
# Each chapter changes exactly one thing about the previous one, and holds it for a few
# tasks so the change has time to be noticed:
#
#   the lesson            what a turn is
#   clockwise             the erasure walk, always the same one
#   counter-clockwise     the same puzzle read the other way round
#   easy+                 the opening quarter starts moving
#   across / zigzag       the walks that are not rotations
#   choose the erasures   the halves swap: shapes given, schedule solved
#   colours               two sheets, each eaten by its own walk
#   medium                goals that chain
#
# Two rules hold across the whole run:
#
#   * every task after the lesson is on a 12 second clock
#   * a task introduces one mode at a time -- never erase input and colours together
#
# Anything not pinned by a chapter is left to the generator, so a chapter that does not
# name its walks gets the shuffled bag and is fine with any of them.

const STORY_TURN_SECONDS := 12.0
const SHUFFLED := PuzzleGenerator.SHUFFLED_ERASURE_CYCLE

# Chapters in order. `cycles` empty means "any walk"; `tutorial` marks the lesson, which
# is the one task with no clock.
const CHAPTERS: Array = [
	{
		"title": "HOW IT WORKS",
		"tasks": 1,
		"tutorial": true,
		"difficulty": PuzzleGenerator.Difficulty.EASY,
		"cycles": [EraserSystem.CYCLE_CLOCKWISE],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "CLOCKWISE",
		"tasks": 2,
		"difficulty": PuzzleGenerator.Difficulty.EASY,
		"cycles": [EraserSystem.CYCLE_CLOCKWISE],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "THE OTHER WAY",
		"tasks": 2,
		"difficulty": PuzzleGenerator.Difficulty.EASY,
		"cycles": [EraserSystem.CYCLE_COUNTER_CLOCKWISE],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "MOVING OPENINGS",
		"tasks": 3,
		"difficulty": PuzzleGenerator.Difficulty.EASY_PLUS,
		"cycles": [EraserSystem.CYCLE_CLOCKWISE, EraserSystem.CYCLE_COUNTER_CLOCKWISE],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "ACROSS THE FIELD",
		"tasks": 3,
		"difficulty": PuzzleGenerator.Difficulty.EASY_PLUS,
		"cycles": [2, 3],  # ACROSS-LEFT, ACROSS-RIGHT
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "ZIGZAG",
		"tasks": 4,
		"difficulty": PuzzleGenerator.Difficulty.EASY_PLUS_PLUS,
		"cycles": [4, 5],  # ZIGZAG-RIGHT, ZIGZAG-LEFT
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "ANY ORDER",
		"tasks": 4,
		"difficulty": PuzzleGenerator.Difficulty.EASY_PLUS_PLUS,
		"cycles": [],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
	{
		"title": "YOU HOLD THE ERASER",
		"tasks": 4,
		"difficulty": PuzzleGenerator.Difficulty.EASY,
		"cycles": [],
		"input_mode": PuzzleData.InputMode.CHOOSE_ERASURES,
		"layers": 1,
	},
	{
		"title": "TWO COLOURS",
		"tasks": 4,
		"difficulty": PuzzleGenerator.Difficulty.EASY,
		"cycles": [],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 2,
	},
	{
		"title": "ONE GOAL AFTER ANOTHER",
		"tasks": 5,
		"difficulty": PuzzleGenerator.Difficulty.MEDIUM,
		"cycles": [],
		"input_mode": PuzzleData.InputMode.DRAW_SHAPES,
		"layers": 1,
	},
]

static func total_tasks() -> int:
	var total := 0
	for chapter in CHAPTERS:
		total += int(chapter["tasks"])
	return total

# Which chapter a run-wide task index falls in, and how far into it.
static func chapter_index_for_task(task_index: int) -> int:
	var remaining := maxi(0, task_index)
	for i in range(CHAPTERS.size()):
		var tasks := int(CHAPTERS[i]["tasks"])
		if remaining < tasks:
			return i
		remaining -= tasks
	return CHAPTERS.size() - 1

static func task_within_chapter(task_index: int) -> int:
	var remaining := maxi(0, task_index)
	for chapter in CHAPTERS:
		var tasks := int(chapter["tasks"])
		if remaining < tasks:
			return remaining
		remaining -= tasks
	return 0

static func get_chapter(task_index: int) -> Dictionary:
	return CHAPTERS[chapter_index_for_task(task_index)]

static func is_finished(task_index: int) -> bool:
	return task_index >= total_tasks()

static func is_tutorial_task(task_index: int) -> bool:
	var chapter := get_chapter(task_index)
	return chapter.get("tutorial", false)

# The walk this task runs on. A chapter that names several rotates through them, so a set
# of tasks shows each of its new orders rather than rolling the same one repeatedly.
static func cycle_for_task(task_index: int) -> int:
	var chapter := get_chapter(task_index)
	var cycles: Array = chapter["cycles"]
	if cycles.is_empty():
		return SHUFFLED
	return int(cycles[task_within_chapter(task_index) % cycles.size()])

static func difficulty_for_task(task_index: int) -> int:
	return int(get_chapter(task_index)["difficulty"])

static func input_mode_for_task(task_index: int) -> int:
	return int(get_chapter(task_index)["input_mode"])

static func layers_for_task(task_index: int) -> int:
	# One mode at a time: erase input never arrives with colours on top of it.
	if input_mode_for_task(task_index) == PuzzleData.InputMode.CHOOSE_ERASURES:
		return LayerSystem.SINGLE_LAYER
	return int(get_chapter(task_index)["layers"])

static func clock_for_task(task_index: int) -> float:
	return 0.0 if is_tutorial_task(task_index) else STORY_TURN_SECONDS

static func title_for_task(task_index: int) -> String:
	return str(get_chapter(task_index)["title"])

# "CLOCKWISE  -  2 / 2", which is as much as the run needs to say about where it is.
static func progress_label(task_index: int) -> String:
	if is_finished(task_index):
		return "STORY COMPLETE"
	var chapter := get_chapter(task_index)
	return "%s  -  %d / %d" % [
		chapter["title"],
		task_within_chapter(task_index) + 1,
		int(chapter["tasks"]),
	]
