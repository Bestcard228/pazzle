using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;

namespace PuzzleGame.Core
{
    public static class GeometryClipper
    {
        public static VectorGeometry ClipGeometryOut(VectorGeometry geometry, EraseArea region, float tol = 0.001f)
        {
            var result = new VectorGeometry();
            if (geometry == null || geometry.IsEmpty() || region == null) return result;
            result = result.Canonicalize(); // ensure empty canonical
            // Actually start empty
            result = new VectorGeometry();
            foreach (var seg in geometry.segments)
                foreach (var s in ClipSegmentOutRegion(seg, region, tol))
                    result.AddSegment(s);
            return result.Canonicalize();
        }

        public static List<VectorGeometry.LineSegment2D> ClipSegmentOutRegion(VectorGeometry.LineSegment2D seg, EraseArea region, float tol = 0.001f)
        {
            var result = new List<VectorGeometry.LineSegment2D>();
            if (seg.IsDegenerate() || region == null) return result;

            Vector2 p1 = seg.p1;
            Vector2 p2 = seg.p2;
            Vector2 dir = p2 - p1;

            var tValues = new List<float> { 0f, 1f };
            tValues.AddRange(region.GetSplitParameters(p1, p2, tol));
            tValues.Sort();

            var unique = new List<float>();
            foreach (var t in tValues)
            {
                if (unique.Count == 0 || Mathf.Abs(t - unique[unique.Count - 1]) > tol)
                    unique.Add(Mathf.Clamp(t, 0f, 1f));
            }

            for (int i = 0; i < unique.Count - 1; i++)
            {
                float tStart = unique[i];
                float tEnd = unique[i + 1];
                if (Mathf.Abs(tEnd - tStart) <= tol) continue;
                float tMid = (tStart + tEnd) * 0.5f;
                if (region.Contains(p1 + dir * tMid, tol)) continue;
                var sub = new VectorGeometry.LineSegment2D(p1 + dir * tStart, p1 + dir * tEnd);
                if (!sub.IsDegenerate(tol)) result.Add(sub);
            }
            return result;
        }

        public static List<VectorGeometry.LineSegment2D> ClipSegmentOutRect(VectorGeometry.LineSegment2D seg, Rect rect, float tol = 0.001f)
        {
            return ClipSegmentOutRegion(seg, EraseArea.MakeRect(rect), tol);
        }
    }
}
