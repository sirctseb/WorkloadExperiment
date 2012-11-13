part of WorkloadTask;

/// [TaskController] oversees the presentation of the whole task
class TaskController {
  
  /// The root view of the actual task
  DivElement taskRoot;
  
  /// The root view of the settings screen
  DivElement settingsRoot;
  
  /// Task properties
  
  /// Web socket to communicate with data server
  WebSocket ws = new WebSocket("ws://localhost:8000/ws");
  
  /// Create a task controller
  TaskController() {
    // store task and settings root elements
    taskRoot = document.body.query("#task");
    settingsRoot = document.body.query("#settings");
    
    // register for keyboard input
    window.on.keyPress.add(handleKeyPress);
    
    // create target display
    Target target = new Target(ws);
  }
  
  void handleKeyPress(KeyboardEvent event) {
    // receive keyboard input
    if(event.which == "s".charCodeAt(0)) {
      // show settings screen
      showSettings();
    } else if(event.which == "t".charCodeAt(0)) {
      // show task screen
      showTask();
    }
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
