using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Shapes;

namespace PuzzleGame.UI
{
    public class SolutionStrip : MonoBehaviour
    {
        public BoardDefinition boardDef;
        public PuzzleSolution solution;
        public bool isRevealed = false;
        public List<int> eraseOrder = new List<int>();
        public LayeredSolution layeredSolution;
        public int layerCount = 1;

        public void SetSolution(PuzzleSolution pSolution, BoardDefinition pBoardDef){ solution=pSolution; boardDef=pBoardDef; }
        public void SetRevealed(bool pRevealed){ isRevealed=pRevealed; }
        public void SetLayeredSolution(LayeredSolution pLayered, int pLayerCount){ layeredSolution=pLayered; layerCount=pLayerCount; }
        public bool UsesLayers()=> layerCount>1 && layeredSolution!=null;
        public void SetEraseOrder(List<int> pOrder){ eraseOrder=new List<int>(pOrder); }
    }
}
