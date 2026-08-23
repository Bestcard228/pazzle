using System;
using UnityEngine;
using UnityEngine.UI;

namespace PuzzleGame.UI
{
    public class MainMenu : MonoBehaviour
    {
        public event Action<bool> ModeChosen;
        public Button btnStory;
        public Button btnDebug;
        public Text labelProgress;
        float t=0f;

        void Awake()
        {
            if(btnStory!=null) btnStory.onClick.AddListener(()=> ModeChosen?.Invoke(true));
            if(btnDebug!=null) btnDebug.onClick.AddListener(()=> ModeChosen?.Invoke(false));
        }

        void Update(){ t+=Time.deltaTime; }

        public void SetStoryProgress(int taskIndex)
        {
            if(labelProgress==null) return;
            if(Session.StoryCampaign.IsFinished(taskIndex)){ labelProgress.text="STORY COMPLETE"; return; }
            labelProgress.text = $"{Session.StoryCampaign.TitleForTask(taskIndex)}  -  TASK {taskIndex+1} / {Session.StoryCampaign.TotalTasks()}";
        }
    }
}
