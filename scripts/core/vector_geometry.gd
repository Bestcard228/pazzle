class_name VectorGeometry
extends RefCounted

const EPSILON := 0.01

class LineSegment2D extends RefCounted:
	var p1: Vector2
	var p2: Vector2

	func _init(point_a: Vector2 = Vector2.ZERO, point_b: Vector2 = Vector2.ZERO):
		self.p1 = point_a
		self.p2 = point_b

	func length() -> float:
		return p1.distance_to(p2)

	func is_degenerate(tol: float = EPSILON) -> bool:
		return length() <= tol

	# Returns a line segment where p1 is lexicographically <= p2
	func get_normalized() -> LineSegment2D:
		if p1.x < p2.x - EPSILON or (abs(p1.x - p2.x) <= EPSILON and p1.y <= p2.y):
			return LineSegment2D.new(p1, p2)
		else:
			return LineSegment2D.new(p2, p1)

	func equals_segment(other: LineSegment2D, tol: float = EPSILON) -> bool:
		var norm_a := get_normalized()
		var norm_b := other.get_normalized()
		return norm_a.p1.distance_to(norm_b.p1) <= tol and norm_a.p2.distance_to(norm_b.p2) <= tol

	func duplicate_segment() -> LineSegment2D:
		return LineSegment2D.new(p1, p2)

	func _to_string() -> String:
		return "Line(%.2f,%.2f -> %.2f,%.2f)" % [p1.x, p1.y, p2.x, p2.y]

var segments: Array[LineSegment2D] = []

func _init(initial_segments: Array = []):
	for s in initial_segments:
		if s is LineSegment2D:
			add_segment(s)

func add_segment(seg: LineSegment2D) -> void:
	if not seg.is_degenerate():
		segments.append(seg.duplicate_segment())

func add_line(a: Vector2, b: Vector2) -> void:
	add_segment(LineSegment2D.new(a, b))

func merge(other: VectorGeometry) -> void:
	if other == null:
		return
	for seg in other.segments:
		add_segment(seg)

func is_empty() -> bool:
	return segments.is_empty()

func clear() -> void:
	segments.clear()

func duplicate_geometry() -> VectorGeometry:
	var copy := VectorGeometry.new()
	for seg in segments:
		copy.add_segment(seg)
	return copy

# Returns a canonical representation (normalized directions, sorted, duplicates removed)
func canonicalize(tol: float = EPSILON) -> VectorGeometry:
	var norm_list: Array[LineSegment2D] = []
	for seg in segments:
		if seg.is_degenerate(tol):
			continue
		var n := seg.get_normalized()
		# Avoid duplicate segments
		var exists := false
		for existing in norm_list:
			if existing.equals_segment(n, tol):
				exists = true
				break
		if not exists:
			norm_list.append(n)

	# Sort deterministically
	norm_list.sort_custom(func(a: LineSegment2D, b: LineSegment2D) -> bool:
		if abs(a.p1.x - b.p1.x) > tol:
			return a.p1.x < b.p1.x
		if abs(a.p1.y - b.p1.y) > tol:
			return a.p1.y < b.p1.y
		if abs(a.p2.x - b.p2.x) > tol:
			return a.p2.x < b.p2.x
		return a.p2.y < b.p2.y
	)

	var canonical := VectorGeometry.new()
	canonical.segments = norm_list
	return canonical

# Compare geometric equality against another VectorGeometry
func is_equivalent_to(other: VectorGeometry, tol: float = EPSILON) -> bool:
	if other == null:
		return false
	var c_this := canonicalize(tol)
	var c_other := other.canonicalize(tol)

	if c_this.segments.size() != c_other.segments.size():
		return false

	for i in range(c_this.segments.size()):
		if not c_this.segments[i].equals_segment(c_other.segments[i], tol):
			return false

	return true
