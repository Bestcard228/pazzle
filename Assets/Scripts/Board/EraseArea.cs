using System.Collections.Generic;
using UnityEngine;

namespace PuzzleGame.Board
{
    public class EraseArea
    {
        public enum Kind { RECT, WEDGE }
        public const float COS_45 = 0.7071067811865476f;
        public const float BOUNDARY_BIAS = 0.000001f;

        public Kind kind = Kind.RECT;
        public Rect rect = new Rect();
        public Vector2 apex = Vector2.zero;
        public Vector2 axis = Vector2.zero;
        public float halfAngleCos = COS_45;

        public static EraseArea MakeRect(Rect r)
        {
            var region = new EraseArea();
            region.kind = Kind.RECT;
            region.rect = r;
            return region;
        }

        public static EraseArea MakeWedge(Vector2 pApex, Vector2 pAxis, float pHalfAngleCos = COS_45)
        {
            var region = new EraseArea();
            region.kind = Kind.WEDGE;
            region.apex = pApex;
            region.axis = pAxis.normalized;
            region.halfAngleCos = pHalfAngleCos;
            return region;
        }

        public bool IsEmpty()
        {
            if (kind == Kind.WEDGE) return axis == Vector2.zero;
            return rect.width <= 0f || rect.height <= 0f;
        }

        public bool Contains(Vector2 point, float tol = 0.001f)
        {
            switch (kind)
            {
                case Kind.RECT:
                    return point.x > rect.x + tol && point.x < rect.x + rect.width - tol
                        && point.y > rect.y + tol && point.y < rect.y + rect.height - tol;
                case Kind.WEDGE:
                    Vector2 v = point - apex;
                    float dist = v.magnitude;
                    if (dist <= tol) return true;
                    return (Vector2.Dot(v, axis) / dist) >= halfAngleCos - BOUNDARY_BIAS;
            }
            return false;
        }

        public List<float> GetSplitParameters(Vector2 p1, Vector2 p2, float tol = 0.001f)
        {
            var outParams = new List<float>();
            Vector2 dir = p2 - p1;
            switch (kind)
            {
                case Kind.RECT:
                    if (Mathf.Abs(dir.x) > tol)
                    {
                        AppendParameter(outParams, (rect.x - p1.x) / dir.x, tol);
                        AppendParameter(outParams, (rect.x + rect.width - p1.x) / dir.x, tol);
                    }
                    if (Mathf.Abs(dir.y) > tol)
                    {
                        AppendParameter(outParams, (rect.y - p1.y) / dir.y, tol);
                        AppendParameter(outParams, (rect.y + rect.height - p1.y) / dir.y, tol);
                    }
                    break;
                case Kind.WEDGE:
                    foreach (var bd in GetBoundaryDirections())
                    {
                        float denom = dir.x * bd.y - dir.y * bd.x; // cross
                        if (Mathf.Abs(denom) > BOUNDARY_BIAS)
                        {
                            Vector2 ap = apex - p1;
                            float t = (ap.x * bd.y - ap.y * bd.x) / denom;
                            AppendParameter(outParams, t, tol);
                        }
                    }
                    break;
            }
            return outParams;
        }

        public List<Vector2> GetBoundaryDirections()
        {
            if (kind != Kind.WEDGE) return new List<Vector2>();
            float half = Mathf.Acos(Mathf.Clamp(halfAngleCos, -1f, 1f)) * Mathf.Rad2Deg;
            // Unity: rotate axis
            Vector2 a1 = Rotate(axis, half);
            Vector2 a2 = Rotate(axis, -half);
            return new List<Vector2> { a1, a2 };
        }

        static Vector2 Rotate(Vector2 v, float degrees)
        {
            float rad = degrees * Mathf.Deg2Rad;
            float cos = Mathf.Cos(rad);
            float sin = Mathf.Sin(rad);
            return new Vector2(v.x * cos - v.y * sin, v.x * sin + v.y * cos);
        }

        void AppendParameter(List<float> o, float t, float tol)
        {
            if (t > tol && t < 1f - tol) o.Add(t);
        }
    }
}
