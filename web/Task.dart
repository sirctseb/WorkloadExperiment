part of WorkloadExperiment;

/// [TaskEvent] is an event that occurs during a task

Map merge(Map m1, Map m2) {
  Map result = {};
  for(var key in m1.keys) {
    result.putIfAbsent(key, () => m1[key]);
  }
  for(var key in m2.keys) {
    result.putIfAbsent(key, () => m2[key]);
  }
  return result;
}

abstract class TaskEvent {
  /// The task controller
  TaskController delegate;
  
  /// The time after the beginning of the task that the event occurs
  num time;
  
  /// The amount of time the event lasts
  num duration;
  
  /// True iff the event is active
  bool running = false;
  
  void start() { running = true; }
  void stop() { running = false; }
  void update(num sinceTaskStart) {
    if(sinceTaskStart > time + duration) stop();
  }
  
  TaskEvent(TaskController this.delegate, num this.time, num this.duration);

  Map toJson() {
    return {"time": time, "duration": duration};
  }
}

/// [TargetEvent] is an [Event] that shows a target
abstract class TargetEvent extends TaskEvent {
  Target target;
  
  TargetEvent(TaskController delegate, num time, num duration) : super(delegate, time, duration) {
    target = new Target(delegate);
  }
  Map toJson() {
    return merge(super.toJson(), {"target": target.toJson()});
  }
}

/// [FixedTargetEvent] is a [TargetEvent] that shows a target in a fixed position
class FixedTargetEvent extends TargetEvent {
  num x, y;
  
  FixedTargetEvent(TaskController delegate, num time, duration, this.x, this.y): super(delegate, time, duration) {
    target.move(x, y);
  }
  
  FixedTargetEvent.atRandomPoint(TaskController delegate, num time, duration) : super(delegate, time, duration) {
    Random rng = new Random();
    // put target at random place on screen
    target.move(rng.nextInt(document.body.clientWidth), rng.nextInt(document.body.clientHeight));
  }
  
  void start() {
    running = true;
    // show the target
    target.show();
    delegate.onTargetStart(this, new Date.now().millisecondsSinceEpoch);
  }
  
  void update(num sinceTaskStart) {
    if(sinceTaskStart > time + duration) {

      // if the target is still visible, it hasn't been dismissed, so remove and update score
      if(target.visible) {
        // remove the target
        target.timeout();
        
        delegate.onTargetTimeout(this, new Date.now().millisecondsSinceEpoch);
        
        // update the score
        delegate.score -= 100;
      }
      
      stop();
    }
  }
  
  Map toJson() {
    return merge(super.toJson(), {"x": x, "y": y});
  }
}

/// [MovingTargetEvent] is a [TargetEvent] that displays a moving target
class MovingTargetEvent extends TargetEvent {
  num startX, startY;
  num endX, endY;
  
  Map toJson() {
    return merge(super.toJson(), {"startX": startX, "startY": startY, "endX": endX, "endY": endY, "duration": duration});
  }
  
  MovingTargetEvent(TaskController delegate, num time, num duration,
                    this.startX, this.startY,
                    this.endX, this.endY) : super(delegate, time, duration) {
    target.move(startX, startY);
    //target.resize(64,64);
  }
  
  MovingTargetEvent.eventWithLength(TaskController delegate, num time, num duration, num length) 
      : super(delegate, time, duration) {
        
    Random rng = new Random();
    
    // get random start point
    startX = rng.nextInt(document.body.clientWidth);
    startY = rng.nextInt(document.body.clientHeight);
    
    // compute random end point at a given distance
    // TODO we have to be careful that there is a point on the circle that lies in the rect
    Point end = new Circle(new Point(startX, startY), length).randomPointInRect(
        new Rectangle(0,0, document.body.clientWidth, document.body.clientHeight));
    
    // store in member vars
    endX = end.x;
    endY = end.y;
  }
  
  void start() {
    //window.requestAnimationFrame(update);
    running = true;
    
    // show target
    target.show();
    
    // notify delegate of target start
    delegate.onTargetStart(this, new Date.now().millisecondsSinceEpoch);
  }
  
