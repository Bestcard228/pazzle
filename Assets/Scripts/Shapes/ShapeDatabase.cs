using System.Collections.Generic;
using PuzzleGame.Board;
using PuzzleGame.Core;
using UnityEngine;

namespace PuzzleGame.Shapes
{
    public static class ShapeDatabase
    {
        static Dictionary<string, ShapeTemplate> templates = new Dictionary<string, ShapeTemplate>();
        static bool initialized = false;

        static void EnsureInitialized()
        {
            if (initialized) return;
            initialized = true;
            templates["Triangle"] = new ShapeTemplate("Triangle","Triangle",4,true);
            templates["Square"] = new ShapeTemplate("Square","Square",5,true);
            templates["Circle"] = new ShapeTemplate("Circle","Circle",7,true);
            templates["Pentagon"] = new ShapeTemplate("Pentagon","Pentagon",6,true);
            templates["Star"] = new ShapeTemplate("Star","Star",6,true);
            templates["Line"] = new ShapeTemplate("Line","Line",2,false);
            templates["Polyline"] = new ShapeTemplate("Polyline","Polyline",3,false);
        }

        public static ShapeTemplate IdentifyShape(List<int> pNodeIds)
        {
            EnsureInitialized();
            if (pNodeIds == null || pNodeIds.Count < 2) return null;
            bool isClosed = pNodeIds.Count >= 4 && pNodeIds[0] == pNodeIds[pNodeIds.Count-1];
            var unique = new HashSet<int>(pNodeIds);
            int uCount = unique.Count;
            if (isClosed)
            {
                switch (uCount)
                {
                    case 3: return templates["Triangle"];
                    case 4: return templates["Square"];
                    case 5: return IsStarPattern(pNodeIds) ? templates["Star"] : templates["Pentagon"];
                    default: return uCount >= 7 ? templates["Circle"] : new ShapeTemplate("Polygon","Polygon",pNodeIds.Count,true);
                }
            }
            else
            {
                if (uCount == 2) return templates["Line"];
                else return templates["Polyline"];
            }
        }

        static bool IsStarPattern(List<int> nodeIds)
        {
            if (nodeIds.Count < 6) return false;
            int step1 = Mathf.Abs(nodeIds[1]-nodeIds[0]);
            return step1 > 1 && step1 != 4;
        }

        public static ShapeInstance CreateInstanceFromPath(List<int> pNodeIds, BoardDefinition boardDef)
        {
            var tmpl = IdentifyShape(pNodeIds);
            if (tmpl == null) return null;
            return tmpl.CreateInstance(pNodeIds, boardDef);
        }

        public static List<Dictionary<string, object>> GetEasyModePredefinedShapes(BoardDefinition boardDef)
        {
            EnsureInitialized();
            int N = boardDef.nodeCount;
            var shapes = new List<Dictionary<string, object>>();

            var triPath = new List<int>{0, N*3/8, N*5/8, 0};
            shapes.Add(new Dictionary<string, object>{{"name","Triangle"},{"instance", CreateInstanceFromPath(triPath, boardDef)},{"path", triPath}});

            var sqPath = new List<int>{0, N/4, N/2, N*3/4, 0};
            shapes.Add(new Dictionary<string, object>{{"name","Square"},{"instance", CreateInstanceFromPath(sqPath, boardDef)},{"path", sqPath}});

            var diaPath = new List<int>{N/8, N*3/8, N*5/8, N*7/8, N/8};
            shapes.Add(new Dictionary<string, object>{{"name","Diamond"},{"instance", CreateInstanceFromPath(diaPath, boardDef)},{"path", diaPath}});

            var circPath = new List<int>();
            for(int i=0;i<N;i++) circPath.Add(i);
            circPath.Add(0);
            shapes.Add(new Dictionary<string, object>{{"name","Circle"},{"instance", CreateInstanceFromPath(circPath, boardDef)},{"path", circPath}});

            var linePath = new List<int>{0, N/2};
            shapes.Add(new Dictionary<string, object>{{"name","Line"},{"instance", CreateInstanceFromPath(linePath, boardDef)},{"path", linePath}});

            return shapes;
        }
    }
}
