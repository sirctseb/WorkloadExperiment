part of WorkloadExperiment;

/// A class to manage the replay of trials
class TrialReplay implements TargetDelegate {
  // logger for replay
  static Logger logger = new Logger("replay")..level = Level.INFO;
  
  // trial state
  /// The current time in seconds from the start of the trial. can be negative
  num get time => _time;
  num _time;
  /// The current time in seconds from the start of the iteration
  num get iterationTime => time - iterationStartTime;
  /// The current iteration
  int iteration;
  /// The targets
  List<Target> targets;
  /// The addition operands
  int op1, op2;
  
  /// The start time of the iteration in seconds since the start of the trial
  num get iterationStartTime => _iterationStartTime;
  num _iterationStartTime;
  /// The length of the trial in seconds
  num get trialLength => (trialEndStamp - trialStartStamp)/1000;
  
  /// The trial start time in unix ms
  int trialStartStamp;
  /// The trial end time in unix ms
  int trialEndStamp;
  
  /// The iteration time of the first target hit of the iteration
  num hit1Time;
  /// The iteration time of the second target hit of the iteration
  num hit2Time;
  /// The iteration time when the addition problem was completed
  num additionTime;
  
  /// The block description for this trial
  Map block;
  
  /// True if we are running real-time playback
  bool playing = false;
  /// The trial time when the playback started
  num trialTimePlaybackStart;
  /// The time passed to the animation frame request callback when the animation started
  num animationPlaybackStartTime;
  
  // access to trial controller
  TaskController _delegate;
  TaskController get delegate => _delegate;
  set delegate(TaskController del) {
    // if there is a current data subscription, cancel it
    // (this will never happen)
    if(dataSubscription != null) {
      dataSubscription.cancel();
      dataSubscription = null;
    }
    
    // set backing field
    _delegate = del;
    
    // subscribe to messages from server
    if(delegate.wsReady) {
      dataSubscription = delegate.ws.onMessage.listen(receiveData);
    }
  }
  StreamSubscription dataSubscription;
  
  // TargetDelegate implementation
  void TargetClicked(Target target, MouseEvent event) {
    // don't do anything;
  }
  
  // data
  List<Map> mouseMoves;
  List<Map> events;
  
  // load data
  void loadTrial(String path) {
    if(delegate != null && delegate.wsReady) {
      // send request for data file contents
      delegate.ws.send(stringify({"cmd": "replay", "data": "datafile", "path": path}));
    } else {
      // TODO error message
    }
  }
  void receiveData(MessageEvent event) {
    try {
      var data = parse(event.data);
      if(data.containsKey("data") && data["data"] == "datafile") {
        logger.info("got data from server, parsing");
        // read block description
        block = parse(data["block"]);
        // set targeting difficulty class
        if(block["targetDifficulty"] == 1) {
          document.body.classes.add("high-targeting-difficulty");
        } else {
          document.body.classes.remove("high-targeting-difficulty");
        }
        logger.info("block is like: $block");
        // parse data file into mouse move and event lists
        mouseMoves = TrialDataParser.parseMouseMoveData(data["content"]);
        events = TrialDataParser.parseEventData(data["content"]);
        // find trial start event to set stamp
        trialStartStamp = events.firstMatching((event) => event["event"] == "TrialStart")["time"];
        // find trial end event to set stamp
        trialEndStamp = events.lastMatching((event) => event["event"] == "TrialEnd")["time"];
        // TODO set trial times in mouse moves?
        // set time so state is set correctly
        time = 0;
        // update time views
        updateTimeViews();
      }
    } on FormatException catch(e) {
      // ignore if not valid json
    }
  }
  
  // map from target ids of the original targets to the target objects we are replaying them with
  Map<int, Target> targetIDmap = new Map<int, Target>();
  
  // the amount of time to show a miss during replay
  final num MISS_SHOW_TIME = 0.1;
  
