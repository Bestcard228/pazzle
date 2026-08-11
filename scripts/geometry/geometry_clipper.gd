class_name GeometryClipper
extends RefCounted

# Clips out (erases) any portion of `geometry` that falls inside `region`.
# Returns a new VectorGeometry containing the surviving line segments outside the region.
static func clip_geometry_out(geometry: VectorGeometry, region: EraseArea, tol: float = 0.001) -> VectorGeometry:
	var result := VectorGeometry.new()
	if geometry == null or geometry.is_empty() or region == null:
		return result

	for seg in geometry.segments:
		for s in clip_segment_out_region(seg, region, tol):
			result.add_segment(s)

	return result.canonicalize()

# Clips a single line segment against an erased region, keeping the sub-segments that lie
# OUTSIDE it. The region is convex, so splitting at every boundary crossing and testing
# each piece's midpoint is exact for both rectangles and wedges.
static func clip_segment_out_region(seg: VectorGeometry.LineSegment2D, region: EraseArea, tol: float = 0.001) -> Array[VectorGeometry.LineSegment2D]:
	var result: Array[VectorGeometry.LineSegment2D] = []
	if seg.is_degenerate() or region == null:
		return result

	var p1 := seg.p1
	var p2 := seg.p2
	var dir := p2 - p1

	var t_values: Array[float] = [0.0, 1.0]
	t_values.append_array(region.get_split_parameters(p1, p2, tol))
	t_values.sort()

	# Remove near-duplicate t values
	var unique_t: Array[float] = []
	for t in t_values:
		if unique_t.is_empty() or absf(t - unique_t.back()) > tol:
			unique_t.append(clampf(t, 0.0, 1.0))

	for i in range(unique_t.size() - 1):
		var t_start := unique_t[i]
		var t_end := unique_t[i + 1]
		if absf(t_end - t_start) <= tol:
			continue

		var t_mid := (t_start + t_end) / 2.0
		if region.contains(p1 + dir * t_mid, tol):
			continue

		var sub_seg := VectorGeometry.LineSegment2D.new(p1 + dir * t_start, p1 + dir * t_end)
		if not sub_seg.is_degenerate(tol):
			result.append(sub_seg)

	return result

# Convenience wrapper for the rectangular (half-plane) eraser.
static func clip_segment_out_rect(seg: VectorGeometry.LineSegment2D, rect: Rect2, tol: float = 0.001) -> Array[VectorGeometry.LineSegment2D]:
	return clip_segment_out_region(seg, EraseArea.make_rect(rect), tol)

static func point_inside_rect(pt: Vector2, rect: Rect2, tol: float = 0.001) -> bool:
	return EraseArea.make_rect(rect).contains(pt, tol)
