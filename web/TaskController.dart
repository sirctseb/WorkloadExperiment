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
  num get scoreNoStyle => _score;
  // set the score without doing the green and red coloring
  set scoreNoStyle(num s) {
    // update backing field
    _score = s;
    // update html
    taskRoot.query("#score-content").text = s.toStringAsFixed(0);
  }
  
  /// Task properties
  Task task;
  
  /// Web socket to communicate with data server
  String ws_url = "ws://localhost:8000/ws";
  WebSocket ws;// = new WebSocket("ws://localhost:8000/ws");
  bool get wsReady => ws != null ? ws.readyState == WebSocket.OPEN : false;
  void openWS() {
    ws = new WebSocket(ws_url)
    // update warning on state changes
    ..onOpen.listen(WarnWS)
    ..onError.listen(WarnWS)
    ..onClose.listen(WarnWS);
  }
  void notifyWSStart() { ws.send("start trial: ${stringify(task)}"); }
  void notifyWSEnd() { ws.send("end trial"); }
  
  /// An element to show feedback when a click occurs
  DivElement shotElement = new DivElement()..classes.add("shot");

  // the current beep countdown
  int countdown = 2;
  // get element
  AudioElement beep = (query("#beep") as AudioElement);
  
  void WarnWS(Event event) {
    if(wsReady) document.body.classes.remove("ws-error");
    else document.body.classes.add("ws-error");
  }
  
  /// Create a task controller
  TaskController() {
    // connect to server
    openWS();
    
    // store task and settings root elements
    taskRoot = document.body.query("#task");
    settingsRoot = document.body.query("#settings");
    
    // register for keyboard input
    window.onKeyPress.listen(handleKeyPress);
    
    // create a task
    task = new BlockTrialTask(this,
        BlockTrialTask.LOW_SPEED,
        BlockTrialTask.LOW_TARGET_NUMBER,
        BlockTrialTask.LOW_OPERANDS);
    
    // add handler to body for missed target clicks
    document.body.onMouseDown.listen(onBodyDown);
    
    // add handler to body for mouse moves
    document.body.onMouseMove.listen(onBodyMove);
    
    document.body.children.add(shotElement);
    
    // add handler on button click
    document.query("#set-params").onClick.listen(settingChanged);
    
    // add handler to block trial button click
    document.query("#block-set-params").onClick.listen(blockTrialSet);
    
    // add handler for setting subject number
    document.query("#set-subject-number").onClick.listen(setSubjectNumber);
    
    // start trial at the start of the final beep
    beep.onPlay.listen((Event) {
      if(countdown == 0) {
        // if countdown is done, start trial
        task.start();
      }
    });
    // add end event
    beep.onEnded.listen((Event) {
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
    ws.send("subject ${(document.query('#subject-number') as InputElement).value}");
  }
  void settingChanged(Event event) {
  // if custom is enabled, create a new task
    // parse input elements
    num iterations = getInputValue("iterations");
    num iterationTime = getInputValue("iteration-time");
    num numTargets = getInputValue("num-targets");
    num targetDist = getInputValue("target-dist");
    num minOp = getInputValue("min-op");
    num maxOp = getInputValue("max-op");
    int targetSize = getInputValue("target-size");
    
    task = new ConfigurableTrialTask(this,
        iterations: iterations,
        iterationTime: iterationTime, 
        numTargets: numTargets,
        targetDist: targetDist,
        opRange: [minOp, maxOp],
        targetSize: targetSize);
  }
  void blockTrialSet(Event event) {
    task = new BlockTrialTask(this, 
        lowSetting("block-target-dist") ? BlockTrialTask.LOW_SPEED : BlockTrialTask.HIGH_SPEED,
        lowSetting("block-num-targets") ? BlockTrialTask.LOW_TARGET_NUMBER : BlockTrialTask.HIGH_TARGET_NUMBER,
        lowSetting("block-operand-range") ? BlockTrialTask.LOW_OPERANDS : BlockTrialTask.HIGH_OPERANDS);
  }
  bool lowSetting(String name) {
    return (query("[name=$name]:checked") as InputElement).value == "low";
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
      // tell task to actually generate task events
      task.buildEvents();
      
      // g for 'go', start the task
      // play chirps and then start
      countdown = 2;

      // tell the data server we're starting so it can start recording
      notifyWSStart();
      
      // play first tone
      beep.play();
    } else if(event.which == "p".charCodeAt(0)) {
      // p for 'pause', stop the task
      task.stop();
    } else if(event.which == " ".charCodeAt(0)) {
      // mark correct addition response on space bar
      
      // make sure addition is not already marked correct
      if(query(".addition").classes.contains("correct")) return;
      
      // tell task that addition is over
      task.endAdditionEvent();
      
      // log response to server
      ws.send("AdditionCorrect, ${event.timeStamp}");
      
      // color operands green?
      query(".addition").classes.add("correct");
      
      // update score
      score += 100;
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
    score += 100;
    
    // don't propagate mouse down so body won't react to it
    event.stopPropagation();
  }
  
  void onTrialStart(num time) {
    // ensure score is at zero
    score = 0;
    // send trial start to data server
    if(wsReady) {
      ws.send("TrialStart, $time");
    }
  }
  void onTrialEnd(num time) {
    // send trial end to data server
    if(wsReady) {
      ws.send("FinalScore, $score");
      ws.send("TrialEnd, $time");
      // send non-log end command
      notifyWSEnd();
    }
    // reset addition task placeholder text
    query("#addition").text = "X + Y";
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
  
  void onCompleteTasks(num time, num duration) {
    
    Logger.root.fine("all task components completed for this iteration");
    
    // increase the score by the amount of time they had left
    score += 100 * (task.iterationTime - duration) / 1000;

    // log event to server
    if(wsReady) {
      ws.send("TasksComplete, $time, $duration");
    }
  }
  
  void onAdditionStart(AdditionEvent ae, num time) {
    // reset addition correctness style
    query(".addition").classes.remove("correct");
    
    // send info to the data server
    if(wsReady) {
      ws.send("AdditionStart, $time, ${ae.op1}, ${ae.op2}");
    }
  }
  void onAdditionEnd(AdditionEvent ae, num time) {
    // send info to the data server
    if(wsReady) {
      ws.send("AdditionEnd, $time");
    }
  }
}
