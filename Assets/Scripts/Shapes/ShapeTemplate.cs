using System.Collections.Generic;
using PuzzleGame.Board;
using PuzzleGame.Core;
using UnityEngine;

namespace PuzzleGame.Shapes
{
    public class ShapeTemplate
    {
        public string id;
        public string name;
        public int minNodes;
        public bool isClosed;

        public ShapeTemplate(string pId="", string pName="", int pMinNodes=3, bool pClosed=true)
        {
            id=pId; name=pName; minNodes=pMinNodes; isClosed=pClosed;
        }

        public ShapeInstance CreateInstance(List<int> nodeIds, BoardDefinition boardDef)
        {
            var geom = new VectorGeometry();
            for (int i=0;i<nodeIds.Count-1;i++)
            {
                var a = boardDef.GetNodePosition(nodeIds[i]);
                var b = boardDef.GetNodePosition(nodeIds[i+1]);
                geom.AddLine(a,b);
            }
            var inst = new ShapeInstance();
            inst.templateId = id;
            inst.nodeIds = new List<int>(nodeIds);
            inst.geometry = geom;
            return inst;
        }
    }
}
