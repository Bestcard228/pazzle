using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using PuzzleGame.Board;

namespace PuzzleGame.UI
{
    public class InputHandler : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        public event Action<List<int>> ShapeDrawn;
        public event Action<List<int>> ActivePathChanged;
        public event Action<int, Vector2> NodePressed;
        public event Action<int> NodeReleased;
        public event Action<int> HoverUpdated;
        public event Action<Vector2, bool> PositionUpdated;
        public event Action<Vector2> PreviewPositionUpdated;
        public event Action<bool> LoopClosedChanged;

        public BoardDefinition boardDef;
        public List<Vector2> nodeScreenPositions = new List<Vector2>();
        public List<int> activeNodeIds = new List<int>();
        public bool isDragging = false;
        public bool isEnabled = true;
        public Vector2 currentTouchPos;

        public const float DETECTION_RADIUS = 70f;
        public const float DOT_RADIUS = 32f;

        int backtrackTargetId = -1;
        float backtrackProgress = 0f;
        int hoveredNodeId = -1;
        int lastValidNodeId = -1;
        bool isBacktrackingEnabled = true;
        bool loopClosed = false;

        public void Setup(BoardDefinition pBoardDef, List<Vector2> pScreenPositions)
        {
            boardDef = pBoardDef;
            nodeScreenPositions = new List<Vector2>(pScreenPositions);
        }

        public void SetEnabled(bool pEnabled)
        {
            isEnabled = pEnabled;
            if(!pEnabled && isDragging) FinishDrag();
        }

        public void OnPointerDown(PointerEventData eventData)
        {
            if(!isEnabled||nodeScreenPositions.Count==0) return;
            BeginDrag(eventData.position);
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if(isDragging) FinishDrag();
        }

        public void OnDrag(PointerEventData eventData)
        {
            if(!isDragging) return;
            ProcessDrag(eventData.position);
        }

        void BeginDrag(Vector2 pos)
        {
            isDragging = true;
            currentTouchPos = pos;
            PositionUpdated?.Invoke(pos,true);
            PreviewPositionUpdated?.Invoke(pos);
            CheckNodeHit(pos);
        }

        void ProcessDrag(Vector2 pos)
        {
            currentTouchPos = pos;
            UpdateBacktracking(pos);
            PositionUpdated?.Invoke(pos,true);
            PreviewPositionUpdated?.Invoke(pos);
            UpdateHover(pos);
            CheckForNewDot(pos);
        }

        void CheckNodeHit(Vector2 pos)
        {
            int best = FindBestHitNode(pos);
            if(best==-1)
            {
                if(hoveredNodeId!=-1){ hoveredNodeId=-1; HoverUpdated?.Invoke(-1); }
                return;
            }
            if(hoveredNodeId!=best){ hoveredNodeId=best; HoverUpdated?.Invoke(best); }
            int changed = HandlePathUpdate(best,pos);
            if(changed==1) NodePressed?.Invoke(best,pos);
        }

        void UpdateHover(Vector2 pos)
        {
            int nearest=-1; float nearestDist=float.MaxValue;
            for(int i=0;i<nodeScreenPositions.Count;i++){
                float d=Vector2.Distance(pos, nodeScreenPositions[i]);
                if(d<=DETECTION_RADIUS && d<nearestDist){ nearest=i; nearestDist=d; }
            }
            if(nearest!=hoveredNodeId){ hoveredNodeId=nearest; HoverUpdated?.Invoke(nearest); }
        }

        int FindBestHitNode(Vector2 pos)
        {
            int best=-1; float bestDist=float.MaxValue;
            for(int i=0;i<nodeScreenPositions.Count;i++){
                float dist=Vector2.Distance(pos, nodeScreenPositions[i]);
                if(dist<=DETECTION_RADIUS){
                    bool already = activeNodeIds.Contains(i);
                    if(!already || (activeNodeIds.Count>=3 && i==activeNodeIds[0])){
                        if(dist<bestDist){ best=i; bestDist=dist; }
                    }
                }
            }
            return best;
        }

