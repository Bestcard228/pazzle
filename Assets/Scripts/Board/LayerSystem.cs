using System.Collections.Generic;
using UnityEngine;

namespace PuzzleGame.Board
{
    public static class LayerSystem
    {
        public const int MAX_LAYERS = 4;
        public const int SINGLE_LAYER = 1;

        public static readonly Color[] LAYER_COLORS = new Color[]
        {
            new Color(0.95f, 0.35f, 0.40f),
            new Color(0.35f, 0.90f, 0.55f),
            new Color(0.40f, 0.65f, 1.00f),
            new Color(0.95f, 0.80f, 0.30f),
        };

        public static readonly string[] LAYER_NAMES = new string[] { "RED", "GREEN", "BLUE", "YELLOW" };
        public static readonly Color SINGLE_LAYER_COLOR = new Color(0.95f, 0.75f, 0.20f, 0.95f);

        public static Color GetLayerColor(int layer, int layerCount = 2)
        {
            if (layerCount <= SINGLE_LAYER) return SINGLE_LAYER_COLOR;
            int idx = ((layer % MAX_LAYERS) + MAX_LAYERS) % MAX_LAYERS;
            return LAYER_COLORS[idx];
        }

        public static string GetLayerName(int layer)
        {
            int idx = ((layer % MAX_LAYERS) + MAX_LAYERS) % MAX_LAYERS;
            return LAYER_NAMES[idx];
        }

        public static int ClampLayerCount(int count) => Mathf.Clamp(count, SINGLE_LAYER, MAX_LAYERS);

        public static List<int> AssignLayerCycles(int layerCount, int shape, System.Random rng = null)
        {
            if (rng == null) rng = new System.Random();
            var usable = EraserSystem.GetUsableCycles(shape);
            var cycles = new List<int>();
            if (usable.Count == 0)
            {
                for (int i = 0; i < layerCount; i++) cycles.Add(EraserSystem.CYCLE_CLOCKWISE);
                return cycles;
            }
            var pool = new List<int>(usable);
            Shuffle(pool, rng);
            for (int i = 0; i < layerCount; i++) cycles.Add(pool[i % pool.Count]);
            return cycles;
        }

        public static List<int> AssignLayerStartPhases(int layerCount, System.Random rng = null)
        {
            if (rng == null) rng = new System.Random();
            var phases = new List<int>();
            var pool = new List<int>();
            for (int p = 0; p < EraserSystem.PHASE_COUNT; p++) pool.Add(p);
            Shuffle(pool, rng);
            for (int i = 0; i < layerCount; i++) phases.Add(pool[i % pool.Count]);
            return phases;
        }

        static void Shuffle<T>(List<T> list, System.Random rng)
        {
            for (int i = list.Count - 1; i > 0; i--)
            {
                int j = rng.Next(i + 1);
                T tmp = list[i]; list[i] = list[j]; list[j] = tmp;
            }
        }
    }
}
