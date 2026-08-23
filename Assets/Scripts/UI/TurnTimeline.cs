using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;

namespace PuzzleGame.UI
{
    public class TurnTimeline : MonoBehaviour
    {
        public Color colorCellBg = new Color(0.14f,0.16f,0.24f);
        public Color colorCellBorder = new Color(0.30f,0.35f,0.45f,0.6f);
        public Color colorCurrent = new Color(0.40f,0.70f,1f);
        public Color colorWarn = new Color(0.95f,0.30f,0.35f);
        public Color colorDrawn = new Color(0.95f,0.75f,0.20f);

        public BoardDefinition boardDef;
        public int maxTurns = 4;
        public int currentTurn = 0;
        public List<bool> drawnTurns = new List<bool>();
        float pulseT = 0f;

        public bool showsShapes = false;
        public PuzzleSolution shapeSolution;
        public List<int> committedZones = new List<int>();

        void Update(){ pulseT+=Time.deltaTime; }

        public void Setup(BoardDefinition pBoardDef, int pMaxTurns)
        {
            boardDef=pBoardDef; maxTurns=Mathf.Max(1,pMaxTurns); currentTurn=0;
            drawnTurns.Clear(); for(int i=0;i<maxTurns;i++) drawnTurns.Add(false);
        }

        public void SetShapeMode(bool pEnabled, PuzzleSolution pSolution){ showsShapes=pEnabled; shapeSolution=pSolution; }
        public void SetCommittedZones(List<int> pZones){ committedZones=new List<int>(pZones); }
        public void SetProgress(int pCurrentTurn, List<bool> pDrawnTurns){ currentTurn=pCurrentTurn; drawnTurns=new List<bool>(pDrawnTurns); }

        // Rendering is handled via OnGUI / Graphics in Unity UI; this class holds state for DrawingBoard / UI to render.
        public int GetPhaseForTurn(int turn)
        {
            if(showsShapes)
            {
                if(turn < committedZones.Count) return committedZones[turn];
                return -1;
            }
            return EraserSystem.GetPhaseForTurn(turn, boardDef);
        }

        void OnGUI()
        {
            if(boardDef==null||maxTurns<=0) return;
            // Simple IMGUI fallback to visualize timeline in editor - draws cells as boxes
            var rect = GetComponent<RectTransform>()!=null ? GetComponent<RectTransform>().rect : new Rect(0,0,500,80);
            // Not drawing in OnGUI to avoid clutter; actual drawing via Unity UI elements will be built in GameUI.
        }
    }
}
