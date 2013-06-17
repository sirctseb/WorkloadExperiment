part of WorkloadExperiment;

/// [TaskController] oversees the presentation of the whole task
class TaskController implements TaskEventDelegate {
  
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
  
  /// The trial replay manager
  TrialReplay trialReplay;
  
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
    new Timer(const Duration(milliseconds:400), () {
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
  
  /// True if we are showing answers
  bool cheat = false;
  
  /// Web socket to communicate with data server
  String ws_url = "ws://localhost:8000/";
  WebSocket ws;
  bool get wsReady => ws != null ? ws.readyState == WebSocket.OPEN : false;
  void openWS() {
    // TODO this may change soon
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
  
  void receiveWS(MessageEvent event) {
    Logger.root.info("got message from server");
    // if showing answers, check for answer update
    if(cheat) {
      Logger.root.info("we are cheat client");
      // parse data
      Map response = parse(event.data);
      Logger.root.info("parsed data: $response");
      // make sure it is the addition answer
      if(response.containsKey("addition")) {
        Logger.root.info("data is addition value");
        // display the answer
        query("#addition").text = "= ${response['addition']}";
      }
    }
  }
  void WarnWS(Event event) {
    if(wsReady) {
      Logger.root.info("ws ready");
      document.body.classes.remove("ws-error");
      // set up trial replay
      // TODO seems like this should go somewhere better
      trialReplay.delegate = this;
    } else {
      Logger.root.info("error: ws not ready");
      document.body.classes.add("ws-error");
    }
  }

  /// True iff we are using blocks from Block
  bool useBlockManager = false;
  /// The number of trial if not using a block manager
  int trial = 0;
  /// The block number if not using a block manager
  int blockNumber = 0;
  /// The block created when setting block parameters in UI
  Block block;
  
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
    
    // make trial replay
    trialReplay = new TrialReplay();
    
    // register for keyboard input
    window.onKeyPress.listen(handleKeyPress);
    
    // create a task
    task = new BlockTrialTask(this,
        Block.LOW_SPEED,
        Block.LOW_TARGET_NUMBER,
        Block.LOW_OPERANDS,
        Block.HIGH_DIFFICULTY);
    
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
      // set up ui for first task
      task.setupUI();
      // log task info
      logTaskInfo();
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
      
      // if using block manager and blocks are done, show weights
      if(useBlockManager && blockManager.finished) {
        showWeights();
      } else {
        // go to task view
        showTask();
      }
    });
    
    // add handler for setting subject number
    document.query("#set-subject-number").onClick.listen(setSubjectNumber);
    
    // add handler to button to start trial
    query(".start-button").onClick.listen((event) {
      startTrial();
    });
    
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
        new Timer(const Duration(milliseconds: 1000), () {
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
        numTargets: numTargets,
        opRange: [minOp, maxOp],
        targetSize: targetSize);
    useBlockManager = false;
  }
  void blockTrialSet(Event event) {
    
    // increment block number
    blockNumber++;
    
    // set trial to 0
    trial = 0;
    
    // create block
    block = new Block.flags(lowSetting("block-num-targets"),
        lowSetting("block-target-dist"),
        lowSetting("block-operand-range"),
        lowSetting("block-target-difficulty"));
    
    // notify server of block number and description
    if(wsReady) {
      ws.send("set: ${stringify({'block': blockNumber, 'blockDesc': block})}");
    }
    
    // create a task in the block
    setTaskByBlockSettings();
  }
  void setTaskByBlockSettings() {
    task = block.createTask(this);
    
    task.setupUI();
    
    useBlockManager = false;
  }
  bool lowSetting(String name) {
    // get element that is checked
    var el = query("[name=$name]:checked") as InputElement;
    // if neither is checked, return null
    if(el == null) return null;
    // return true if value is low
    return el.value == "low";
  }
  
  static int getInputValue(String id) {
    return int.parse((query("#$id") as InputElement).value);
  }
  
  void onBodyDown(MouseEvent event) {
    // ignore if on settings screen
    if(settingsRoot.style.display == "block") return;
    // ignore if task is not active
    if(!query(".task").classes.contains("active")) return;
    
    // show miss feedback
    // first remove from DOM so that animation will start again when it is added back
    shotElement.remove();
    
    // set location
    // TODO magic numbers
    shotElement.style.left = "${event.client.x - 15}px";
    shotElement.style.top = "${event.client.y - 15}px";
    
    // add back to DOM
    document.body.children.add(shotElement);
    
    logMouseDown(event, false);
  }
  void logMouseDown(MouseEvent event, bool hit) {
    // send click event to server
    if(wsReady) {
      Logger.root.finest("sending mouse down event");
      ws.send("MouseDown, ${event.timeStamp}, ${event.client.x}, ${event.client.y}, ${hit?'HIT':'MISS'}");
    }
    if(!hit) {
      score -= 20;
    }
  }
  
  void onBodyMove(MouseEvent event) {
    // set info to data server
    if(wsReady) {
      ws.send("MouseMove, ${event.timeStamp}, ${event.client.x}, ${event.client.y}");
    }
  }
  void handleKeyPress(KeyboardEvent event) {
    // receive keyboard input
    if(event.which == "s".codeUnitAt(0)) {
      // show settings screen
      showSettings();
    } else if(event.which == "t".codeUnitAt(0)) {
      // show task screen
      showTask();
    } else if(event.which == "g".codeUnitAt(0)) {
      startTrial();
    } else if(event.which == "p".codeUnitAt(0)) {
      // p for 'pause', stop the task
      task.stop();
    } else if(event.which == " ".codeUnitAt(0)) {
      // bail if not running
      if(task != null && !task.running) return;
      // mark correct addition response on space bar

      // make sure we're not in the first half second of a task
      if(task.firstHalfSecondOfAddition) return;

      // log response to server
      ws.send("AdditionCorrect, ${event.timeStamp}");
      
      // tell task that addition is over
      task.endAdditionEvent();
      
      // update score
      score += 100;
    } else if(event.which == "n".codeUnitAt(0)) {
      // n for nasa-tlx
      
      // show the survey root
      showSurvey();
      
      // TODO on button click, record responses
    } else if(event.which == "w".codeUnitAt(0)) {
      // w for weights
      
      // show the weights root
      showWeights();
    } else if(event.which == "r".codeUnitAt(0)) {
      // r for replay
      
      // load an arbitrary trial for replay
      //trialReplay.loadTrial("output/subject8/block1/trial0");
      // show replay ui
      query(".task").classes.add("replay");
      // initiate
      trialReplay.init();
    } else if(event.which == "k".codeUnitAt(0)) {
      // k for skip
      
      // move to the next trial
      advanceBlockManagerTrial();
    } else if(event.which == "x".codeUnitAt(0)) {
      // x for playground
      // start a playground
      Playground playground = new Playground();
      print('started playground');
    } else if(event.which == "c".codeUnitAt(0)) {
      // c for cheat
      // set up stream for addition answers and show on screen
      var url = "ws://${query('input#ip').value}:8000/";
      Logger.root.info("attempting to connect to websocket at $url");
      ws = new WebSocket(url)
        ..onMessage.listen(receiveWS)
        ..onOpen.listen((event) {
          cheat = true;
          Logger.root.info("requesting cheat values from server");
          ws.send(stringify({"request": "cheat"}));
        });
    }
  }
  
  void startTrial() {
    // add the active class to the trial
    query(".task").classes.add("active");
    
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
          ws.send("set: ${stringify({'block': blockManager.blockNumber, 'blockDesc': blockManager.block})}");
          Logger.root.info("sent block info");
        }
      }
    }

    // tell the data server we're starting so it can start recording
    notifyWSStart();
    
    // play first tone
    beep.play();
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
    // dismiss the target
    target.dismiss();
    
    // log the mouse down so we also get the exact mouse location
    logMouseDown(event, true);
    
    // notify data server
    if(wsReady) {
      if(target.enemy) {
        ws.send("TargetHit, ${event.timeStamp}, ${target.x}, ${target.y}, ${target.ID}");
      } else {
        ws.send("FriendHit, ${event.timeStamp}, ${target.x}, ${target.y}, ${target.ID}");
      }
    }
    
    // notify the task
    task.targetClicked();
    
    // update score
    if(target.enemy) {
      score += 100;
    } else {
      score -= 100;
    }
    
    // don't propagate mouse down so body won't react to it
    event.stopPropagation();
  }
  void TargetOver(Target target, MouseEvent event) {
    // log hover
    if(wsReady) {
      ws.send("TargetOver, ${event.timeStamp}, ${event.client.x}, ${event.client.y}, ${target.ID}, ${target.enemy ? 'enemy' : 'friend'}");
    }
  }
  void TargetOut(Target target, MouseEvent event) {
    // log unhover
    if(wsReady) {
      ws.send("TargetOut, ${event.timeStamp}, ${event.client.x}, ${event.client.y}, ${target.ID}, ${target.enemy ? 'enemy' : 'friend'}");
    }
  }
  
  void weightsCollected(Iterable<Scale> scales) {
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
  
  /// log the task info for the current task
  void logTaskInfo() {
    Logger.root.info("Current task info:");
    BlockTrialTask btt = task as BlockTrialTask;
    Logger.root.info("oprange: ${btt.opRange}, diff: ${btt.targetDifficulty}, targets: ${btt.numTargets}");
  }
  /// advance the trial in the block manager.
  /// if we finished a block condition and it's not practice, show the survey
  /// get the new task, set up the ui, and log the task info
  void advanceBlockManagerTrial() {
    Logger.root.fine("trial over, incrementing trial");
    
    bool practice = blockManager.block.practice;
    // tell manager to advance trial
    if(blockManager.advance() && !practice) {
      // if block advanced and it wasn't a practice trial, show workload survey
      showSurvey();
    }
    if(!blockManager.finished) {
      task = blockManager.getTask(this);
      
      // set up the interface based on the new task
      task.setupUI();
      
      logTaskInfo();
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
      advanceBlockManagerTrial();
    } else {
      // otherwise, increment the trial number
      trial++;
      // get a new task according to the block settings
      // TODO this assumes we did block settings and not all settings
      setTaskByBlockSettings();
    }
    
    // remove active class from trial display
    query(".task").classes.remove("active");
  }
  
  void onTargetStart(TargetEvent te, num time) {
    // send target start info to data server
    if(wsReady) {
      ws.send("TargetStart, $time, ${te.target.x.toInt()}, ${te.target.y.toInt()}, ${te.target.ID}");
    }
  }
  void onTargetTimeout(TargetEvent te, num time) {
    Logger.root.fine("sending timeout to server");
    // send target timeout info to data server
    if(wsReady) {
      ws.send("TargetTimeout, $time, ${te.target.x}, ${te.target.y}, ${te.target.ID}, ${te.target.enemy ? 'enemy' : 'friend'}");
    }
  }
  void onTargetComplete(num time) {
    Logger.root.fine("got target complete event, sending to server");
    // send target complet info to data server
    if(wsReady) {
      ws.send("TargetComplete, $time");
    }
  }
  
  void onAdditionStart(AdditionEvent ae, num time) {
    
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
