class_name InputHandler
extends Node2D

signal shape_drawn(node_ids: Array[int])
signal active_path_changed(node_ids: Array[int])
signal node_pressed(node_id: int, touch_pos: Vector2)
signal node_released(node_id: int)
signal hover_updated(hover_node_id: int)
signal position_updated(position: Vector2, is_dragging: bool)
signal preview_position_updated(position: Vector2)
signal loop_closed_changed(closed: bool)

var board_def: BoardDefinition
var node_screen_positions: Array[Vector2] = []
var active_node_ids: Array[int] = []
var is_dragging: bool = false
var is_enabled: bool = true
var current_touch_pos: Vector2 = Vector2.ZERO

# How near a dot counts. DETECTION_RADIUS is the forgiving radius used to decide which dot
# the finger is nearest; DOT_RADIUS is the tighter one that actually links a dot, and the
# same radius the finger has to come back inside to unlink the previous one.
const DETECTION_RADIUS := 70.0
const DOT_RADIUS := 32.0

# The dot the finger has come back onto, while it is being backtracked away from.
var backtrack_target_id := -1
var backtrack_progress := 0.0

var hovered_node_id := -1          # Currently hovered node for guidance
var last_valid_node_id := -1       # Last node that confirmed activation
var is_backtracking_enabled := true
var loop_closed: bool = false      # Track if the current shape has been closed into a loop

# _handle_path_update return values
const PATH_NO_CHANGE := 0
const PATH_ADDED := 1

func setup(p_board_def: BoardDefinition, p_screen_positions: Array[Vector2]) -> void:
	self.board_def = p_board_def
	self.node_screen_positions = p_screen_positions.duplicate()

# ERASE mode gives the board a different job, so the swipe input stands down entirely
# rather than competing for the same taps.
func set_enabled(p_enabled: bool) -> void:
	is_enabled = p_enabled
	if not p_enabled and is_dragging:
		_finish_drag()

func _input(event: InputEvent) -> void:
	if not is_enabled or node_screen_positions.is_empty():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.position)
			else:
				if is_dragging:
					_finish_drag()

	elif event is InputEventMouseMotion and is_dragging:
		_process_drag(event.position)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			if is_dragging:
				_finish_drag()

	elif event is InputEventScreenDrag and is_dragging:
		_process_drag(event.position)

func _begin_drag(pos: Vector2) -> void:
	is_dragging = true
	current_touch_pos = pos
	# The rubber band is live from the very first dot, not only after the first move.
	position_updated.emit(pos, true)
	preview_position_updated.emit(pos)
	_check_node_hit(pos)
	# No backtracking update on press: we have only just put the finger down.

func _process_drag(pos: Vector2) -> void:
	current_touch_pos = pos
	_update_backtracking(pos)
	position_updated.emit(pos, true)
	preview_position_updated.emit(pos)
	_update_hover(pos)
	_check_for_new_dot(pos)

func _check_node_hit(pos: Vector2) -> void:
	# Find the best hit node within detection radius
	var hit_result := _find_best_hit_node(pos)
	var best_node_id: int = hit_result[0]

	if best_node_id == -1:
		# No node close enough, update hover guidance to none
		if hovered_node_id != -1:
			hovered_node_id = -1
			hover_updated.emit(-1)
		return

	# Update hover guidance for auto-linking
	if hovered_node_id != best_node_id:
		hovered_node_id = best_node_id
		hover_updated.emit(best_node_id)

	# Handle path updates with normal addition (no backtracking here - handled in _update_backtracking)
	var path_changed := _handle_path_update(best_node_id, pos)

	if path_changed == PATH_ADDED:
		node_pressed.emit(best_node_id, pos)

	queue_redraw()

# Keeps the dashed guidance line following the finger for the whole drag, not just the press.
func _update_hover(pos: Vector2) -> void:
	var nearest := -1
	var nearest_distance := 1e20
	for i in range(node_screen_positions.size()):
		var d := pos.distance_to(node_screen_positions[i])
		if d <= DETECTION_RADIUS and d < nearest_distance:
			nearest = i
			nearest_distance = d

	if nearest != hovered_node_id:
		hovered_node_id = nearest
		hover_updated.emit(nearest)

func _find_best_hit_node(pos: Vector2) -> Array:
	"""Find the best node to hit within detection radius.
	Returns [best_node_id, second_best_id, distance_to_best]"""
	var best_node_id: int = -1
	var second_best_id: int = -1
	var best_distance: float = 1e20
	var second_best_distance: float = 1e20

	for i in range(node_screen_positions.size()):
		var n_pos := node_screen_positions[i]
		var distance_to_node := pos.distance_to(n_pos)

		if distance_to_node <= DETECTION_RADIUS:
			# Prioritize nodes not already in path (except for potential loop completion)
			var already_in_path := active_node_ids.has(i)

			# The first node only becomes a candidate again once the path is long enough
			# to actually close into a loop -- otherwise a two-node path would re-add it
			# as a plain duplicate.
			if not already_in_path or (active_node_ids.size() >= 3 and i == active_node_ids.front()):
				# This is a good candidate - not in path or could complete loop
				if distance_to_node < best_distance:
					second_best_id = best_node_id
					second_best_distance = best_distance
					best_node_id = i
					best_distance = distance_to_node
				elif distance_to_node < second_best_distance:
					second_best_id = i
					second_best_distance = distance_to_node

	return [best_node_id, second_best_id, best_distance]

