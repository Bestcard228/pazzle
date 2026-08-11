class_name InputHandler
extends Node2D

signal shape_drawn(node_ids: Array[int])
signal active_path_changed(node_ids: Array[int])

var board_def: BoardDefinition
var node_screen_positions: Array[Vector2] = []
var active_node_ids: Array[int] = []
var is_dragging: bool = false
var current_touch_pos: Vector2 = Vector2.ZERO
var node_hitbox_radius: float = 50.0

func setup(p_board_def: BoardDefinition, p_screen_positions: Array[Vector2]) -> void:
	self.board_def = p_board_def
	self.node_screen_positions = p_screen_positions.duplicate()

func _input(event: InputEvent) -> void:
	if node_screen_positions.is_empty():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				current_touch_pos = event.position
				_check_node_hit(event.position)
			else:
				if is_dragging:
					_finish_drag()

	elif event is InputEventMouseMotion and is_dragging:
		current_touch_pos = event.position
		_check_node_hit(event.position)

	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			current_touch_pos = event.position
			_check_node_hit(event.position)
		else:
			if is_dragging:
				_finish_drag()

	elif event is InputEventScreenDrag and is_dragging:
		current_touch_pos = event.position
		_check_node_hit(event.position)

func _check_node_hit(pos: Vector2) -> void:
	for i in range(node_screen_positions.size()):
		var n_pos := node_screen_positions[i]
		if pos.distance_to(n_pos) <= node_hitbox_radius:
			if active_node_ids.is_empty():
				active_node_ids.append(i)
				active_path_changed.emit(active_node_ids.duplicate())
			elif active_node_ids.back() != i:
				# Check closing loop
				if i == active_node_ids.front() and active_node_ids.size() >= 3:
					active_node_ids.append(i)
					active_path_changed.emit(active_node_ids.duplicate())
					_finish_drag()
					return
				elif not active_node_ids.has(i):
					active_node_ids.append(i)
					active_path_changed.emit(active_node_ids.duplicate())

	queue_redraw()

func _finish_drag() -> void:
	is_dragging = false
	if active_node_ids.size() >= 2:
		shape_drawn.emit(active_node_ids.duplicate())
	active_node_ids.clear()
	active_path_changed.emit(active_node_ids.duplicate())
	queue_redraw()
