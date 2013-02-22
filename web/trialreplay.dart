part of WorkloadExperiment;

/// A class to manage the replay of trials
class TrialReplay {
  // trial state
  /// The current time in seconds from the start of the trial. can be negative
  num get time => _time;
  num _time;
  /// The current time in seconds from the start of the iteration
  num get iterationTime;
  /// The current iteration
  int iteration;
  /// The targets
  List<Target> targets;
  /// The addition operands
  int op1, op2;
  
  /// The trial start time in unix ms
  int trialStartStamp;
  
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
        // TODO parse data file into mouse move and event lists
        mouseMoves = TrialDataParser.parseMouseMoveData(data["content"]);
        events = TrialDataParser.parseEventData(data["content"]);
      }
    } on FormatException catch(e) {
      // ignore if not valid json
    }
  }
  
  /// Move the replay to a given trial time
  set time(num t) {
    Logger.root.info("setting time to $t");
  }
  /// Move the replay to a given iteration time
  set iterationTime(num t);
  
  // ui elements
  InputElement iterationSlider = query("#iteration-time-slider");
  InputElement trialSlider = query("#trial-time-slider");
  InputElement iterationTimeBox = query("#iteration-time");
  InputElement trialTimeBox = query("#trial-time");
 
  TrialReplay() {
    // add listener for trial time input changes
    trialTimeBox.onChange.listen((event) {
      // set time value from input
      time = double.parse(trialTimeBox.value);
    });
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
  static RegExp targetTimeout = new RegExp(r"TargetTimeout, (\d*), ([\d\.]*), ([\d\.]*), (\d)(, friend)?");
  
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
        events.add({"event": "TargetStart", "time": time, "trialTime": time - trialStartTime, "iterationTime": time - iterationStartTime,
                    "x": int.parse(match.group(2)), "y": int.parse(match.group(3)), "id": int.parse(match.group(4))});
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
          "id": int.parse(match.group(4))
          }));
      }
    }
    return events;
  }
  
  static Map parseTimes(Match match, Map event) {
    int time = int.parse(match.group(1));
    event["time"] = time;
    event["trialTime"] = time - trialStartTime;
    event["iterationTime"] = time - iterationStartTime;
    return event;
  }
}