func _handle_path_update(node_id: int, pos: Vector2) -> int:
	"""Handle adding nodes to path (no backtracking here).
	Returns PATH_NO_CHANGE or PATH_ADDED."""
	if active_node_ids.is_empty():
		# First node in path
		active_node_ids.append(node_id)
		active_path_changed.emit(active_node_ids.duplicate())
		last_valid_node_id = node_id
		return PATH_ADDED

	# Normal node addition: if not already in path
	if not active_node_ids.has(node_id):
		active_node_ids.append(node_id)
		active_path_changed.emit(active_node_ids.duplicate())
		last_valid_node_id = node_id
		return PATH_ADDED

	return PATH_NO_CHANGE

func _update_backtracking(pos: Vector2) -> void:
	"""Update backtracking hysteresis logic."""
	if not is_backtracking_enabled or active_node_ids.size() < 2:
		backtrack_target_id = -1
		backtrack_progress = 0.0
		return

	var current_id: int = active_node_ids.back()
	var previous_id: int = active_node_ids[active_node_ids.size() - 2]

	var current_pos := node_screen_positions[current_id]
	var previous_pos := node_screen_positions[previous_id]

	# Distance from cursor to the current selected dot.
	var distance_from_current := pos.distance_to(current_pos)

	# Distance from cursor to previous dot.
	var distance_to_previous := pos.distance_to(previous_pos)

	# Backtracking means exactly one thing: the finger has come back onto the dot before
	# the last one, using the same radius that links a dot in the first place. Anything
	# looser -- "closer to the previous dot than to the current one" -- also fires while
	# the finger is on its way to a third dot that happens to lie on that side, which
	# makes whole families of triangles impossible to draw.
	if distance_to_previous > DOT_RADIUS or distance_to_previous >= distance_from_current:
		backtrack_target_id = -1
		backtrack_progress = 0.0
		return

	backtrack_target_id = previous_id
	backtrack_progress = distance_to_previous

	var removed_id: int = active_node_ids.pop_back()
	active_path_changed.emit(active_node_ids.duplicate())
	node_released.emit(removed_id)
	last_valid_node_id = active_node_ids.back() if not active_node_ids.is_empty() else -1

	# The node just popped off a closed shape is the repeated first node, so removing
	# it is exactly what reopens the loop.
	if loop_closed:
		loop_closed = false
		loop_closed_changed.emit(false)

	backtrack_target_id = -1
	backtrack_progress = 0.0

func _check_for_new_dot(pos: Vector2) -> void:
	"""Check for a new dot to add, if not backtracking and shape not closed."""
	# If we are currently backtracking, don't add a new dot.
	if backtrack_target_id != -1:
		return

	# If the shape is closed, don't add a new dot.
	if loop_closed:
		return

	# Find the nearest dot within DOT_RADIUS.
	var hit_result := _find_best_hit_node(pos)
	var best_node_id: int = hit_result[0]
	var distance: float = hit_result[2]

	if best_node_id == -1 or distance > DOT_RADIUS:
		return

	# A drag that began away from the ring still starts its path on the first dot it meets.
	if active_node_ids.is_empty():
		active_node_ids.append(best_node_id)
		active_path_changed.emit(active_node_ids.duplicate())
		last_valid_node_id = best_node_id
		node_pressed.emit(best_node_id, pos)
		return

	# Closing the loop: the first node is repeated at the end of the path, which is the
	# form ShapeDatabase identifies closed shapes from.
	if active_node_ids.size() >= 3 and best_node_id == active_node_ids.front():
		active_node_ids.append(best_node_id)
		loop_closed = true
		active_path_changed.emit(active_node_ids.duplicate())
		loop_closed_changed.emit(true)
		node_pressed.emit(best_node_id, pos)
		return

	# Check if we are trying to add the last dot again (should not happen, but guard).
	if best_node_id == active_node_ids.back():
		return

	# Otherwise, add the new dot.
	active_node_ids.append(best_node_id)
	active_path_changed.emit(active_node_ids.duplicate())
	last_valid_node_id = best_node_id
	node_pressed.emit(best_node_id, pos)

func _finish_drag() -> void:
	is_dragging = false
	backtrack_target_id = -1
	backtrack_progress = 0.0
	loop_closed = false
	loop_closed_changed.emit(false)
	if active_node_ids.size() >= 2:
		shape_drawn.emit(active_node_ids.duplicate())
	active_node_ids.clear()
	active_path_changed.emit(active_node_ids.duplicate())
	hovered_node_id = -1
	hover_updated.emit(-1)
	position_updated.emit(current_touch_pos, false)
	queue_redraw()
