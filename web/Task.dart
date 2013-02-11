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
  
  /// The amount of time the event lasts
  num duration;
  
  /// True iff the event is active
  bool running = false;
  
  void start() { running = true; }
  void stop([bool timeout = false]) { running = false; }
  void update(num sinceIterationStart) {
  }
  
  TaskEvent(TaskController this.delegate, num this.duration);

  Map toJson() {
    return {"duration": duration};
  }
}

class TaskEndEvent extends TaskEvent {
  TaskEndEvent(TaskController delegate)
      : super(delegate, 0);
  
  void start() {
    delegate.endTrial();
  }
}

/// [TargetEvent] is an [Event] that shows a target
abstract class TargetEvent extends TaskEvent {
  Target target;
  
  TargetEvent(TaskController delegate, num duration, bool enemy) : super(delegate, duration) {
    target = new Target(delegate, enemy);
  }
  Map toJson() {
    return merge(super.toJson(), {"target": target.toJson()});
  }
}

/// [FixedTargetEvent] is a [TargetEvent] that shows a target in a fixed position
class FixedTargetEvent extends TargetEvent {
  num x, y;
  
  FixedTargetEvent(TaskController delegate, duration, this.x, this.y, bool enemy): super(delegate, duration, enemy) {
    target.move(x, y);
  }
  
  FixedTargetEvent.atRandomPoint(TaskController delegate, duration, bool enemy) : super(delegate, duration, enemy) {
    Random rng = new Random();
    // put target at random place on screen
    target.move(rng.nextInt(document.body.clientWidth), rng.nextInt(document.body.clientHeight));
  }
  
  void start() {
    running = true;
    // show the target
    target.show();
    delegate.onTargetStart(this, new DateTime.now().millisecondsSinceEpoch);
  }
  
