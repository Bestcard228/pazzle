using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;

namespace PuzzleGame.UI
{
    public class DrawingBoard : MonoBehaviour
    {
        public Color colorBoardFill = new Color(0.11f,0.13f,0.20f);
        public Color colorBoardRing = new Color(0.30f,0.35f,0.45f,0.5f);
        public Color colorDeadZone = new Color(0.03f,0.03f,0.06f,0.55f);
        public Color colorDivider = new Color(0.45f,0.52f,0.66f,0.45f);
        public Color colorWarn = new Color(0.95f,0.30f,0.35f);
        public Color colorNode = new Color(0.40f,0.70f,1f);
        public Color colorNodeActive = new Color(0.20f,0.95f,0.50f);
        public Color colorInk = new Color(0.95f,0.75f,0.20f,0.95f);
        public Color colorCleared = new Color(0.20f,0.95f,0.50f);

        public BoardDefinition boardDef;
        public VectorGeometry currentSurvivingGeometry;
        public int appliedErasurePhase = -1;
        public int upcomingErasurePhase = -1;
        public bool isCleared = false;
        public List<int> activeSwipeNodes = new List<int>();
        float pulseT = 0f;
        float drawProgress = 0f;
        float drawProgressTarget = 0f;
        float drawSpeed = 10f;
        int lastSwipeCount = 0;
        Dictionary<int,float> activePresses = new Dictionary<int,float>();
        int hoverGuidanceId = -1;
        public Vector2 previewPosition;
        public bool isPreviewActive = false;
        bool isLoopClosed = false;
        const float COMMIT_FLASH_TIME = 0.45f;
        List<int> commitFlashNodes = new List<int>();
        float commitFlashT = COMMIT_FLASH_TIME;
        public int layerCount = 1;
        public int activeLayer = 0;
        public List<VectorGeometry> layerGeometry = new List<VectorGeometry>();
        public List<int> layerAppliedPhases = new List<int>();
        public List<int> layerUpcomingPhases = new List<int>();

        public Color colorClock = new Color(0.55f,0.85f,1f);
        public Color colorClockUrgent = new Color(1f,0.35f,0.30f);
        public float clockFraction = -1f;
        float clockFlash = 0f;

        public bool zonePickingActive = false;
        public int hoveredZone = -1;
        public bool hoveredZoneLegal = true;
        public List<int> pickedZones = new List<int>();

        public Color colorHint = new Color(1f,0.85f,0.35f);
        public const float HINT_SHOW_TIME = 4.5f;
        List<int> hintNodes = new List<int>();
        float hintT = HINT_SHOW_TIME;

        public List<Vector2> nodeScreenPositions = new List<Vector2>();
        public Vector2 boardCenterScreen = new Vector2(270,490);
        public float boardRadiusScreen = 170f;

        Material lineMaterial;

        void Awake()
        {
            if(boardDef==null) boardDef=new BoardDefinition(8);
            RecomputeScreenPositions();
            var shader = Shader.Find("Hidden/Internal-Colored");
            if(shader!=null) lineMaterial = new Material(shader);
        }

        void Update()
        {
            var keysToRemove=new List<int>();
            foreach(var kv in activePresses){
                activePresses[kv.Key]+=Time.deltaTime*8f;
                if(activePresses[kv.Key]>=1f) keysToRemove.Add(kv.Key);
            }
            foreach(var k in keysToRemove) activePresses.Remove(k);
            if(commitFlashT < COMMIT_FLASH_TIME) commitFlashT+=Time.deltaTime;
            if(hintT < HINT_SHOW_TIME) hintT+=Time.deltaTime;
            if(clockFlash>0f) clockFlash = Mathf.Max(0f, clockFlash - Time.deltaTime*1.8f);

            int targetSwipe = activeSwipeNodes.Count;
            if(targetSwipe!=lastSwipeCount)
            {
                bool grew = targetSwipe>lastSwipeCount;
                lastSwipeCount=targetSwipe;
                if(targetSwipe<2){ drawProgress=0; drawProgressTarget=0; }
                else if(grew){ drawProgress=(float)(targetSwipe-2)/(float)(targetSwipe-1); drawProgressTarget=1f; }
                else{ drawProgress=1f; drawProgressTarget=1f; }
            }
            int segCount=Mathf.Max(1, activeSwipeNodes.Count-1);
            float step = Time.deltaTime*drawSpeed/(float)segCount;
            if(drawProgress < drawProgressTarget) drawProgress=Mathf.Min(drawProgressTarget, drawProgress+step);
            else if(drawProgress > drawProgressTarget) drawProgress=Mathf.Max(drawProgressTarget, drawProgress-step);

            if(upcomingErasurePhase>=0 || isCleared || hoveredZone>=0 || UsesLayers() || clockFraction>=0f) pulseT+=Time.deltaTime;
        }

