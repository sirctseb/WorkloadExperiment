part of WorkloadExperiment;

/// [TaskController] oversees the presentation of the whole task
class TaskController implements TargetDelegate {
  
  /// The root view of the actual task
  DivElement taskRoot;
  
  /// The root view of the settings screen
  DivElement settingsRoot;
  
  /// Task state
  bool taskRunning = false;
  num _score = 0;
  num get score => _score;
  set score(num s) {
    _score = s;
    // update html
    taskRoot.query("#score-content").text = s.toStringAsFixed(0);
  }
  
  /// Task properties
  Task task;
  
  /// Web socket to communicate with data server
  WebSocket ws = new WebSocket("ws://localhost:8000/ws");
  
  /// Create a task controller
  TaskController() {
    // store task and settings root elements
    taskRoot = document.body.query("#task");
    settingsRoot = document.body.query("#settings");
    
    // register for keyboard input
    window.on.keyPress.add(handleKeyPress);
    
    // create the task
    //task = new ExampleTask(this);
    //task = new SlowTrialTask(this);
    //task = new FixedTrialTask(this);
    task = new TwoTargetSlowTrialTask(this);
  }
  
  void handleKeyPress(KeyboardEvent event) {
    // receive keyboard input
    if(event.which == "s".charCodeAt(0)) {
      // show settings screen
      showSettings();
    } else if(event.which == "t".charCodeAt(0)) {
      // show task screen
      showTask();
    } else if(event.which == "g".charCodeAt(0)) {
      // g for 'go', start the task
      task.start();
    } else if(event.which == "p".charCodeAt(0)) {
      // p for 'pause', stop the task
      task.stop();
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
  
  /* TargetDelegate implementation */
  void TargetClicked(Target target, MouseEvent event) {
    // notify data server
    ws.send("target hit: ${event.clientX}, ${event.clientY}");
    
    // update score
    num dist = sqrt(pow(target.x - event.clientX, 2) + pow(target.y - event.clientY, 2));
    score += 100 - dist;
  }
}
