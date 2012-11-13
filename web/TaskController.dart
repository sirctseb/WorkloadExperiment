part of WorkloadTask;

/// [TaskController] oversees the presentation of the whole task
class TaskController {
  
  /// The root view of the actual task
  DivElement taskRoot;
  
  /// The root view of the settings screen
  DivElement settingsRoot;
  
  /// Task properties
  
  TaskController() {
    
  }
  
  void showSettings() {
    // hide task root
    taskRoot.style.display = "none";
    
    // show settings root
    settingsRoot.style.display = "block";
  }
  
  void showTask() {
    // hide settings root
    settingsRoot.style.display = "none";
    
    // show task root
    taskRoot.style.display = "block";
  }
}