        public void RecomputeScreenPositions()
        {
            nodeScreenPositions.Clear();
            if(boardDef==null) return;
            // Map board 64x64 to screen space
            // boardCenterScreen and radius already define screen mapping; compute node positions proportionally
            for(int i=0;i<boardDef.nodeCount;i++)
            {
                Vector2 boardPos = boardDef.GetNodePosition(i);
                Vector2 offset = boardPos - boardDef.center;
                // Normalize by board radius
                Vector2 screenPos = boardCenterScreen + offset * (boardRadiusScreen / boardDef.radius);
                nodeScreenPositions.Add(screenPos);
            }
        }

        public void SetBoardDefinition(BoardDefinition pBoardDef){ boardDef=pBoardDef; RecomputeScreenPositions(); }
        public void SetSurvivingGeometry(VectorGeometry geom){ currentSurvivingGeometry=geom; }
        public void SetErasurePhases(int pApplied, int pUpcoming){ appliedErasurePhase=pApplied; upcomingErasurePhase=pUpcoming; }
        public void SetCleared(bool pCleared){ isCleared=pCleared; }
        public void SetActiveSwipe(List<int> nodes){ activeSwipeNodes=new List<int>(nodes); }
        public void SetClockFraction(float f){ clockFraction=f; }
        public void FlashClockExpiry(){ clockFlash=1f; }
        public void SetLayerInfo(int pLayerCount,int pActiveLayer, List<VectorGeometry> pGeom, List<int> pApplied, List<int> pUpcoming)
        {
            layerCount=pLayerCount; activeLayer=pActiveLayer; layerGeometry=new List<VectorGeometry>(pGeom);
            layerAppliedPhases=new List<int>(pApplied); layerUpcomingPhases=new List<int>(pUpcoming);
        }
        public void SetZonePicking(bool active, int hovered, bool legal, List<int> picked)
        {
            zonePickingActive=active; hoveredZone=hovered; hoveredZoneLegal=legal; pickedZones=new List<int>(picked);
        }
        public void ShowHint(List<int> nodes){ hintNodes=new List<int>(nodes); hintT=0f; }
        public void TriggerCommitFlash(List<int> nodes){ commitFlashNodes=new List<int>(nodes); commitFlashT=0f; }