  /// Move the replay to a given trial time
  set time(num t) {
    
    logger.fine("setting time to $t");
    
    // TODO error check input
    _time = t;
    
    // get index of last event
    int lastEventIndex = findLastEventIndex(t);
    
    // find iteration start index
    int iterationStartIndex = -1;
    for(iterationStartIndex = lastEventIndex;
        iterationStartIndex >= 0 &&
        events[iterationStartIndex]["event"] != "IterationEnd"
        && events[iterationStartIndex]["event"] != "TrialStart";
        iterationStartIndex--);
    if(iterationStartIndex < 0) {
      logger.fine("Time $t appears to be before any iteration started");
      return;
    }
    
    // set iteration start time
    _iterationStartTime = events[iterationStartIndex]["trialTime"];
    
    logger.fine("this iteration started at $_iterationStartTime");
    
    // find most recent mouse move
    var lastMove = findLastMouseMove(t);
    logger.fine("mouse at ${lastMove['x']}, ${lastMove['y']}");
    // set cursor location
    query("#replay-cursor").style..left = "${lastMove['x']}px"
                                ..top = "${lastMove['y']}px";
    num mouseX = lastMove['x'];
    num mouseY = lastMove['y'];
    if(block["targetNumber"] == 3) {
      // set target state
      // clear id map
      targetIDmap.clear();
      // find target start events
      for(int targ = 0, i = iterationStartIndex; targ < 3; i++) {
        // test if target start event
        if(events[i]["event"] == "TargetStart") {
          // TODO should also grab enemy status from this but they're not in there
          // add target to id map
          targetIDmap[events[i]["id"]] = targets[targ];
          // set target location just to store the start points
          targets[targ].move(events[i]["x"], events[i]["y"]);
          // increment target index
          targ++;
        }
      }
      int hit = 0;
      hit1Time = hit2Time = 0;
      // scan to find the ending time and location of each target
      for(int targ = 0, i = iterationStartIndex; targ < 3; i++) {
        // test if target end event (hit, friend hit, or timeout
        if(events[i]["event"] == "TargetHit" || events[i]["event"] == "FriendHit" || events[i]["event"] == "TargetTimeout") {
          // get target reference
          var currTarget = targetIDmap[events[i]["id"]];
          // compute time parameter
          num param = iterationTime / events[i]["iterationTime"];
          // if parameter is outside of [0,1], target either doesn't exist yet or it is dismissed, so hide it
          currTarget.element.style.display = (param < 0 || param > 1) ? "none" : "block";
          // interpolate position of target
          currTarget.move(currTarget.x + param * (events[i]["x"] - currTarget.x),
                          currTarget.y + param * (events[i]["y"] - currTarget.y));
          // test if target element contains mouse position and add hover class
          ClientRect tRect = currTarget.element.getBoundingClientRect(); 
          if(mouseX >= tRect.left && mouseX <= tRect.right &&
              mouseY >= tRect.top && mouseY <= tRect.bottom) {
            currTarget.element.classes.add("hover");
          } else {
            currTarget.element.classes.remove("hover");
          }
          // set enemy / friend
          currTarget.enemy = events[i]["event"] == "TargetHit" || (events[i]["event"] == "TargetTimeout" && events[i]["enemy"] == 0);
          targ++;
          
          // set hit indicator locations
          if(events[i]["event"] == "TargetHit") {
            query("#hit${hit+1}").style.left = "${100 * events[i]['iterationTime'] / 6}%";
            if(hit == 0) {
              hit1Time = events[i]['iterationTime'];
            } else {
              hit2Time = events[i]['iterationTime'];
            }
            hit++;
          }
        }
      }
      // scan for a recent miss
      bool miss = false;
      var missDiv = query("#replay-miss");
      for(int i = lastEventIndex; i >= 0 && events[i]["trialTime"] + MISS_SHOW_TIME > t; i--) {
        if(events[i]["event"] == "TargetMiss") {
          // set the miss indicator position
          missDiv.style..left = "${events[i]["x"]}px"
          ..top = "${events[i]["y"]}px"
          ..display = "block";
          miss = true;
          break;
        }
      }
      if(!miss && missDiv.style.display != "none") {
        missDiv.style.display = "none";
      }
    }
    if(block["additionDifficulty"] != null) {
      // scan for addition operand values and addition end time
      for(int i = iterationStartIndex; true; i++) {
        if(events[i]["event"] == "AdditionStart") {
          if(op1 != events[i]['op1'] || op2 != events[i]['op2']) {
            op1 = events[i]['op1'];
            op2 = events[i]['op2'];
            // set addition problem values
            query("#addition").text = "$op1 + $op2";
          }
        } else if(events[i]["event"] == "AdditionCorrect") {
          // set the position of the addition indicator
          query("#additionTime").style.left = "${100*events[i]['iterationTime'] / 6}%";
          additionTime = events[i]['iterationTime'];
          break;
        } else if(events[i]["event"] == "IterationEnd") {
          break;
        }
      }
      // scan backwards to see if addition task is complete
      bool correct = false;
      for(int i = lastEventIndex; i >= iterationStartIndex; i--) {
        // check for addition correct
        if(events[i]["event"] == "AdditionCorrect") {
          query("#addition").classes.add("correct");
          correct = true;
          break;
        }
      }
      if(!correct) {
        query("#addition").classes.remove("correct");
      }
    }
  }
  /// Move the replay a given fraction into the trial
  set timeParameter(num p) {
    logger.fine("setting time param to $p");
    time = p * (trialEndStamp - trialStartStamp) / 1000;
  }
  int findLastEventIndex(num t) {
    // TODO DRY these searches
    // do a binary search to find the closest event
    int low = 0, high = events.length - 1;
    int ind;
    while(low < high) {
      ind = low + ((high - low) / 2).ceil().toInt();
      if(events[ind]["trialTime"] == t) return ind;
      if(events[ind]["trialTime"] < t) {
        low = ind;
      } else {
        high = ind - 1;
      }
    }
    ind = low;
    return ind;
  }
  Map findLastMouseMove(num t) {
    // do a binary search to find the closest mouse move
    int low = 0, high = mouseMoves.length - 1;
    int ind;
    while(low < high) {
      ind = low + ((high - low) / 2).ceil().toInt();
      if(mouseMoves[ind]["time"] - trialStartStamp == t*1000) return mouseMoves[ind];
      if(mouseMoves[ind]["time"] - trialStartStamp < t*1000) {
        low = ind;
      } else {
        high = ind - 1;
      }
    }
    ind = low;
    return mouseMoves[ind];
  }
  /// Move the replay to a given iteration time
  set iterationTime(num t) {
    // use time setter to do real work
    time = iterationStartTime + t;
  }
  /// Move the replay to a given fraction into the iteration
  set iterationTimeParameter(num p) {
    // user iterationTime to do real work
    // TODO magic number. this assumes 6 second iterations
    iterationTime = 6 * p;
  }
  
