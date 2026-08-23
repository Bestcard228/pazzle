using System.Collections.Generic;
using UnityEngine;

namespace PuzzleGame.Session
{
    public class StoryRunner
    {
        const string PREF_KEY = "story_task_index";
        public int taskIndex = 0;
        public bool taskCleared = false;

        public StoryRunner(){ LoadProgress(); }
        public bool IsFinished()=> StoryCampaign.IsFinished(taskIndex);
        public bool IsTutorialTask()=> StoryCampaign.IsTutorialTask(taskIndex);
        public string ProgressLabel()=> StoryCampaign.ProgressLabel(taskIndex);
        public Dictionary<string, object> CurrentConfig()
        {
            return new Dictionary<string, object>{
                {"difficulty", StoryCampaign.DifficultyForTask(taskIndex)},
                {"cycle", StoryCampaign.CycleForTask(taskIndex)},
                {"input_mode", StoryCampaign.InputModeForTask(taskIndex)},
                {"layers", StoryCampaign.LayersForTask(taskIndex)},
                {"clock", StoryCampaign.ClockForTask(taskIndex)}
            };
        }
        public void BeginTask(){ taskCleared=false; }
        public void MarkCleared(){ taskCleared=true; }
        public void RestartIfFinished(){ if(IsFinished()){ taskIndex=0; taskCleared=false; } }
        public void Advance(){ taskIndex++; taskCleared=false; SaveProgress(); }
        public void LoadProgress(){ taskIndex = PlayerPrefs.GetInt(PREF_KEY,0); taskIndex = Mathf.Clamp(taskIndex,0,StoryCampaign.TotalTasks()); }
        public void SaveProgress(){ PlayerPrefs.SetInt(PREF_KEY,taskIndex); PlayerPrefs.Save(); }
    }
}
