using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;

namespace PuzzleGame.UI
{
    public static class MiniBoard
    {
        public static float ScaleFor(BoardDefinition boardDef, float boxSize, float fill)
        {
            if(boardDef==null||boardDef.radius<=0f) return 1f;
            return (boxSize*fill)/boardDef.radius;
        }
        public static Vector2 ToScreen(BoardDefinition boardDef, Vector2 center, float scale, Vector2 point) => center + (point - boardDef.center)*scale;
        public static Vector2 NodePosition(BoardDefinition boardDef, Vector2 center, float scale, int nodeId) => ToScreen(boardDef, center, scale, boardDef.GetNodePosition(nodeId));
        public static float Radius(BoardDefinition boardDef, float scale) => boardDef.radius*scale;

        public static void DrawRing(Vector2 center, float radius, Color color, float width=1f)
        {
            // Uses Gizmos or GL - placeholder for editor; actual drawing via UI Graphics in MonoBehaviour
        }
        // Helpers for geometry drawing via GL - to be called from OnPopulateMesh or Gizmos
        public static void DrawFieldGizmos(BoardDefinition boardDef, Vector2 center, float scale, Color ringColor, Color dotColor, float dotSize=2f)
        {
            // Ring + dots via Gizmos for debug
            Gizmos.color = ringColor;
            // Not implemented drawing in gizmos helper; callers will use Unity GL
        }

        public static List<Vector2> WedgePolygon(Vector2 center, float radius, Vector2 axis, int steps=10)
        {
            var pts=new List<Vector2>();
            pts.Add(center);
            float start = Mathf.Atan2(axis.y, axis.x) - Mathf.PI*0.25f;
            for(int i=0;i<=steps;i++){
                float a = start + (Mathf.PI*0.5f)*(i/(float)steps);
                pts.Add(center + new Vector2(Mathf.Cos(a), Mathf.Sin(a))*radius);
            }
            return pts;
        }
    }
}