  /// Go to the time of the nth hit of the iteration
  void goToHit(int hit) {
    // set the iteration time
    iterationTime = hit == 1 ? hit1Time : hit2Time;
    // update time view
    updateTimeViews();
  }
  
  void doPlaybackFrame(num t) {
    // compute new trial time
    num newTrialTime = trialTimePlaybackStart + (t - animationPlaybackStartTime)/1000;
    // check that it's not longer than the trial
    // TODO this should be error checked in time setter
    if(newTrialTime > this.trialLength) {
      playing = false;
      return;
    }
    // set the new trial time
    time = newTrialTime;
    // update time views
    updateTimeViews();
    // if still playing, call for another frame
    if(playing) {
      window.requestAnimationFrame(doPlaybackFrame);
      //window.animationFrame.then(doPlaybackFrame);
    }
  }
  
  // ui elements
  RangeInputElement iterationSlider = query("#iteration-time-slider");
  RangeInputElement trialSlider = query("#trial-time-slider");
  InputElement iterationTimeBox = query("#iteration-time");
  InputElement trialTimeBox = query("#trial-time");
  ButtonElement startButton = query("#replay-play");
  ButtonElement stopButton = query("#replay-stop");
  
  void updateTimeViews({updateIterationSlider: true, updateTrialSlider: true,
                        updateIterationTimeBox: true, updateTrialTimeBox: true}) {
    if(updateIterationSlider) {
      // set the position of the iteration slider
      // TODO magic number assumes 6 second iterations
      iterationSlider.value = "${SLIDER_RESOLUTION * iterationTime / 6}";
    }
    if(updateTrialSlider) {
      // set the trial slider position based on new time
      trialSlider.value = "${SLIDER_RESOLUTION * time / trialLength}";
    }
    if(updateIterationTimeBox) {
      // set the value of the iteration time text box
      iterationTimeBox.value = "$iterationTime";
    }
    if(updateTrialTimeBox) {
      // set the value of the trial time text box
      trialTimeBox.value = "$time";
    }
  }
 