        // --- Compatibility helpers for GameUI ---
        public void SetLayerCount(int count){ layerCount=count; }
        public void SetActiveLayer(int layer){ activeLayer=layer; }
        public void SetLayerGeometry(List<VectorGeometry> geom){ layerGeometry=geom!=null? new List<VectorGeometry>(geom): new List<VectorGeometry>(); }
        public void SetLayerErasurePhases(List<int> applied, List<int> upcoming){ layerAppliedPhases=applied!=null? new List<int>(applied): new List<int>(); layerUpcomingPhases=upcoming!=null? new List<int>(upcoming): new List<int>(); }
        public void SetPickedZones(List<int> zones){ pickedZones=zones!=null? new List<int>(zones): new List<int>(); }
        public void SetHoveredZone(int zone, bool legal){ hoveredZone=zone; hoveredZoneLegal=legal; }
        public void SetZonePicking(bool active){ zonePickingActive=active; if(!active){ hoveredZone=-1; } }
        public void SetHoveredZoneCompat(int zone, bool legal){ SetHoveredZone(zone,legal); }
        public void ClearHint(){ hintNodes.Clear(); hintT=HINT_SHOW_TIME; }
        public void ShowHintPath(List<int> nodes){ ShowHint(nodes); }
        public bool IsHintShowing()=> hintT < HINT_SHOW_TIME;
        public void SetLoopClosed(bool closed){ isLoopClosed=closed; }
        public void OnNodePressed(int id, Vector2 pos){ if(!activePresses.ContainsKey(id)) activePresses[id]=0f; }
        public void OnNodeReleased(int id){}
        public void OnHoverUpdated(int id){ hoverGuidanceId=id; }
        public void OnInputPositionUpdated(Vector2 pos, bool dragging){ previewPosition=pos; isPreviewActive=dragging; }
        public void OnInputPreviewPositionUpdated(Vector2 pos){ previewPosition=pos; isPreviewActive=true; }
        public void FlashCommittedShape(List<int> nodes){ TriggerCommitFlash(nodes); }
        public void ClearHintCompat(){ ClearHint(); }
        public int ZoneAtPosition(Vector2 screenPos)
        {
            // Determine which wedge quadrant the point falls in relative to board center
            Vector2 delta = screenPos - boardCenterScreen;
            if(delta.magnitude < 10f) return -1;
            // In wedge mode, use axis dot test: find nearest axis
            float bestDot=-2f; int bestZone=-1;
            for(int z=0; z<4; z++)
            {
                Vector2 axis = EraserSystem.GetPhaseAxis(z);
                Vector2 n = delta.normalized;
                float dot = Vector2.Dot(n, axis);
                if(dot > bestDot){ bestDot=dot; bestZone=z; }
            }
            // Only if inside board radius?
            if(delta.magnitude > boardRadiusScreen+20f) return -1;
            // Check if within wedge half-angle (45deg => dot >= cos45)
            if(bestDot >= 0.7071f - 0.001f) return bestZone;
            return -1;
        }

        bool UsesLayers()=> layerCount>1;
        void OnPostRender()
        {
            // GL drawing - requires camera with PostRender; alternative is OnRenderObject
        }

        void OnRenderObject()
        {
            if(lineMaterial==null) return;
            var cam = Camera.current;
            if(cam==null) return;

            // Convert screen positions to world or directly use GL in screen space via GL.LoadPixelMatrix
            // Use GL in pixel matrix for overlay
            GL.PushMatrix();
            lineMaterial.SetPass(0);
            GL.LoadPixelMatrix(0, Screen.width, 0, Screen.height);

            // Draw board ring, erasure zones, geometry etc. using GL.LINES
            // Simplified: draw nodes, active swipe, surviving geometry

            // Board ring
            DrawCircleGL(boardCenterScreen, boardRadiusScreen, colorBoardRing, 32);

            // Dead zones (applied erasures)
            if(appliedErasurePhase>=0 && !UsesLayers())
                DrawWedgeGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(appliedErasurePhase), colorDeadZone);

