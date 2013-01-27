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
  String ws_url = "ws://localhost:8000/ws";
  WebSocket ws;// = new WebSocket("ws://localhost:8000/ws");
  bool get wsReady => ws != null ? ws.readyState == WebSocket.OPEN : false;
  void openWS() { ws = new WebSocket(ws_url); }
  void notifyWSStart() { ws.send("start trial: ${stringify(task)}"); }
  void notifyWSEnd() { ws.send("end trial"); }
  
  /// An element to show feedback when a click occurs
  DivElement shotElement = new DivElement()..classes.add("shot");

  // the current beep countdown
  int countdown = 2;
  // get element
  AudioElement beep = (query("#beep") as AudioElement);
  
  /// Create a task controller
  TaskController() {
    // connect to server
    openWS();
    
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
    document.body.on.mouseDown.add(onBodyDown);
    
    // add handler to body for mouse moves
    document.body.on.mouseMove.add(onBodyMove);
    
    document.body.children.add(shotElement);
    
    // add handler on button click
    document.query("#set-params").on.click.add(settingChanged);
    
    // add handler for setting subject number
    document.query("#set-subject-number").on.click.add(setSubjectNumber);
    
    // start trial at the start of the final beep
    beep.on.play.add((Event) {
      if(countdown == 0) {
        // if countdown is done, start trial
        // tell the data server we're starting
        notifyWSStart();
        task.start();
        ws.send("started task");
      }
    });
    // add end event
    beep.on.ended.add((Event) {
      // if countdown is not done, decrement and schedule another in 1 second
      if(countdown > 0) {
        countdown--;
        new Timer(1000, (Timer) {
          beep.play();
        });
      }
    });
    
    // show task on startup
    showTask();
  }
  
  void setSubjectNumber(Event event) {
    // send subject number message
    ws.send("subject ${document.query('#subject-number').value}");
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
      int targetSize = getInputValue("target-size");
      
      task = new ConfigurableTrialTask(this,
          iterations: iterations,
          iterationTime: iterationTime, 
          numTargets: numTargets,
          targetDist: targetDist,
          maxOp: maxOp,
          targetSize: targetSize);
    }
  }
  
  static int getInputValue(String id) {
    return int.parse((query("#$id") as InputElement).value);
  }
  
  void onBodyDown(MouseEvent event) {
    // ignore if on settings screen
    if(settingsRoot.style.display == "block") return;
    
    // show miss feedback
    // first remove from DOM so that animation will start again when it is added back
    shotElement.remove();
    
    // set location
    // TODO magic numbers
    shotElement.style.left = "${event.clientX - 15}px";
    shotElement.style.top = "${event.clientY - 15}px";
    
    // add back to DOM
    document.body.children.add(shotElement);
    
    logMouseDown(event, false);
  }
  void logMouseDown(MouseEvent event, bool hit) {
    // send click event to server
    if(wsReady) {
      Logger.root.finest("sending mouse down event");
      ws.send("MouseDown, ${event.timeStamp}, ${event.clientX}, ${event.clientY}, ${hit?'HIT':'MISS'}");
    }
  }
  
  void onBodyMove(MouseEvent event) {
    // set info to data server
    if(wsReady) {
      ws.send("MouseMove, ${event.timeStamp}, ${event.clientX}, ${event.clientY}");
    }
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
      // play chirps and then start
      countdown = 2;
      // play first tone
      beep.play();
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
    // log the mouse down so we also get the exact mouse location
    logMouseDown(event, true);
    
    // notify data server
    if(wsReady) {
      ws.send("TargetHit, ${event.timeStamp}, ${target.x}, ${target.y}, ${target.ID}");
    }
    
    // update score
    num dist = sqrt(pow(target.x - event.clientX, 2) + pow(target.y - event.clientY, 2));
    score += 100 - dist;
    
    // don't propagate mouse down so body won't react to it
    event.stopPropagation();
  }
  
  void onTrialStart(num time) {
    // ensure score is at zero
    score = 0;
    // send trial start to data server
    if(wsReady) {
      ws.send("TrialStart $time");
    }
  }
  void onTrialEnd(num time) {
    // send trial end to data server
    if(wsReady) {
      ws.send("FinalScore $score");
      ws.send("TrialEnd $time");
    }
    // reset addition task placeholder text
    query("#addition").text = "X + Y";
  }
  
  void onTaskStart(num time) {
    // send start to data server
    // TODO trial number?
    if(wsReady) {
      ws.send("TaskStart, $time");
    }
  }
  void onTaskEnd(num time) {
    // send end to data server
    if(wsReady) {
      ws.send("TaskEnd, $time");
    }
  }
  
  void onTargetStart(TargetEvent te, num time) {
    // send target start info to data server
    if(wsReady) {
      ws.send("TargetStart, $time, ${te.target.x}, ${te.target.y}, ${te.target.ID}");
    }
  }
  /*void onTargetMove(MovingTargetEvent te, num time) {
    // send target move info to data server
    ws.send("TargetMove, $time, ${te.target.x}, ${te.target.y}, ${te.target.ID}");
  }*/
  void onTargetTimeout(TargetEvent te, num time) {
    Logger.root.fine("sending timeout to server");
    // send target timeout info to data server
    if(wsReady) {
      ws.send("TargetTimeout, $time, ${te.target.x}, ${te.target.y}, ${te.target.ID}");
    }
  }
}