  final int SLIDER_RESOLUTION = 10000;
  TrialReplay() {
    // add listener for trial time input changes
    trialTimeBox.onChange.listen((event) {
      // set time value from input
      time = double.parse(trialTimeBox.value);
      // update time views except trial time box
      updateTimeViews(updateTrialTimeBox: false);
    });
    // add listener for iteration time input changes
    iterationTimeBox.onChange.listen((event) {
      // set time value from input
      iterationTime = double.parse(iterationTimeBox.value);
      // update time views except iteration time box
      updateTimeViews(updateIterationTimeBox: false);
    });
    // set min, max on slider
    trialSlider.min = "0";
    trialSlider.max = "$SLIDER_RESOLUTION";
    trialSlider.onChange.listen((event) {
      // set time parameter from slider
      timeParameter = trialSlider.valueAsNumber / int.parse(trialSlider.max);
      // update time views except trial slider
      updateTimeViews(updateTrialSlider: false);
    });
    // set min, max on iteration slider
    iterationSlider.min = "0";
    iterationSlider.max = "$SLIDER_RESOLUTION";
    iterationSlider.onChange.listen((event) {
      // set time parameter
      iterationTimeParameter = iterationSlider.valueAsNumber / int.parse(trialSlider.max);
      // update time views except iteration slider
      updateTimeViews(updateIterationSlider: false);
    });
    // add handler for start and stop buttons
    startButton.onClick.listen((event) {
      logger.info("got start button click");
      if(playing) return;
      // set playing
      playing = true;
      // request animation frame
      window.requestAnimationFrame((t) {
        // set the start time values
        animationPlaybackStartTime = t;
        trialTimePlaybackStart = time;
        // call the actual frame handler
        doPlaybackFrame(t);
      });
    });
    stopButton.onClick.listen((event) {
      logger.info("setting playing to false");
      playing = false;
    });
    
    // add click handlers to the target hit time indicator divs
    query("#hit1").onClick.listen((event) {
      goToHit(1);
    });
    query("#hit2").onClick.listen((event) {
      goToHit(2);
    });
    
    // create targets
    targets = [new Target(this, true), new Target(this, true), new Target(this, false)];
    // add targets to replay ui
    query(".replay-ui").children.addAll(targets.map((target) => target.element));
  }
}

class TrialDataParser {
  static RegExp mouseMove = new RegExp(r"MouseMove, (\d*), (\d*), (\d*)");
  static RegExp trialStart = new RegExp(r"TrialStart, (\d*)");
  static RegExp targetStart = new RegExp(r"TargetStart, (\d*), (\d*), (\d*), (\d*)");
  static RegExp additionStart = new RegExp(r"AdditionStart, (\d*), (\d*), (\d*)");
  static RegExp additionCorrect = new RegExp(r"AdditionCorrect, (\d*)");
  static RegExp hitDown = new RegExp(r"MouseDown, (\d*), (\d*), (\d*), HIT");
  static RegExp hit = new RegExp(r"TargetHit, (\d*), ([\d\.]*), ([\d\.]*), (\d*)");
  static RegExp taskComplete = new RegExp(r"TasksComplete, (\d*), (\d*)");
  static RegExp iterationEnd = new RegExp(r"IterationEnd, (\d*)");
  static RegExp friendHit = new RegExp(r"FriendHit, (\d*), ([\d\.]*), ([\d\.]*), (\d*)");
  static RegExp targetTimeout = new RegExp(r"TargetTimeout, (\d*), ([\d\.]*), ([\d\.]*), (\d*), (friend|enemy)");
  static RegExp trialEnd = new RegExp(r"TrialEnd, (\d*)");
  static RegExp miss = new RegExp(r"MouseDown, (\d*), (\d*), (\d*), MISS");
  
