using System.Collections.Generic;
using PuzzleGame.Board;
using PuzzleGame.Shapes;

namespace PuzzleGame.Core
{
    public class LayeredSolution
    {
        public int layerCount;
        public int maxTurns;
        public List<PuzzleSolution> layers = new List<PuzzleSolution>();

        public LayeredSolution(int pLayerCount = 2, int pMaxTurns = 4)
        {
            layerCount = LayerSystem.ClampLayerCount(pLayerCount);
            maxTurns = pMaxTurns;
            for (int i = 0; i < layerCount; i++)
                layers.Add(new PuzzleSolution(pMaxTurns));
        }

        public PuzzleSolution GetLayer(int layer)
        {
            if (layer < 0 || layer >= layers.Count) return null;
            return layers[layer];
        }

        public void SetAction(int turn, int layer, ShapeInstance shape)
        {
            var sol = GetLayer(layer);
            if (sol != null) sol.SetAction(turn, shape);
        }

        public void ClearAction(int turn, int layer) => SetAction(turn, layer, null);

        public DrawAction GetAction(int turn, int layer)
        {
            var sol = GetLayer(layer);
            return sol != null ? sol.GetAction(turn) : null;
        }

        public ShapeInstance GetShape(int turn, int layer)
        {
            var a = GetAction(turn, layer);
            return a != null ? a.shapeInstance : null;
        }

        public bool IsDrawTurn(int turn)
        {
            for (int i = 0; i < layers.Count; i++)
                if (GetShape(turn, i) != null) return true;
            return false;
        }

        public int GetNonEmptyActionCount()
        {
            int count = 0;
            foreach (var s in layers) count += s.GetNonEmptyActionCount();
            return count;
        }

        public LayeredSolution Duplicate()
        {
            var copy = new LayeredSolution(layerCount, maxTurns);
            for (int i = 0; i < layers.Count; i++)
                copy.layers[i] = layers[i].Duplicate();
            return copy;
        }

        public override string ToString()
        {
            var parts = new List<string>();
            for (int i = 0; i < layers.Count; i++)
                parts.Add($"{LayerSystem.GetLayerName(i)}: {layers[i]}");
            return "LayeredSolution[\n  " + string.Join(",\n  ", parts) + "\n]";
        }
    }
}
