part of WorkloadExperiment;

/// [TaskController] oversees the presentation of the whole task
class TaskController implements TargetDelegate {
  
  /// The root view of the actual task
  DivElement taskRoot;
  
  /// The root view of the settings screen
  DivElement settingsRoot;
  
  /// The root view of the survey screen
  DivElement surveyRoot;
  
  /// The root view of the weights screen
  DivElement weightsRoot;
  
  /// The weights manager
  TlxWeights weights;
  
  /// The block manager
  BlockManager blockManager;
  
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
    if(wsReady) {
      Logger.root.info("ws ready");
      document.body.classes.remove("ws-error");
    } else {
      Logger.root.info("error: ws not ready");
      document.body.classes.add("ws-error");
    }
  }

  /// True iff we are using blocks from Block
  bool useBlockManager = false;
  /// The number of trial if not using a block manager
  int trial = 0;
  
  /// Create a task controller
  TaskController() {
    // connect to server
    openWS();
    
    // store task and settings root elements
    taskRoot = document.body.query("#task");
    settingsRoot = document.body.query("#settings");
    surveyRoot = document.body.query("#nasa-tlx");
    weightsRoot = document.query("#weights");
    
    // make weights manager
    weights = new TlxWeights(this);
    
    // make block manager
    blockManager = new BlockManager();
    
    // register for keyboard input
    window.onKeyPress.listen(handleKeyPress);
    
    // create a task
    task = new BlockTrialTask(this,
        BlockTrialTask.LOW_SPEED,
        BlockTrialTask.LOW_TARGET_NUMBER,
        BlockTrialTask.LOW_OPERANDS);
    
    // add handler to body for missed target clicks
    document.query(".task").onMouseDown.listen(onBodyDown);
    
    // add handler to body for mouse moves
    document.body.onMouseMove.listen(onBodyMove);
    
    document.body.children.add(shotElement);
    
    // add handler on button click
    document.query("#set-params").onClick.listen(settingChanged);
    
    // add handler to block trial button click
    document.query("#block-set-params").onClick.listen(blockTrialSet);
    
    // add handler to start all blocks
    document.query("#all-blocks").onClick.listen((event) {
      Logger.root.fine("starting block sequence");
      // flag to use blocks
      useBlockManager = true;
      // get first task
      task = blockManager.getTask(this);
    });
    
    // add handler to survey submission
    query("#tlx-submit").onClick.listen((event) {
      // get response values
      var responses = {
        "mental": getInputValue("mental-demand"),
        "physical": getInputValue("physical-demand"),
        "temporal": getInputValue("temporal-demand"),
        "performance": getInputValue("performance"),
        "effort": getInputValue("effort"),
        "frustration": getInputValue("frustration")
      };
      
      // send values to data server
      if(wsReady) {
        ws.send("survey: ${stringify(responses)}");
      }
      
      // reset slider states
      for(InputElement slider in surveyRoot.queryAll("input")) {
        slider.value = "0";
      }
      
      // go to task view
      showTask();
    });
    
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
    ws.send("set: ${stringify({'subject': int.parse((document.query('#subject-number') as InputElement).value)})}");
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
    useBlockManager = false;
  }
  void blockTrialSet(Event event) {
    task = new BlockTrialTask(this, 
        lowSetting("block-target-dist") ? BlockTrialTask.LOW_SPEED : BlockTrialTask.HIGH_SPEED,
        lowSetting("block-num-targets") ? BlockTrialTask.LOW_TARGET_NUMBER : BlockTrialTask.HIGH_TARGET_NUMBER,
        lowSetting("block-operand-range") ? BlockTrialTask.LOW_OPERANDS : BlockTrialTask.HIGH_OPERANDS);
    
    useBlockManager = false;
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
    if(!hit) {
      score -= 20;
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
      
      // send trial number to server
      if(wsReady) {
        ws.send("set: ${stringify({'trial': useBlockManager ? blockManager.trialNumber : trial})}");
      }
      // if we're doing block sequence and we're on a new block, send block description
      if(useBlockManager) {
        if(wsReady) {
          if(blockManager.trialNumber == 0) {
            Logger.root.info("sending block info");
            ws.send("set: ${stringify({'block': blockManager.block, 'blockDesc': blockManager.blockDesc})}");
            Logger.root.info("sent block info");
          }
        }
      }

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
    } else if(event.which == "n".charCodeAt(0)) {
      // n for nasa-tlx
      
      // show the survey root
      showSurvey();
      
      // TODO on button click, record responses
    } else if(event.which == "w".charCodeAt(0)) {
      // w for weights
      
      // show the weights root
      showWeights();
    }
  }
  
  void showSettings() {
    // hide weights root
    weightsRoot.style.display = "none";
    
    // hide task root
    taskRoot.style.display = "none";
    
    // hide survey root
    surveyRoot.style.display = "none";
    
    // show settings root
    settingsRoot.style.display = "block";
  }
  
  void showTask() {
    // hide weights root
    weightsRoot.style.display = "none";
    
    // hide settings root
    settingsRoot.style.display = "none";
    
    // hide survey root
    surveyRoot.style.display = "none";
    
    // show task root
    taskRoot.style.display = "block";
  }
  
  void showSurvey() {
    // hide weights root
    weightsRoot.style.display = "none";
    
    // hide settings root
    settingsRoot.style.display = "none";
    
    // hide task root
    taskRoot.style.display = "none";
    
    // show survey root
    surveyRoot.style.display = "block";
  }
  
  void showWeights() {
    // hide settings root
    settingsRoot.style.display = "none";
    
    // hide task root
    taskRoot.style.display = "none";
    
    // hide survey root
    surveyRoot.style.display = "none";
    
    // show weights root
    weightsRoot.style.display = "block";
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
  
  void weightsCollected(List<Scale> scales) {
    // send weights to data server
    if(wsReady) {
      Map counts = {};
      for(var scale in scales) {
        counts[scale.title] = scale.count;
      }
      ws.send("weights: ${stringify(counts)}");
    }
    
    // reset weights
    weights.reset();
    
    // show task view
    showTask();
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
    
    // if we are using all blocks, increment trial / block and create new task
    if(useBlockManager) {
      Logger.root.fine("trial over, incrementing trial");
      
      // tell manager to advance trial
      if(blockManager.advance()) {
        // if block advanced, show workload survey
        showSurvey();
      }
      if(!blockManager.finished) {
        task = blockManager.getTask(this);
        Logger.root.fine("got new task: $task from manager");
      } else {
        // TODO show message that we are finished?
        // show settings
        showSettings();
      }
    } else {
      // otherwise, just increment the trial number
      trial++;
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
  
  /// The time it took to complete the tasks in the iteration
  int executionDuration;
  void onCompleteTasks(num time, num duration) {
    
    Logger.root.fine("all task components completed for this iteration");
    
    // save the duration
    executionDuration = duration;

    // log event to server
    if(wsReady) {
      ws.send("TasksComplete, $time, $duration");
    }
  }
  
  void onIterationComplete(num time) {
    // log iteration end to server
    if(wsReady) {
      ws.send("IterationEnd, $time");
    }
    
    // update score based on how much time they took
    if(executionDuration != null) {
      score += 100 * (task.iterationTime - executionDuration) / 1000;
    }
    
    // reset duration
    executionDuration = null;
    
    // reset addition correctness style
    query(".addition").classes.remove("correct");
  }
  
  void onAdditionStart(AdditionEvent ae, num time) {
    
    // send info to the data server
    if(wsReady) {
      ws.send("AdditionStart, $time, ${ae.op1}, ${ae.op2}");
    }
  }
  
  // called by the end task even when it starts
  void endTrial() {
    task.endTask();
  }
  
  void onAdditionEnd(AdditionEvent ae, num time) {
    // send info to the data server
    if(wsReady) {
      ws.send("AdditionEnd, $time");
    }
  }
}
