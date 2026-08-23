using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using PuzzleGame.UI;
using PuzzleGame.Board;

public class SetupPuzzleScene : EditorWindow
{
    [MenuItem("PuzzleGame/Setup Main Scene")]
    static void Setup()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        // Main Camera
        var camGO = GameObject.Find("Main Camera");
        if(camGO!=null)
        {
            var cam = camGO.GetComponent<Camera>();
            cam.backgroundColor = new Color(0.08f,0.09f,0.14f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.orthographic = true;
            cam.orthographicSize = 5f;
            if(camGO.GetComponent<PixelFilterEffect>()==null)
                camGO.AddComponent<PixelFilterEffect>();
        }
        // Create Canvas
        var canvasGO = new GameObject("Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
        var canvas = canvasGO.GetComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        var scaler = canvasGO.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(540,960);
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
        scaler.matchWidthOrHeight = 0.5f;
        scaler.referencePixelsPerUnit = 100;

        // GameUI Root
        var gameUIGO = new GameObject("GameUI");
        gameUIGO.transform.SetParent(canvasGO.transform, false);
        var gameUI = gameUIGO.AddComponent<GameUI>();
        gameUIGO.AddComponent<RectTransform>();

        // HUD placeholder
        var hudGO = new GameObject("HUD", typeof(RectTransform));
        hudGO.transform.SetParent(gameUIGO.transform, false);
        gameUI.hud = hudGO;
        // Controls
        var controlsGO = new GameObject("Controls", typeof(RectTransform), typeof(HorizontalLayoutGroup));
        controlsGO.transform.SetParent(gameUIGO.transform, false);
        gameUI.controls = controlsGO;
        // DrawingBoard
        var boardGO = new GameObject("DrawingBoard");
        boardGO.transform.SetParent(gameUIGO.transform, false);
        var board = boardGO.AddComponent<DrawingBoard>();
        board.boardDef = new BoardDefinition(8);
        gameUI.drawingBoard = board;
        // InputHandler
        var inputGO = new GameObject("InputHandler", typeof(RectTransform), typeof(Image));
        inputGO.transform.SetParent(canvasGO.transform, false);
        var rt = inputGO.GetComponent<RectTransform>();
        rt.anchorMin = Vector2.zero; rt.anchorMax = Vector2.one; rt.offsetMin=Vector2.zero; rt.offsetMax=Vector2.zero;
        var img = inputGO.GetComponent<Image>(); img.color = new Color(0,0,0,0); img.raycastTarget = true;
        var handler = inputGO.AddComponent<InputHandler>();
        gameUI.inputHandler = handler;
        // TargetDisplay
        var targetGO = new GameObject("TargetDisplay", typeof(RectTransform));
        targetGO.transform.SetParent(hudGO.transform, false);
        var td = targetGO.AddComponent<TargetDisplay>();
        gameUI.targetDisplay = td;
        var checkpointGO = new GameObject("CheckpointDisplay", typeof(RectTransform));
        checkpointGO.transform.SetParent(hudGO.transform, false);
        var cp = checkpointGO.AddComponent<TargetDisplay>();
        gameUI.checkpointDisplay = cp;
        // TurnTimeline
        var timelineGO = new GameObject("TurnTimeline", typeof(RectTransform));
        timelineGO.transform.SetParent(hudGO.transform, false);
        var tl = timelineGO.AddComponent<TurnTimeline>();
        gameUI.turnTimeline = tl;
        // SolutionStrip
        var stripGO = new GameObject("SolutionStrip", typeof(RectTransform));
        stripGO.transform.SetParent(hudGO.transform, false);
        var strip = stripGO.AddComponent<SolutionStrip>();
        gameUI.solutionStrip = strip;
        // MainMenu
        var menuGO = new GameObject("MainMenu", typeof(RectTransform), typeof(Image));
        menuGO.transform.SetParent(canvasGO.transform, false);
        var menuRT = menuGO.GetComponent<RectTransform>();
        menuRT.anchorMin=Vector2.zero; menuRT.anchorMax=Vector2.one; menuRT.offsetMin=Vector2.zero; menuRT.offsetMax=Vector2.zero;
        var menuImg = menuGO.GetComponent<Image>(); menuImg.color = new Color(0.08f,0.09f,0.14f,1f);
        var menu = menuGO.AddComponent<MainMenu>();
        // Buttons for menu
        var btnStoryGO = new GameObject("BtnStory", typeof(RectTransform), typeof(Image), typeof(Button));
        btnStoryGO.transform.SetParent(menuGO.transform,false);
        var btnStoryRT = btnStoryGO.GetComponent<RectTransform>(); btnStoryRT.sizeDelta=new Vector2(260,68); btnStoryRT.anchoredPosition=new Vector2(0,20);
        var btnStory = btnStoryGO.GetComponent<Button>();
        var txtStoryGO = new GameObject("Text", typeof(RectTransform), typeof(Text));
        txtStoryGO.transform.SetParent(btnStoryGO.transform,false);
        var txtStory = txtStoryGO.GetComponent<Text>(); txtStory.text="STORY"; txtStory.alignment=TextAnchor.MiddleCenter; txtStory.color=Color.white; txtStory.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        var txtRT = txtStoryGO.GetComponent<RectTransform>(); txtRT.anchorMin=Vector2.zero; txtRT.anchorMax=Vector2.one; txtRT.offsetMin=Vector2.zero; txtRT.offsetMax=Vector2.zero;
        menu.btnStory = btnStory;
        var btnDebugGO = new GameObject("BtnDebug", typeof(RectTransform), typeof(Image), typeof(Button));
        btnDebugGO.transform.SetParent(menuGO.transform,false);
        var btnDebugRT = btnDebugGO.GetComponent<RectTransform>(); btnDebugRT.sizeDelta=new Vector2(260,68); btnDebugRT.anchoredPosition=new Vector2(0,-60);
        var btnDebug = btnDebugGO.GetComponent<Button>();
        var txtDebugGO = new GameObject("Text", typeof(RectTransform), typeof(Text));
        txtDebugGO.transform.SetParent(btnDebugGO.transform,false);
        var txtDebug = txtDebugGO.GetComponent<Text>(); txtDebug.text="DEBUG"; txtDebug.alignment=TextAnchor.MiddleCenter; txtDebug.color=Color.white; txtDebug.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        var txtDRT = txtDebugGO.GetComponent<RectTransform>(); txtDRT.anchorMin=Vector2.zero; txtDRT.anchorMax=Vector2.one; txtDRT.offsetMin=Vector2.zero; txtDRT.offsetMax=Vector2.zero;
        menu.btnDebug = btnDebug;
        var progGO = new GameObject("ProgressLabel", typeof(RectTransform), typeof(Text));
        progGO.transform.SetParent(menuGO.transform,false);
        var progRT = progGO.GetComponent<RectTransform>(); progRT.sizeDelta=new Vector2(460,34); progRT.anchoredPosition=new Vector2(0,80);
        var progTxt = progGO.GetComponent<Text>(); progTxt.alignment=TextAnchor.MiddleCenter; progTxt.color=Color.white; progTxt.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        menu.labelProgress = progTxt;
        gameUI.mainMenu = menu;

        // Title label
        var titleGO = new GameObject("TitleLabel", typeof(RectTransform), typeof(Text));
        titleGO.transform.SetParent(hudGO.transform,false);
        var titleRT = titleGO.GetComponent<RectTransform>(); titleRT.anchorMin=new Vector2(0.5f,1); titleRT.anchorMax=new Vector2(0.5f,1); titleRT.sizeDelta=new Vector2(360,38); titleRT.anchoredPosition=new Vector2(0,-50);
        var titleTxt = titleGO.GetComponent<Text>(); titleTxt.alignment=TextAnchor.MiddleCenter; titleTxt.fontSize=26; titleTxt.color=new Color(0.9f,0.95f,1f); titleTxt.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        gameUI.titleLabel = titleTxt;
        // Status label
        var statusGO = new GameObject("StatusLabel", typeof(RectTransform), typeof(Text));
        statusGO.transform.SetParent(hudGO.transform,false);
        var statusRT = statusGO.GetComponent<RectTransform>(); statusRT.anchorMin=new Vector2(0.5f,0); statusRT.anchorMax=new Vector2(0.5f,0); statusRT.sizeDelta=new Vector2(500,36); statusRT.anchoredPosition=new Vector2(0,120);
        var statusTxt = statusGO.GetComponent<Text>(); statusTxt.alignment=TextAnchor.MiddleCenter; statusTxt.color=Color.white; statusTxt.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        gameUI.labelStatus = statusTxt;
        // Btns for controls
        System.Func<string, Button> makeBtn = (name)=>{
            var go = new GameObject(name, typeof(RectTransform), typeof(Image), typeof(Button));
            go.transform.SetParent(controlsGO.transform,false);
            var rt2 = go.GetComponent<RectTransform>(); rt2.sizeDelta=new Vector2(130,48);
            var btn = go.GetComponent<Button>();
            var img2 = go.GetComponent<Image>(); img2.color=new Color(0.2f,0.25f,0.34f);
            var tgo = new GameObject("Text", typeof(RectTransform), typeof(Text));
            tgo.transform.SetParent(go.transform,false);
            var t = tgo.GetComponent<Text>(); t.text=name; t.alignment=TextAnchor.MiddleCenter; t.color=Color.white; t.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            var trt = tgo.GetComponent<RectTransform>(); trt.anchorMin=Vector2.zero; trt.anchorMax=Vector2.one; trt.offsetMin=Vector2.zero; trt.offsetMax=Vector2.zero;
            return btn;
        };
        gameUI.btnReset = makeBtn("RESET");
        gameUI.btnSkip = makeBtn("SKIP TURN");
        gameUI.btnNewPuzzle = makeBtn("NEW PUZZLE");
        // Icon buttons row - create placeholders as IconButton
        System.Func<string, PuzzleGame.UI.IconButton.IconKind, IconButton> makeIcon = (name,kind)=>{
            var go = new GameObject(name, typeof(RectTransform), typeof(Image), typeof(Button));
            go.transform.SetParent(hudGO.transform,false);
            var rt2 = go.GetComponent<RectTransform>(); rt2.sizeDelta=new Vector2(64,48);
            var ic = go.AddComponent<IconButton>(); ic.iconKind=kind;
            return ic;
        };
        gameUI.btnMode = makeIcon("BtnModeToggle", IconButton.IconKind.DIFFICULTY);
        gameUI.btnTurns = makeIcon("BtnTurns", IconButton.IconKind.TURN_COUNT);
        gameUI.btnEraserToggle = makeIcon("BtnEraserToggle", IconButton.IconKind.ERASER_SHAPE);
        // Actually GameUI expects btnEraser vs btnEraserToggle naming - map both
        gameUI.btnEraser = gameUI.btnEraserToggle;
        gameUI.btnReveal = makeIcon("BtnReveal", IconButton.IconKind.REVEAL);
        gameUI.btnHint = makeIcon("BtnHint", IconButton.IconKind.HINT);
        gameUI.btnHint.gameObject.SetActive(false);
        gameUI.btnPixel = makeIcon("BtnPixel", IconButton.IconKind.PIXEL);
        gameUI.btnDirection = makeIcon("BtnDirection", IconButton.IconKind.DIRECTION);
        gameUI.btnInputMode = makeIcon("BtnInputMode", IconButton.IconKind.INPUT_MODE);
        gameUI.btnLayers = makeIcon("BtnLayers", IconButton.IconKind.LAYERS);
        gameUI.btnTimer = makeIcon("BtnTimer", IconButton.IconKind.TURN_CLOCK);
        gameUI.btnTutorial = makeIcon("BtnTutorial", IconButton.IconKind.TUTORIAL);
        gameUI.btnMenu = makeIcon("BtnMenu", IconButton.IconKind.MENU);

        // Assign some positions for icon row
        var iconPositions = new Vector2[]{ new Vector2(47, -96), new Vector2(121,-96), new Vector2(195,-96), new Vector2(269,-96), new Vector2(343,-96), new Vector2(121,-154), new Vector2(195,-154), new Vector2(269,-154), new Vector2(47,-212), new Vector2(121,-212), new Vector2(195,-212)};
        var icons = new IconButton[]{gameUI.btnMode, gameUI.btnTurns, gameUI.btnEraserToggle, gameUI.btnReveal, gameUI.btnPixel, gameUI.btnDirection, gameUI.btnInputMode, gameUI.btnLayers, gameUI.btnTimer, gameUI.btnTutorial, gameUI.btnMenu };
        for(int i=0;i<icons.Length && i<iconPositions.Length;i++)
        {
            var rt2 = icons[i].GetComponent<RectTransform>();
            rt2.anchorMin=new Vector2(0,1); rt2.anchorMax=new Vector2(0,1);
            rt2.anchoredPosition=iconPositions[i];
        }
        // Timeline and strip anchors
        var tlRT = timelineGO.GetComponent<RectTransform>(); tlRT.anchorMin=new Vector2(0,0); tlRT.anchorMax=new Vector2(1,0); tlRT.sizeDelta=new Vector2(-20,61); tlRT.anchoredPosition=new Vector2(0,200);
        var stripRT = stripGO.GetComponent<RectTransform>(); stripRT.anchorMin=new Vector2(0,0); stripRT.anchorMax=new Vector2(1,0); stripRT.sizeDelta=new Vector2(-20,78); stripRT.anchoredPosition=new Vector2(0,280);
        var targetRT = targetGO.GetComponent<RectTransform>(); targetRT.anchorMin=new Vector2(1,1); targetRT.anchorMax=new Vector2(1,1); targetRT.sizeDelta=new Vector2(125,125); targetRT.anchoredPosition=new Vector2(-77,-132);
        var cpRT = checkpointGO.GetComponent<RectTransform>(); cpRT.anchorMin=new Vector2(1,1); cpRT.anchorMax=new Vector2(1,1); cpRT.sizeDelta=new Vector2(125,125); cpRT.anchoredPosition=new Vector2(-77,-312); checkpointGO.SetActive(false);
        var hudRT = hudGO.GetComponent<RectTransform>(); if(hudRT==null) hudGO.AddComponent<RectTransform>();
        var canvasRT = canvasGO.GetComponent<RectTransform>(); canvasRT.anchorMin=Vector2.zero; canvasRT.anchorMax=Vector2.one; canvasRT.offsetMin=Vector2.zero; canvasRT.offsetMax=Vector2.zero;
        var controlsRT = controlsGO.GetComponent<RectTransform>(); controlsRT.anchorMin=new Vector2(0,0); controlsRT.anchorMax=new Vector2(1,0); controlsRT.sizeDelta=new Vector2(-40,55); controlsRT.anchoredPosition=new Vector2(0,42);

        // Pixel filter dummy GO
        var pixGO = new GameObject("PixelFilter");
        pixGO.transform.SetParent(gameUIGO.transform,false);
        gameUI.pixelFilter = pixGO;

        // Checkpoint title
        var cpTitleGO = new GameObject("CheckpointTitle", typeof(RectTransform), typeof(Text));
        cpTitleGO.transform.SetParent(checkpointGO.transform,false);
        var cpTitleRT = cpTitleGO.GetComponent<RectTransform>(); cpTitleRT.sizeDelta=new Vector2(115,26); cpTitleRT.anchoredPosition=new Vector2(0,50);
        var cpTitleTxt = cpTitleGO.GetComponent<Text>(); cpTitleTxt.text="STEP 1"; cpTitleTxt.alignment=TextAnchor.MiddleCenter; cpTitleTxt.color=Color.white; cpTitleTxt.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        gameUI.checkpointTitle = cpTitleTxt;

        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene, "Assets/Scenes/Main.unity");
        Debug.Log("Puzzle scene created at Assets/Scenes/Main.unity - open it and press Play");
    }
}