        int HandlePathUpdate(int nodeId, Vector2 pos)
        {
            if(activeNodeIds.Count==0){ activeNodeIds.Add(nodeId); ActivePathChanged?.Invoke(new List<int>(activeNodeIds)); lastValidNodeId=nodeId; return 1; }
            if(!activeNodeIds.Contains(nodeId)){ activeNodeIds.Add(nodeId); ActivePathChanged?.Invoke(new List<int>(activeNodeIds)); lastValidNodeId=nodeId; return 1; }
            return 0;
        }

        void UpdateBacktracking(Vector2 pos)
        {
            if(!isBacktrackingEnabled||activeNodeIds.Count<2){ backtrackTargetId=-1; backtrackProgress=0; return; }
            int curId=activeNodeIds[activeNodeIds.Count-1];
            int prevId=activeNodeIds[activeNodeIds.Count-2];
            Vector2 curPos=nodeScreenPositions[curId];
            Vector2 prevPos=nodeScreenPositions[prevId];
            float distFromCurrent=Vector2.Distance(pos,curPos);
            float distToPrev=Vector2.Distance(pos,prevPos);
            if(distToPrev>DOT_RADIUS || distToPrev>=distFromCurrent){ backtrackTargetId=-1; backtrackProgress=0; return; }
            backtrackTargetId=prevId;
            int removed=activeNodeIds[activeNodeIds.Count-1]; activeNodeIds.RemoveAt(activeNodeIds.Count-1);
            ActivePathChanged?.Invoke(new List<int>(activeNodeIds));
            NodeReleased?.Invoke(removed);
            lastValidNodeId=activeNodeIds.Count>0? activeNodeIds[activeNodeIds.Count-1] : -1;
            if(loopClosed){ loopClosed=false; LoopClosedChanged?.Invoke(false); }
            backtrackTargetId=-1; backtrackProgress=0;
        }

        void CheckForNewDot(Vector2 pos)
        {
            if(backtrackTargetId!=-1) return;
            if(loopClosed) return;
            int best=FindBestHitNode(pos);
            if(best==-1) return;
            float dist=Vector2.Distance(pos, nodeScreenPositions[best]);
            if(dist>DOT_RADIUS) return;
            if(activeNodeIds.Count==0){ activeNodeIds.Add(best); ActivePathChanged?.Invoke(new List<int>(activeNodeIds)); lastValidNodeId=best; NodePressed?.Invoke(best,pos); return; }
            if(activeNodeIds.Count>=3 && best==activeNodeIds[0]){ activeNodeIds.Add(best); loopClosed=true; ActivePathChanged?.Invoke(new List<int>(activeNodeIds)); LoopClosedChanged?.Invoke(true); NodePressed?.Invoke(best,pos); return; }
            if(best==activeNodeIds[activeNodeIds.Count-1]) return;
            activeNodeIds.Add(best); ActivePathChanged?.Invoke(new List<int>(activeNodeIds)); lastValidNodeId=best; NodePressed?.Invoke(best,pos);
        }

        void FinishDrag()
        {
            isDragging=false;
            backtrackTargetId=-1; backtrackProgress=0;
            loopClosed=false; LoopClosedChanged?.Invoke(false);
            if(activeNodeIds.Count>=2) ShapeDrawn?.Invoke(new List<int>(activeNodeIds));
            activeNodeIds.Clear(); ActivePathChanged?.Invoke(new List<int>(activeNodeIds));
            hoveredNodeId=-1; HoverUpdated?.Invoke(-1);
            PositionUpdated?.Invoke(currentTouchPos,false);
        }

        // Mouse fallback for editor
        void Update()
        {
            if(!isEnabled) return;
            // Handle mouse when not using EventSystem drag (for quick testing)
            if(Input.GetMouseButtonDown(0) && !isDragging)
            {
                Vector2 pos = Input.mousePosition;
                // Convert from bottom-left to top-left if needed; Unity Screen space is bottom-left for Input, but UI is top-left?
                // For simplicity use raw screen pos; caller should convert via RectTransform utility.
                // Only trigger if over this handler's rect
                if(RectTransformUtility.RectangleContainsScreenPoint(GetComponent<RectTransform>(), pos, null))
                    BeginDrag(pos);
            }
            if(isDragging && Input.GetMouseButton(0))
            {
                ProcessDrag((Vector2)Input.mousePosition);
            }
            if(isDragging && Input.GetMouseButtonUp(0))
            {
                FinishDrag();
            }
        }
    }
}