  void update(num sinceTaskStart) {
    // if target has not been dismissed, move it
    if(target.visible) {
      
      // find fraction of time elapsed
      var fraction = (sinceTaskStart - time) / duration;
      
      // position target
      target.move(startX + fraction * (endX - startX), startY + fraction * (endY - startY));
      
      // call for next frame if not done
      if(fraction >=1 ) {
        // update score for missed target
        target.timeout();
        delegate.score -= 100;
        // notify delegate of target timeout
        delegate.onTargetTimeout(this, new Date.now().millisecondsSinceEpoch);
        stop();
      }
    } else {
      // stop if target was dismissed
      stop();
    }
  }
}

/// [AdditionEvent] is a [TaskEvent] that displays an addition problem on the screen
class AdditionEvent extends TaskEvent {
  
  int op1, op2;
  
  Map toJson() {
    return merge(super.toJson(), {"op1": op1, "op2": op2});
  }
  
  static Timer outstanding;
  
  AdditionEvent(TaskController delegate, num time, num duration, int this.op1, int this.op2)
      : super(delegate, time, duration) {
  }
  
  AdditionEvent.withRandomOps(TaskController delegate, num time, num duration, int op1max, int op2max)
      : super(delegate, time, duration) {
    // set ops randomly within max
    Random rng = new Random();
    op1 = rng.nextInt(op1max);
    op2 = rng.nextInt(op2max);
  }
  
  void start() {
    // if there is an outstanding timer, cancel it so it doesn't clear after this starts
    if(outstanding != null) {
      outstanding.cancel();
      outstanding = null;
    }
    
    // display text in addition task problem
    query("#addition").text = "$op1 + $op2";
    
    // set timeout to hide
    outstanding = new Timer(duration, (timer) {
      query("#addition").text = "";
    });
  }
}

/// [Task] represents an experimental task
class Task {
  /// True iff the task is currently running
  bool running = false;
  
  // the task controller
  TaskController delegate;
  
  /// A list of task events ordered by time
  List<TaskEvent> events = [];
  /// The list of tasks currently executing
  List<TaskEvent> currentEvents = [];
  
  Map toJson() {
    return {"events": events.mappedBy((event) => event.toJson()).toList()};
  }
  
  /// The index in events that is next to process
  int eventIndex = 0;
  
  /// The timer to control events
  // TODO should we use one global timer?
  //Timer timer;
  /// The time that the next event is scheduled for
  int get nextEventTime {
    if(eventIndex >= events.length) return -1;
    return events[eventIndex].time;
  }
  
  /// Stopwatch to keep track of progress
  Stopwatch stopwatch = new Stopwatch();
  
  Task(this.delegate);
  
  void start() {
    running = true;
    
    stopwatch.start();

    // tell delegate that task started
    delegate.onTrialStart(new Date.now().millisecondsSinceEpoch);
    
    // manually call first timer event
    //onTimer(timer);
    update(0);
  }
  void stop() {
    //timer.cancel();
    stopwatch.stop();
    
    // tell delegate that task ended
    delegate.onTrialEnd(new Date.now().millisecondsSinceEpoch);
    
    running = false;
  }
  void reset() {
    stop();
    stopwatch.reset();
  }
  void update(time) {
  //void onTimer(Timer timer) {
    // if we are done processing all events, stop
    if(eventIndex >= events.length && currentEvents.length == 0) {
      Logger.root.info("stopping because we are out of events and there are not more current events");
      stop();
    }
    
    // check for new events to add to current events
    // process events that are scheduled at or before the current time
    while(eventIndex < events.length && events[eventIndex].time <= stopwatch.elapsedMilliseconds) {
      Logger.root.info("starting event $eventIndex");
      // start the task
      events[eventIndex].start();
      // add to current events
      currentEvents.add(events[eventIndex]);
      // increment index
      eventIndex++;
    }

    // update current events
    currentEvents.forEach((ce) => ce.update(stopwatch.elapsedMilliseconds));
    
    // remove finished events
    //currentEvents.removeMatching((ce) => !ce.running);
    // TODO workaround for removeMatching not working
    var dupEvents = []..addAll(currentEvents);
    dupEvents.forEach((event) {
      if(!event.running) {
        Logger.root.info("removing event $event because it is done");
        currentEvents.removeAt(currentEvents.indexOf(event));
      }
    });
    
    if(running) {
      window.requestAnimationFrame(update);
    }
  }
}