  static List<Map> parseMouseMoveData(String data) {
    // parse all mouse moves and put into list
    return mouseMove.allMatches(data).map((match) => {"time": int.parse(match.group(1)),
                                                      "x": int.parse(match.group(2)),
                                                      "y": int.parse(match.group(3))}).toList();
  }

  static num trialStartTime;
  static num iterationStartTime;
  static List<Map> parseEventData(String data) {
    // take out mouse moves
    //String cleanData = data.replaceAll(mouseMove, "");
    Match match;
    List<Map> events = new List();
    // scan through lines and extract events
    for(String line in data.split("\n")) {
      // test against mouse move first to avoid going through every condition on almost all events
      if(line.startsWith("MouseMove")) {
        // do nothing
      } else if((match = trialStart.firstMatch(line)) != null) {
        events.add({"event": "TrialStart", "time": int.parse(match.group(1)), "trialTime": 0, "iterationTime": 0});
        // save trial start time
        trialStartTime = events.last["time"];
        iterationStartTime = trialStartTime;
      } else if((match = targetStart.firstMatch(line)) != null) {
        // create target start event
        var time = int.parse(match.group(1));
        events.add(parseTimes(match, {"event": "TargetStart", "x": int.parse(match.group(2)), "y": int.parse(match.group(3)), "id": int.parse(match.group(4))}));
      } else if((match = additionStart.firstMatch(line))!= null) {
        // create addition start event
        events.add(parseTimes(match, {"event": "AdditionStart", "op1": int.parse(match.group(2)), "op2": int.parse(match.group(3))}));
      } else if((match = additionCorrect.firstMatch(line)) != null) {
        // create addition correct event
        events.add(parseTimes(match,
          {"event": "AdditionCorrect"}));
      } else if((match = hit.firstMatch(line)) != null) {
        // create hit event
        events.add(parseTimes(match,
          {"event": "TargetHit",
           "x": double.parse(match.group(2)),
           "y": double.parse(match.group(3)),
           "id": int.parse(match.group(4))
          }));
      } else if((match = taskComplete.firstMatch(line)) != null) {
        // create task complete event
        events.add(parseTimes(match,
          {"event": "TasksComplete"}
        ));
      } else if((match = iterationEnd.firstMatch(line)) != null) {
        // create iteration end event
        events.add(parseTimes(match,{"event": "IterationEnd"}));
        // update iteration start time
        iterationStartTime = events.last["time"];
      } else if((match = friendHit.firstMatch(line)) != null) {
        // create friend hit event
        events.add(parseTimes(match, {"event": "FriendHit",
          "x": double.parse(match.group(2)),
          "y": double.parse(match.group(3)),
          "id": int.parse(match.group(4))
          }));
      } else if((match = targetTimeout.firstMatch(line)) != null) {
        // create target timeout event
        events.add(parseTimes(match, {"event": "TargetTimeout",
          "x": double.parse(match.group(2)),
          "y": double.parse(match.group(3)),
          "id": int.parse(match.group(4)),
          "enemy": match.group(5) == "enemy"
          }));
      } else if((match = trialEnd.firstMatch(line)) != null) {
        // create trial end event
        events.add(parseTimes(match, {"event": "TrialEnd"}));
      } else if((match = miss.firstMatch(line)) != null) {
        // create miss event
        events.add(parseTimes(match,
          {"event": "TargetMiss",
           "x": int.parse(match.group(2)),
           "y": int.parse(match.group(3))
           }));
      }
    }
    return events;
  }
  
  static Map parseTimes(Match match, Map event) {
    int time = int.parse(match.group(1));
    event["time"] = time;
    event["trialTime"] = (time - trialStartTime)/1000;
    event["iterationTime"] = (time - iterationStartTime)/1000;
    return event;
  }
}