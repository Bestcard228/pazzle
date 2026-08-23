using System.Collections.Generic;
using UnityEngine;

namespace PuzzleGame.Board
{
    public class BoardDefinition
    {
        public int nodeCount = 8;
        public Vector2 resolution = new Vector2(64, 64);
        public Vector2 center = new Vector2(32, 32);
        public float radius = 24f;
        public List<Vector2> nodePositions = new List<Vector2>();

        public int erasureStartPhase = 0;
        public int erasureShape = EraserSystem.ErasureShape.DIAGONAL_WEDGE;
        public int erasureCycleId = EraserSystem.CYCLE_CLOCKWISE;
        public List<int> erasureOverride = new List<int>();

        public BoardDefinition(int pNodeCount = 8, Vector2 pRes = default, int pStartPhase = 0, int pShape = 0, int pCycle = 0)
        {
            if (pRes == default) pRes = new Vector2(64, 64);
            nodeCount = pNodeCount;
            resolution = pRes;
            center = pRes / 2f;
            radius = Mathf.Min(pRes.x, pRes.y) * 0.38f;
            erasureStartPhase = ((pStartPhase % 4) + 4) % 4;
            erasureShape = pShape;
            erasureCycleId = ((pCycle % EraserSystem.CYCLE_COUNT) + EraserSystem.CYCLE_COUNT) % EraserSystem.CYCLE_COUNT;
            ComputeNodePositions();
        }

        public BoardDefinition Duplicate()
        {
            var copy = new BoardDefinition(nodeCount, resolution, erasureStartPhase, erasureShape, erasureCycleId);
            copy.erasureOverride = new List<int>(erasureOverride);
            return copy;
        }

        public BoardDefinition WithErasureOverride(List<int> zones)
        {
            var copy = Duplicate();
            copy.erasureOverride = new List<int>(zones);
            return copy;
        }

        void ComputeNodePositions()
        {
            nodePositions.Clear();
            for (int i = 0; i < nodeCount; i++)
            {
                float angle = -Mathf.PI / 2f + (i * Mathf.PI * 2f / nodeCount);
                Vector2 raw = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
                Vector2 q = new Vector2(Mathf.Round(raw.x), Mathf.Round(raw.y));
                nodePositions.Add(q);
            }
        }

        public Vector2 GetNodePosition(int nodeId)
        {
            if (nodeId >= 0 && nodeId < nodePositions.Count) return nodePositions[nodeId];
            return center;
        }
    }
}