  void stop([bool timeout = false]) {
    super.stop();
    
    // if the target is still visible, it hasn't been dismissed, so remove and update score
    if(timeout && target.visible) {
      // remove the target
      target.timeout();
      
      delegate.onTargetTimeout(this, new DateTime.now().millisecondsSinceEpoch);
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
  
  MovingTargetEvent(TaskController delegate, num duration, bool enemy,
                    this.startX, this.startY,
                    this.endX, this.endY) : super(delegate, duration, enemy) {
    target.move(startX, startY);
    //target.resize(64,64);
  }
  
  MovingTargetEvent.eventWithLength(TaskController delegate, num duration, bool enemy, num length) 
      : super(delegate, duration, enemy) {
    
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
    delegate.onTargetStart(this, new DateTime.now().millisecondsSinceEpoch);
  }
  
  void update(num sinceIterationStart) {
    // if target has not been dismissed, move it
    if(target.visible) {
      
      // find fraction of time elapsed
      var fraction = sinceIterationStart / duration;
      
      // position target
      target.move(startX + fraction * (endX - startX), startY + fraction * (endY - startY));
      
    } else {
      // stop if target was dismissed
      stop();
    }
  }
  
  void stop([bool timeout = false]) {
    super.stop(timeout);
    // call for next frame if not done
    if(timeout && target.visible) {
      // update score for missed target
      target.timeout();
      // notify delegate of target timeout
      delegate.onTargetTimeout(this, new DateTime.now().millisecondsSinceEpoch);
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
  
  AdditionEvent(TaskController delegate, num duration, int this.op1, int this.op2)
      : super(delegate, duration) {
  }
  
  AdditionEvent.withRandomOps(TaskController delegate, num duration, int opMin, int opMax)
      : super(delegate, duration) {
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
    delegate.onAdditionStart(this, new DateTime.now().millisecondsSinceEpoch);
  }
  
  void stop([bool timeout = false]) {
    super.stop();
    delegate.onAdditionEnd(this, new DateTime.now().millisecondsSinceEpoch);
  }
}

/// [Task] represents an experimental task
abstract class Task {
  /// True iff the task is currently running
  bool running = false;
  
  // the task controller
  TaskController delegate;
  
  /// A list of task events ordered by time
  List<List<TaskEvent>> events = [];
  /// The list of tasks currently executing
  List<TaskEvent> currentEvents = [];
  
  /// the number of iterations of the task to present
  int iterations = 12;
  int iterationTime = 5000;
  
  /// The current iteration
  int iteration = 0;
  int iterationStartTime;
  bool get iterationComplete => currentEvents.isEmpty;
  
  /// True if an iteration is currently active; i.e. not complete
  // TODO we should have a better notion of iterations in this class
  // this is set to true whenever an event starts because we assume
  // all events start at the beginning of an iteration.
  // this is set to false when it is true and any remaining tasks are friendly targets
  // TODO that test should be a method on events
  //bool iterationActive = false;
  bool iterationTasksCompleted = false;
  
  /// Generate the task events
  void buildEvents();
  
  Map toJson() {
    return {"events": events, "iterations": iterations, "iterationTime": iterationTime};
  }
  
  /// The index in events that is next to process
  //int eventIndex = 0;
  
  /// Stopwatch to keep track of progress
  Stopwatch stopwatch = new Stopwatch();
  
  Task(this.delegate, {int this.iterations: 12, num this.iterationTime: 5000});
  
  void start() {
    running = true;
    
    // start the stopwatch
    stopwatch.start();
    
    // set the initial iteration start time
    iterationStartTime = 0;

    // tell delegate that task started
    delegate.onTrialStart(new DateTime.now().millisecondsSinceEpoch);
    
    // set current events
    currentEvents = events[iteration];
    
    // start new tasks
    for(TaskEvent event in currentEvents) {
      event.start();
    }
    
    // manually call first timer event
    //onTimer(timer);
    update(null);
  }
  // the method an end task event calls when it starts
  void endTask() {
    // if we haven't passed the last iteration, we have to notify the controller
    // of the end of the iteration
    // TODO I think this should never happen
    if(iteration < iterations) {
      Logger.root.info("got end task from end event, and still on $iteration; sending message");
      delegate.onIterationComplete(new DateTime.now().millisecondsSinceEpoch);
    }
    stop();
  }
  void stop() {
    //timer.cancel();
    stopwatch.stop();
    
    // tell delegate that task ended
    delegate.onTrialEnd(new DateTime.now().millisecondsSinceEpoch);
    
    running = false;
  }
  void reset() {
    stop();
    stopwatch.reset();
  }
  // true if there are events in currentEvents that are not friendly target events
  bool activeEvents() {
    // look at each current event
    for(TaskEvent event in currentEvents) {
      // check if it is a target event
      if(event is TargetEvent && event.running) {
        // if it is, and it is enemy, return true
        if(event.target.enemy) return true;
      } else if(event.running) {
        // if it is not, return true
        return true;
      }
    }
    // if nothing found, return false
    return false;
  }
  void update(time) {

    // if we are done processing all events, stop
    /*if(eventIndex >= events.length && currentEvents.length == 0) {
      Logger.root.info("stopping because we are out of events and there are not more current events");
      stop();
    }*/
    
    // get the current time since start of trial
    num currentTime = stopwatch.elapsedMilliseconds;
    
    // if time is past iteration duration, move to the next iteration
    if(currentTime - iterationStartTime > iterationTime) {
      
      // kill current tasks
      for(TaskEvent event in currentEvents) {
        // TODO make sure tasks timeout correctly if not completed
        event.stop(true);
      }
      
      // notify delegate
      delegate.onIterationComplete(new DateTime.now().millisecondsSinceEpoch);
      
      // reset tasks completed flag
      iterationTasksCompleted = false;
      
      // increment iteration
      iteration++;
      
      // update iteration startedTime
      iterationStartTime = currentTime;
      
      // update currentEvents if not done
      if(iteration < iterations) {
        currentEvents = events[iteration];
        
        // start new tasks
        for(TaskEvent event in currentEvents) {
          event.start();
        }
      } else {
        // otherwise, just stop here
        stop();
      }
      
    } else {
      // otherwise, just update the current tasks
      for(TaskEvent event in currentEvents) {
        event.update(currentTime - iterationStartTime);
      }
      
      // if the iterationTasksCompleted flag is not set, but there are no active tasks,
      // then we must have just finished them, so notify delegate
      if(!iterationTasksCompleted && !activeEvents()) {
        // notify delegate
        delegate.onCompleteTasks(new DateTime.now().millisecondsSinceEpoch, stopwatch.elapsedMilliseconds - iterationStartTime);
        // set completed
        iterationTasksCompleted = true;
      }
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
        events.add([]);
        // generate target events
        for(int j = 0; j < numTargets; j++) {
          events[i].add(buildTargetEvent(j));
        }
        // only add addition even if we have a valid range
        // TODO hide addition ui if we don't have addition events
        if(opRange != null) {
          // addition event
          events[i].add(buildAdditionEvent(i));
        }
      }
    }
  }
  
  TargetEvent buildTargetEvent(int targetNum);
  AdditionEvent buildAdditionEvent(int index) {
    return new AdditionEvent.withRandomOps(delegate, iterationTime, opRange[0], opRange[1]);
  }
}

// TODO this just adds one parameter to the constructor and a buildTargetEvent method
class ConfigurableTrialTask extends TrialTask {
  
  num targetDist;
  int targetSize = 128;
  int targetDifficulty;
  
  Map toJson() {
    return merge(super.toJson(), {"targetDist": targetDist, "targetSize": targetSize, "targetDifficulty": targetDifficulty});
  }
  
  ConfigurableTrialTask(TaskController delegate,
      { int numTargets: 1,
        num this.targetDist: 0,
        int iterations: 12,
        List<int> opRange: const [1, 15],
        int iterationTime: 5000,
        int this.targetSize: 128,
        int this.targetDifficulty: 1})
      : super(delegate, numTargets: numTargets, iterations: iterations, opRange: opRange, iterationTime: iterationTime);
  
  TargetEvent buildTargetEvent(int targetNum) {
    // make ceil(n/2) targets enemies
    bool enemy = ((targetNum % 2) == 0) ? Target.ENEMY : Target.FRIEND;
    return new MovingTargetEvent.eventWithLength(delegate, iterationTime, enemy, targetDist)..target.resize(targetSize, targetSize);
  }
  
  void start() {
    // set css based on target difficulty
    if(targetDifficulty == Block.HIGH_DIFFICULTY) {
      document.body.classes.add("high-targeting-difficulty");
    } else {
      document.body.classes.remove("high-targeting-difficulty");
    }
    // do normal start
    super.start();
  }
}

class BlockTrialTask extends ConfigurableTrialTask {
  
  // trial task constants
  static const int ITERATION_TIME_S = 5;
  static const int ITERATION_TIME_MS = 5000;
  static const int ITERATIONS = 12;
  static const int TARGET_SIZE = 128;
  
  BlockTrialTask(TaskController delegate,
      int speed, int target_number, List<int> operand_range, int target_difficulty)
      : super(delegate, numTargets: target_number, targetDist: speed * ITERATION_TIME_S, iterations: ITERATIONS, opRange: operand_range,
          iterationTime: ITERATION_TIME_MS, targetSize: TARGET_SIZE, targetDifficulty: target_difficulty);
}