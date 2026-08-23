using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace PuzzleGame.Core
{
    public class VectorGeometry
    {
        public const float EPSILON = 0.01f;

        public class LineSegment2D
        {
            public Vector2 p1;
            public Vector2 p2;

            public LineSegment2D(Vector2 a = default, Vector2 b = default)
            {
                p1 = a;
                p2 = b;
            }

            public float Length() => Vector2.Distance(p1, p2);
            public bool IsDegenerate(float tol = EPSILON) => Length() <= tol;

            public LineSegment2D GetNormalized()
            {
                if (p1.x < p2.x - EPSILON || (Mathf.Abs(p1.x - p2.x) <= EPSILON && p1.y <= p2.y))
                    return new LineSegment2D(p1, p2);
                else
                    return new LineSegment2D(p2, p1);
            }

            public bool EqualsSegment(LineSegment2D other, float tol = EPSILON)
            {
                var a = GetNormalized();
                var b = other.GetNormalized();
                return Vector2.Distance(a.p1, b.p1) <= tol && Vector2.Distance(a.p2, b.p2) <= tol;
            }

            public LineSegment2D Duplicate() => new LineSegment2D(p1, p2);
            public override string ToString() => $"Line({p1.x:F2},{p1.y:F2} -> {p2.x:F2},{p2.y:F2})";
        }

        public List<LineSegment2D> segments = new List<LineSegment2D>();

        public VectorGeometry(IEnumerable<LineSegment2D> initial = null)
        {
            if (initial != null)
                foreach (var s in initial) AddSegment(s);
        }

        public void AddSegment(LineSegment2D seg)
        {
            if (seg != null && !seg.IsDegenerate())
                segments.Add(seg.Duplicate());
        }

        public void AddLine(Vector2 a, Vector2 b) => AddSegment(new LineSegment2D(a, b));

        public void Merge(VectorGeometry other)
        {
            if (other == null) return;
            foreach (var seg in other.segments) AddSegment(seg);
        }

        public bool IsEmpty() => segments.Count == 0;
        public void Clear() => segments.Clear();

        public VectorGeometry Duplicate()
        {
            var copy = new VectorGeometry();
            foreach (var s in segments) copy.AddSegment(s);
            return copy;
        }

        public VectorGeometry Canonicalize(float tol = EPSILON)
        {
            var normList = new List<LineSegment2D>();
            foreach (var seg in segments)
            {
                if (seg.IsDegenerate(tol)) continue;
                var n = seg.GetNormalized();
                bool exists = normList.Any(e => e.EqualsSegment(n, tol));
                if (!exists) normList.Add(n);
            }
            normList.Sort((a, b) =>
            {
                if (Mathf.Abs(a.p1.x - b.p1.x) > tol) return a.p1.x.CompareTo(b.p1.x);
                if (Mathf.Abs(a.p1.y - b.p1.y) > tol) return a.p1.y.CompareTo(b.p1.y);
                if (Mathf.Abs(a.p2.x - b.p2.x) > tol) return a.p2.x.CompareTo(b.p2.x);
                return a.p2.y.CompareTo(b.p2.y);
            });
            var canonical = new VectorGeometry();
            canonical.segments = normList;
            return canonical;
        }

        public bool IsEquivalentTo(VectorGeometry other, float tol = EPSILON)
        {
            if (other == null) return false;
            var cThis = Canonicalize(tol);
            var cOther = other.Canonicalize(tol);
            if (cThis.segments.Count != cOther.segments.Count) return false;
            for (int i = 0; i < cThis.segments.Count; i++)
                if (!cThis.segments[i].EqualsSegment(cOther.segments[i], tol)) return false;
            return true;
        }

        public override string ToString() => $"VectorGeometry({segments.Count} segs)";
    }
}
