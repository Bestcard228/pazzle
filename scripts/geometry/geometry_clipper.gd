class_name GeometryClipper
extends RefCounted

# Clips out (erases) any portion of `geometry` that falls inside `erased_rect`.
# Returns a new VectorGeometry containing the surviving line segments outside the erased rect.
static func clip_geometry_out(geometry: VectorGeometry, erased_rect: Rect2, tol: float = 0.001) -> VectorGeometry:
	var result := VectorGeometry.new()
	if geometry == null or geometry.is_empty():
		return result

	for seg in geometry.segments:
		var surviving_segments := clip_segment_out_rect(seg, erased_rect, tol)
		for s in surviving_segments:
			result.add_segment(s)

	return result.canonicalize()

# Clips a single line segment against an erased rectangle.
# Keeps sub-segments that lie OUTSIDE `erased_rect`.
static func clip_segment_out_rect(seg: VectorGeometry.LineSegment2D, rect: Rect2, tol: float = 0.001) -> Array[VectorGeometry.LineSegment2D]:
	var result: Array[VectorGeometry.LineSegment2D] = []
	if seg.is_degenerate():
		return result

	var p1 := seg.p1
	var p2 := seg.p2
	var dir := p2 - p1

	# Gather parametric values t in [0, 1] for intersection points
	var t_values: Array[float] = [0.0, 1.0]

	# Check boundary lines of rect
	var left := rect.position.x
	var right := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y

	if abs(dir.x) > tol:
		var t_left := (left - p1.x) / dir.x
		if t_left > tol and t_left < 1.0 - tol:
			t_values.append(t_left)
		var t_right := (right - p1.x) / dir.x
		if t_right > tol and t_right < 1.0 - tol:
			t_values.append(t_right)

	if abs(dir.y) > tol:
		var t_top := (top - p1.y) / dir.y
		if t_top > tol and t_top < 1.0 - tol:
			t_values.append(t_top)
		var t_bottom := (bottom - p1.y) / dir.y
		if t_bottom > tol and t_bottom < 1.0 - tol:
			t_values.append(t_bottom)

	t_values.sort()

	# Remove near-duplicate t values
	var unique_t: Array[float] = []
	for t in t_values:
		if unique_t.is_empty() or abs(t - unique_t.back()) > tol:
			unique_t.append(clamp(t, 0.0, 1.0))

	# Test midpoints of each sub-interval [t_i, t_{i+1}]
	for i in range(unique_t.size() - 1):
		var t_start := unique_t[i]
		var t_end := unique_t[i + 1]
		if abs(t_end - t_start) <= tol:
			continue

		var t_mid := (t_start + t_end) / 2.0
		var p_mid := p1 + dir * t_mid

		# Check if midpoint is inside erased rectangle
		if not point_inside_rect(p_mid, rect, tol):
			var sub_p1 := p1 + dir * t_start
			var sub_p2 := p1 + dir * t_end
			var sub_seg := VectorGeometry.LineSegment2D.new(sub_p1, sub_p2)
			if not sub_seg.is_degenerate(tol):
				result.append(sub_seg)

	return result

static func point_inside_rect(pt: Vector2, rect: Rect2, tol: float = 0.001) -> bool:
	return (pt.x > rect.position.x + tol and pt.x < rect.position.x + rect.size.x - tol and
			pt.y > rect.position.y + tol and pt.y < rect.position.y + rect.size.y - tol)
