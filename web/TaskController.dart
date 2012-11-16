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
    bool increase = s > score;
    _score = s;
    // update html
    taskRoot.query("#score-content").text = s.toStringAsFixed(0);
    // animate color of score text
    query(".score").classes.add(increase ? "increase" : "decrease");
    // remove the class in 400ms
    new Timer(400, (timer) {
      query(".score").classes.removeAll(["increase", "decrease"]);
    });
  }
  
  /// Task properties
  Task task;
  
  /// Web socket to communicate with data server
  WebSocket ws = new WebSocket("ws://localhost:8000/ws");
  
  /// An element to show feedback when a click occurs
  DivElement shotElement = new DivElement()..classes.add("shot");
  
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
    task = new FixedTrialTask(this);
    //task = new TwoTargetSlowTrialTask(this);
    
    // add handler to body for missed target clicks
    document.body.on.click.add(onBodyClick);
    document.body.elements.add(shotElement);
    
    // add handler to watch for changes to settings
    /*document.queryAll(".settings input").forEach((InputElement e) {
      e.on.change.add(settingChanged);
    })*/
    // only add handler on button click
    document.query("#set-params").on.click.add(settingChanged);
    
    // show task on startup
    showTask();
  }
  
  void settingChanged(Event event) {
    // if custom is enabled, create a new task
    if((query("#enable-custom") as InputElement).checked) {
      // parse input elements
      num iterations = getInputValue("iterations");
      num iterationTime = getInputValue("iteration-time");
      num numTargets = getInputValue("num-targets");
      num targetDist = getInputValue("target-dist");
      num maxOp = getInputValue("max-op");
      
      task = new ConfigurableTrialTask(this,
          iterations: iterations,
          iterationTime: iterationTime, 
          numTargets: numTargets,
          targetDist: targetDist,
          maxOp: maxOp);
    }
  }
  
  static int getInputValue(String id) {
    return int.parse((query("#$id") as InputElement).value);
  }
  
  void onBodyClick(MouseEvent event) {
    // show miss feedback
    // first remove from DOM so that animation will start again when it is added back
    shotElement.remove();
    // set location
    // TODO magic numbers
    shotElement.style.left = "${event.clientX - 15}px";
    shotElement.style.top = "${event.clientY - 15}px";
    // add back to DOM
    document.body.elements.add(shotElement);
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
