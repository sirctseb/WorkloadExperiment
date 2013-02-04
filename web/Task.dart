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
    
    // check that movement length is possible
    if(length*length > (document.body.clientWidth*document.body.clientWidth +
                        document.body.clientHeight*document.body.clientHeight)) {
      throw new Exception("Target movement length too long for window");
    }
    
    Random rng = new Random();
    
    // get circles with radius == length to use for making sure target locations are good
    var c1 = new Circle(new Point(0, 0), length);
    var c2 = new Circle(new Point(0, document.body.clientHeight), length);
    var c3 = new Circle(new Point(document.body.clientWidth, 0), length);
    var c4 = new Circle(new Point(document.body.clientWidth, document.body.clientHeight), length);
    
    // make function that determines if a point has no other points within the screen at the given distance
    var ineligiblePoint = (x, y) {
      var point = new Point(x,y);
      return c1.contains(point) && c2.contains(point) && c3.contains(point) && c4.contains(point);
    };
    
    // get random start point
    startX = rng.nextInt(document.body.clientWidth);
    startY = rng.nextInt(document.body.clientHeight);
    
    // discard starting points that have no other points within the rect a the given distance
    while(ineligiblePoint(startX, startY)) {
      startX = rng.nextInt(document.body.clientWidth);
      startY = rng.nextInt(document.body.clientHeight);
    }
    
    // compute random end point at a given distance
    Point end = new Circle(new Point(startX, startY), length).randomPointInRect(
        new Rectangle(0,0, document.body.clientWidth, document.body.clientHeight));
    
    target.move(startX, startY);
    
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
  
  AdditionEvent(TaskController delegate, num time, num duration, int this.op1, int this.op2)
      : super(delegate, time, duration) {
  }
  
  AdditionEvent.withRandomOps(TaskController delegate, num time, num duration, int opMin, int opMax)
      : super(delegate, time, duration) {
    // set ops randomly within max
    Random rng = new Random();
    int range = opMax - opMin;
    op1 = rng.nextInt(range) + opMin;
    op2 = rng.nextInt(range) + opMin;
  }
  
  void start() {
    // display text in addition task problem
    query("#addition").text = "$op1 + $op2";
    
    running = true;
    
    // notify delegate
    delegate.onAdditionStart(this, new Date.now().millisecondsSinceEpoch);
  }
  
  void stop() {
    super.stop();
    delegate.onAdditionEnd(this, new Date.now().millisecondsSinceEpoch);
  }
}

/// [Task] represents an experimental task
abstract class Task {
  /// True iff the task is currently running
  bool running = false;
  
  // the task controller
  TaskController delegate;
  
  /// A list of task events ordered by time
  List<TaskEvent> events = [];
  /// The list of tasks currently executing
  List<TaskEvent> currentEvents = [];
  
  /// the number of iterations of the task to present
  int iterations = 12;
  num iterationTime = 5000;
  
  /// The current iteration
  int get iteration => stopwatch.elapsedMilliseconds ~/ iterationTime;
  int get iterationStartTime => iteration * iterationTime;
  bool get iterationComplete => currentEvents.isEmpty;
  
  /// Generate the task events
  void buildEvents();
  
  Map toJson() {
    return {"events": events.mappedBy((event) => event.toJson()).toList(), "iterations": iterations, "iterationTime": iterationTime};
  }
  
  /// The index in events that is next to process
  int eventIndex = 0;
  
  /// Stopwatch to keep track of progress
  Stopwatch stopwatch = new Stopwatch();
  
  Task(this.delegate, {int this.iterations: 12, num this.iterationTime: 5000});
  
  void start() {
    running = true;
    
    stopwatch.start();

    // tell delegate that task started
    delegate.onTrialStart(new Date.now().millisecondsSinceEpoch);
    
    // manually call first timer event
    //onTimer(timer);
    update(null);
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
  num lastTime;
  void update(time) {
    
    // if we are done processing all events, stop
    if(eventIndex >= events.length && currentEvents.length == 0) {
      Logger.root.info("stopping because we are out of events and there are not more current events");
      stop();
    }
    
    // save the number of current events so we can check if we finish the last one
    int numCurrent = currentEvents.length;
    
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
    
    // if there were some current events before cleaning them,
    // and there are none now, then we just finished them all
    if(numCurrent > 0 && currentEvents.length == 0) {
      delegate.onCompleteTasks(new Date.now().millisecondsSinceEpoch, stopwatch.elapsedMilliseconds - iterationStartTime);
    }
    
    // notify controller if task is not complete yet
    if(lastTime != null && !iterationComplete) {
      delegate.onTaskStillGoing(time - lastTime);
    }
    lastTime = time;
    
    // update current events
    currentEvents.forEach((ce) => ce.update(stopwatch.elapsedMilliseconds));
    
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
    
    if(running) {
      window.requestAnimationFrame(update);
    }
  }
  
  /// End the current addition task
  void endAdditionEvent() {
    // search current events
    for(TaskEvent event in currentEvents) {
      // look for addition event
      if(event is AdditionEvent) {
        // stop event
        event.stop();
      }
    }
  }
}

abstract class TrialTask extends Task {
  List<int> opRange = [1,15];
  
  // the number of targets to present
  int numTargets;
  
  Map toJson() {
    return merge(super.toJson(), {"iterations": iterations, "iterationTime": iterationTime, "opRange": opRange, "numTargets": numTargets});
  }
  
  TrialTask(TaskController delegate, {int this.numTargets: 1,
                                      int iterations: 12,
                                      List<int> this.opRange: const [1, 15],
                                      int iterationTime: 5000})
      : super(delegate, iterations: iterations, iterationTime: iterationTime) {
  }
  
  void buildEvents() {
    // generate the task events if they don't exist yet
    if(events.length == 0) {
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
  }
  
  TargetEvent buildTargetEvent(int index);
  AdditionEvent buildAdditionEvent(int index) {
    return new AdditionEvent.withRandomOps(delegate, index * iterationTime, iterationTime, opRange[0], opRange[1]);
  }
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
        List<int> opRange: const [1, 15],
        int iterationTime: 5000,
        int this.targetSize: 128})
      : super(delegate, numTargets: numTargets, iterations: iterations, opRange: opRange, iterationTime: iterationTime);
  
  TargetEvent buildTargetEvent(int index) {
    return new MovingTargetEvent.eventWithLength(delegate, index * iterationTime, iterationTime, targetDist)..target.resize(targetSize, targetSize);
  }
}

class BlockTrialTask extends ConfigurableTrialTask {
  // The levels of the target speed independent variable in pixels per second
  static const int LOW_SPEED = 80;
  static const int HIGH_SPEED = 160;
  // The levels of the target count indpendent variable
  static const int LOW_TARGET_NUMBER = 2;
  static const int HIGH_TARGET_NUMBER = 3;
  // The levels of the addition operand ranges
  static const List<int> LOW_OPERANDS = const [1,15];
  static const List<int> HIGH_OPERANDS = const [11,25];
  
  // trial task constants
  static const int ITERATION_TIME_S = 5;
  static const int ITERATION_TIME_MS = 5000;
  static const int ITERATIONS = 12;
  static const int TARGET_SIZE = 128;
  
  BlockTrialTask(TaskController delegate,
      int speed, int target_number, List<int> operand_range)
      : super(delegate, numTargets: target_number, targetDist: speed * ITERATION_TIME_S, iterations: ITERATIONS, opRange: operand_range,
          iterationTime: ITERATION_TIME_MS, targetSize: TARGET_SIZE);
}