class ExampleTask extends Task {
  
  ExampleTask(TaskController delegate) : super(delegate) {
    events.addAll([new AdditionEvent(delegate, 0, 1000, 4, 9),
                   new MovingTargetEvent(delegate, 0, 1000, 500, 200, 100, 600),
                   new AdditionEvent(delegate, 1000, 1000, 11, 6),
                   new FixedTargetEvent(delegate, 1000, 1000, 200, 300),
                   new FixedTargetEvent(delegate, 2000, 1000, 500, 200),]);
  }
}

abstract class TrialTask extends Task {
  
  //TrialTask(TaskController delegate) : super(delegate) {
  //  timerLength = iterationTime;
  //}
  
  // the number of iterations of the task to present
  int iterations = 12;
  num iterationTime = 5000;
  int maxOp = 15;
  
  // the number of targets to present
  int numTargets;
  
  Map toJson() {
    return merge(super.toJson(), {"iterations": iterations, "iterationTime": iterationTime, "maxOp": maxOp, "numTargets": numTargets});
  }
  
  TrialTask(TaskController delegate, {int this.numTargets: 1,
                                      int this.iterations: 12,
                                      int this.maxOp: 15,
                                      int this.iterationTime: 5000})
      : super(delegate) {
    
    // generate task events
    for(int i = 0; i < iterations; i++) {
      // generate target events
      for(int j = 0; j < numTargets; j++) {
        events.add(buildTargetEvent(i));
      }
      // addition event
      events.add(buildAdditionEvent(i));
    }
  }
  
  TargetEvent buildTargetEvent(int index);
  AdditionEvent buildAdditionEvent(int index) {
    return new AdditionEvent.withRandomOps(delegate, index * iterationTime, iterationTime, maxOp, maxOp);
  }
}

class SlowTrialTask extends TrialTask { 
  SlowTrialTask(TaskController delegate, [int numTargets = 1]) : super(delegate, numTargets: numTargets);
  
  final double slowDist = 400.0;
  TargetEvent buildTargetEvent(int index) {
    return new MovingTargetEvent.eventWithLength(delegate, index * iterationTime, iterationTime, slowDist);
  }
}
class TwoTargetSlowTrialTask extends SlowTrialTask {
  TwoTargetSlowTrialTask(TaskController delegate) : super(delegate, 2);
}

// TODO this just adds one parameter to the constructor and a buildTargetEvent method
class ConfigurableTrialTask extends TrialTask {
  
  num targetDist;
  int targetSize = 128;
  
  Map toJson() {
    return merge(super.toJson(), {"targetDist": targetDist, "targetSize": targetSize});
  }
  
  ConfigurableTrialTask(TaskController delegate,
      { int numTargets: 1,
        num this.targetDist: 0,
        int iterations: 12,
        int maxOp: 15,
        int iterationTime: 5000,
        int this.targetSize: 128})
      : super(delegate, numTargets: numTargets, iterations: iterations, maxOp: maxOp, iterationTime: iterationTime);
  
  TargetEvent buildTargetEvent(int index) {
    return new MovingTargetEvent.eventWithLength(delegate, index * iterationTime, iterationTime, targetDist)..target.resize(targetSize, targetSize);
  }
}

class FixedTrialTask extends TrialTask {
  
  FixedTrialTask(TaskController delegate) : super(delegate, numTargets: 1);
  
  TargetEvent buildTargetEvent(int index) {
    return new FixedTargetEvent.atRandomPoint(delegate, index * iterationTime, iterationTime);
  }
}

// TODO define constructor params in terms of actual experiment independent variables and levels
// enum TargetCount = {1, 2, 3}
// enum TargetSpeed = {fixed, slow, fast}