            // Upcoming warning with pulse
            if(upcomingErasurePhase>=0 && !UsesLayers())
            {
                float pulse = 0.5f+0.5f*Mathf.Sin(pulseT*3f);
                Color c = Color.Lerp(colorWarn, Color.white, pulse*0.3f);
                c.a = Mathf.Lerp(0.2f,0.45f, pulse);
                DrawWedgeGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(upcomingErasurePhase), c);
                DrawWedgeHatchGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(upcomingErasurePhase), colorWarn);
            }

            // Layered wedges
            if(UsesLayers())
            {
                for(int layer=0; layer<layerCount; layer++)
                {
                    int phase = layer<layerUpcomingPhases.Count? layerUpcomingPhases[layer] : -1;
                    if(phase>=0)
                    {
                        Color ink = Board.LayerSystem.GetLayerColor(layer, layerCount);
                        ink.a = 0.35f + 0.2f*Mathf.Sin(pulseT*3f);
                        DrawWedgeGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(phase), ink);
                    }
                }
            }

            // Division cross in wedge mode
            if(boardDef!=null && boardDef.erasureShape==EraserSystem.ErasureShape.DIAGONAL_WEDGE)
            {
                Color div = colorDivider;
                GL.Begin(GL.LINES);
                GL.Color(div);
                Vector2 d1 = new Vector2(1,1).normalized * boardRadiusScreen;
                GL.Vertex(new Vector3(boardCenterScreen.x - d1.x, boardCenterScreen.y - d1.y,0));
                GL.Vertex(new Vector3(boardCenterScreen.x + d1.x, boardCenterScreen.y + d1.y,0));
                Vector2 d2 = new Vector2(1,-1).normalized * boardRadiusScreen;
                GL.Vertex(new Vector3(boardCenterScreen.x - d2.x, boardCenterScreen.y - d2.y,0));
                GL.Vertex(new Vector3(boardCenterScreen.x + d2.x, boardCenterScreen.y + d2.y,0));
                GL.End();
            }

            // Surviving geometry
            if(currentSurvivingGeometry!=null && !UsesLayers())
            {
                Color ink = isCleared? colorCleared : colorInk;
                DrawGeometryGL(currentSurvivingGeometry, ink, 3f);
            }
            if(UsesLayers())
            {
                for(int layer=0; layer<layerGeometry.Count; layer++)
                {
                    var geom = layerGeometry[layer];
                    if(geom==null) continue;
                    Color ink = Board.LayerSystem.GetLayerColor(layer, layerCount);
                    DrawGeometryGL(geom, ink, 3f);
                }
            }

            // Active swipe
            DrawActiveSwipeGL();

            // Nodes
            DrawNodesGL();

            // Preview line
            if(isPreviewActive && activeSwipeNodes.Count>0)
            {
                Vector2 last = nodeScreenPositions[activeSwipeNodes[activeSwipeNodes.Count-1]];
                GL.Begin(GL.LINES);
                GL.Color(new Color(0.6f,0.8f,1f,0.6f));
                GL.Vertex(new Vector3(last.x, last.y,0));
                GL.Vertex(new Vector3(previewPosition.x, previewPosition.y,0));
                GL.End();
            }

            // Hint ghost
            if(hintT < HINT_SHOW_TIME && hintNodes.Count>=2)
            {
                float prog = Mathf.Clamp01(hintT / 0.8f);
                // Fade alpha
                float alpha = 1f;
                if(hintT> 0.8f) alpha = 1f - Mathf.Clamp01((hintT-0.8f)/(HINT_SHOW_TIME-0.8f));
                DrawPathGhostGL(hintNodes, prog, alpha);
            }

            // Clock ring
            if(clockFraction>=0f || clockFlash>0f)
            {
                float frac = Mathf.Clamp01(clockFraction>=0f? clockFraction : 0f);
                Color c = frac<0.25f? colorClockUrgent : colorClock;
                if(clockFlash>0f) c = Color.Lerp(c, Color.white, clockFlash);
                DrawArcGL(boardCenterScreen, boardRadiusScreen+12f, 0f, Mathf.PI*2f*frac, c, 32);
            }

            // Zone picking highlights (ERASE mode)
            if(zonePickingActive)
            {
                foreach(var zone in pickedZones)
                {
                    DrawWedgeGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(zone), new Color(0.6f,0.6f,0.6f,0.3f));
                }
                if(hoveredZone>=0)
                {
                    Color hc = hoveredZoneLegal? new Color(1f,0.25f,0.3f,0.45f) : new Color(0.5f,0.5f,0.5f,0.3f);
                    DrawWedgeGL(boardCenterScreen, boardRadiusScreen, EraserSystem.GetPhaseAxis(hoveredZone), hc);
                }
            }

            GL.PopMatrix();
        }

        void DrawCircleGL(Vector2 center, float radius, Color color, int segments)
        {
            GL.Begin(GL.LINES);
            GL.Color(color);
            for(int i=0;i<segments;i++){
                float a0 = Mathf.PI*2f*i/segments;
                float a1 = Mathf.PI*2f*(i+1)/segments;
                Vector2 p0 = center + new Vector2(Mathf.Cos(a0), Mathf.Sin(a0))*radius;
                Vector2 p1 = center + new Vector2(Mathf.Cos(a1), Mathf.Sin(a1))*radius;
                GL.Vertex(new Vector3(p0.x,p0.y,0));
                GL.Vertex(new Vector3(p1.x,p1.y,0));
            }
            GL.End();
        }

        void DrawArcGL(Vector2 center, float radius, float startAngle, float sweep, Color color, int segments)
        {
            if(sweep<=0f) return;
            GL.Begin(GL.LINES);
            GL.Color(color);
            int steps = Mathf.Max(1, Mathf.RoundToInt(segments* sweep/(Mathf.PI*2f)));
            for(int i=0;i<steps;i++){
                float a0 = startAngle + sweep*i/steps;
                float a1 = startAngle + sweep*(i+1)/steps;
                Vector2 p0 = center + new Vector2(Mathf.Cos(a0), Mathf.Sin(a0))*radius;
                Vector2 p1 = center + new Vector2(Mathf.Cos(a1), Mathf.Sin(a1))*radius;
                GL.Vertex(new Vector3(p0.x,p0.y,0));
                GL.Vertex(new Vector3(p1.x,p1.y,0));
            }
            GL.End();
        }

        void DrawWedgeGL(Vector2 center, float radius, Vector2 axis, Color color)
        {
            if(axis==Vector2.zero) return;
            var poly = MiniBoard.WedgePolygon(center,radius,axis,12);
            GL.Begin(GL.TRIANGLES);
            GL.Color(color);
            for(int i=1;i<poly.Count-1;i++){
                GL.Vertex(new Vector3(poly[0].x,poly[0].y,0));
                GL.Vertex(new Vector3(poly[i].x,poly[i].y,0));
                GL.Vertex(new Vector3(poly[i+1].x,poly[i+1].y,0));
            }
            GL.End();
        }

        void DrawWedgeHatchGL(Vector2 center, float radius, Vector2 axis, Color color)
        {
            // Simple hatch lines across wedge
            var poly = MiniBoard.WedgePolygon(center,radius,axis,8);
            // Draw lines from center to edge
            GL.Begin(GL.LINES);
            GL.Color(new Color(color.r,color.g,color.b, color.a*0.5f));
            for(int i=1;i<poly.Count;i++){
                GL.Vertex(new Vector3(center.x,center.y,0));
                GL.Vertex(new Vector3(poly[i].x,poly[i].y,0));
            }
            GL.End();
        }

        void DrawGeometryGL(VectorGeometry geom, Color color, float width)
        {
            if(geom==null) return;
            GL.Begin(GL.LINES);
            GL.Color(color);
            foreach(var seg in geom.segments){
                Vector2 p1 = BoardToScreen(seg.p1);
                Vector2 p2 = BoardToScreen(seg.p2);
                GL.Vertex(new Vector3(p1.x,p1.y,0));
                GL.Vertex(new Vector3(p2.x,p2.y,0));
            }
            GL.End();
        }

        Vector2 BoardToScreen(Vector2 boardPos)
        {
            Vector2 offset = boardPos - boardDef.center;
            return boardCenterScreen + offset * (boardRadiusScreen / boardDef.radius);
        }

        void DrawActiveSwipeGL()
        {
            if(activeSwipeNodes.Count<1) return;
            GL.Begin(GL.LINES);
            GL.Color(colorNodeActive);
            // Determine how many segments to draw based on drawProgress
            int totalSegs = Mathf.Max(0, activeSwipeNodes.Count-1);
            float totalToDraw = totalSegs * drawProgress;
            int fullSegs = Mathf.FloorToInt(totalToDraw);
            float partial = totalToDraw - fullSegs;
            for(int i=0;i<fullSegs && i<totalSegs;i++){
                Vector2 a=nodeScreenPositions[activeSwipeNodes[i]];
                Vector2 b=nodeScreenPositions[activeSwipeNodes[i+1]];
                GL.Vertex(new Vector3(a.x,a.y,0));
                GL.Vertex(new Vector3(b.x,b.y,0));
            }
            if(partial>0f && fullSegs < totalSegs){
                Vector2 a=nodeScreenPositions[activeSwipeNodes[fullSegs]];
                Vector2 b=nodeScreenPositions[activeSwipeNodes[fullSegs+1]];
                Vector2 mid = Vector2.Lerp(a,b,partial);
                GL.Vertex(new Vector3(a.x,a.y,0));
                GL.Vertex(new Vector3(mid.x,mid.y,0));
            }
            GL.End();
        }

        void DrawNodesGL()
        {
            // Nodes as GL points (quads)
            foreach(var kv in nodeScreenPositions){ } // placeholder
            GL.Begin(GL.QUADS);
            for(int i=0;i<nodeScreenPositions.Count;i++){
                Vector2 pos=nodeScreenPositions[i];
                bool active = activeSwipeNodes.Contains(i);
                bool hovered = i==hoverGuidanceId;
                bool flash = commitFlashNodes.Contains(i) && commitFlashT < COMMIT_FLASH_TIME;
                Color c = colorNode;
                float size = 4f;
                if(active){ c=colorNodeActive; size=5f; }
                if(hovered){ c=Color.Lerp(c, Color.white, 0.5f+0.5f*Mathf.Sin(pulseT*6f)); size=6f; }
                if(flash){
                    float t = commitFlashT/COMMIT_FLASH_TIME;
                    float flashAlpha = 1f - t;
                    c = Color.Lerp(c, Color.white, flashAlpha);
                    size = Mathf.Lerp(6f, 9f, flashAlpha);
                }
                if(activePresses.ContainsKey(i)){
                    float prog = activePresses[i];
                    c = Color.Lerp(c, Color.white, 0.3f*Mathf.Sin(prog*Mathf.PI));
                    size = Mathf.Lerp(4f, 5.2f, Mathf.Sin(prog*Mathf.PI));
                }
                GL.Color(c);
                GL.Vertex(new Vector3(pos.x-size,pos.y-size,0));
                GL.Vertex(new Vector3(pos.x+size,pos.y-size,0));
                GL.Vertex(new Vector3(pos.x+size,pos.y+size,0));
                GL.Vertex(new Vector3(pos.x-size,pos.y+size,0));
            }
            GL.End();
        }

        void DrawPathGhostGL(List<int> path, float progress, float alpha)
        {
            if(path.Count<2) return;
            int totalSegs = path.Count-1;
            float toDraw = totalSegs*progress;
            int full = Mathf.FloorToInt(toDraw);
            float partial = toDraw - full;
            Color c = new Color(colorHint.r,colorHint.g,colorHint.b, alpha);
            GL.Begin(GL.LINES);
            GL.Color(c);
            for(int i=0;i<full && i<totalSegs;i++){
                Vector2 a = nodeScreenPositions[path[i]];
                Vector2 b = nodeScreenPositions[path[i+1]];
                GL.Vertex(new Vector3(a.x,a.y,0));
                GL.Vertex(new Vector3(b.x,b.y,0));
            }
            if(partial>0f && full<totalSegs){
                Vector2 a=nodeScreenPositions[path[full]];
                Vector2 b=nodeScreenPositions[path[full+1]];
                Vector2 mid=Vector2.Lerp(a,b,partial);
                GL.Vertex(new Vector3(a.x,a.y,0));
                GL.Vertex(new Vector3(mid.x,mid.y,0));
            }
            GL.End();
            // Dots
            GL.Begin(GL.QUADS);
            GL.Color(new Color(colorHint.r,colorHint.g,colorHint.b, alpha));
            for(int i=0;i<=full && i<path.Count;i++){
                Vector2 pos=nodeScreenPositions[path[i]];
                float s=3f;
                GL.Vertex(new Vector3(pos.x-s,pos.y-s,0));
                GL.Vertex(new Vector3(pos.x+s,pos.y-s,0));
                GL.Vertex(new Vector3(pos.x+s,pos.y+s,0));
                GL.Vertex(new Vector3(pos.x-s,pos.y+s,0));
            }
            GL.End();
        }
    }
}
