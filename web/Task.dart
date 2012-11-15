part of WorkloadExperiment;

/// [TaskEvent] is an event that occurs during a task

abstract class TaskEvent {
  /// The task controller
  TaskController delegate;
  
  /// The time after the beginning of the task that the event occurs
  num time;
  
  void execute();
  
  TaskEvent(TaskController this.delegate, num this.time);
}

/// [TargetEvent] is an [Event] that shows a target
class TargetEvent extends TaskEvent {
  Target target;
  
  TargetEvent(TaskController delegate, num time) : super(delegate, time) {
    target = new Target(delegate);
  }
}

/// [FixedTargetEvent] is a [TargetEvent] that shows a target in a fixed position
class FixedTargetEvent extends TargetEvent {
  num x, y;
  num timeOut;
  
  FixedTargetEvent(TaskController delegate, num time, this.x, this.y, [this.timeOut = 1000]): super(delegate, time) {
    target.move(x, y);
  }
  
  FixedTargetEvent.atRandomPoint(TaskController delegate, num time, [this.timeOut = 1000]) : super(delegate, time) {
    Random rng = new Random();
    // put target at random place on screen
    target.move(rng.nextInt(document.body.clientWidth), rng.nextInt(document.body.clientHeight));
  }
  
  void execute() {
    // show the target
    target.show();
    
    new Timer(timeOut, (timer) {
      // if the target is still visible, it hasn't been dismissed, so remove and update score
      if(target.visible) {
        // remove the target
        target.remove();
        
        // update the score
        delegate.score -= 100;
      }
    });
  }
}

/// [MovingTargetEvent] is a [TargetEvent] that displays a moving target
class MovingTargetEvent extends TargetEvent {
  num startX, startY;
  num endX, endY;
  num duration;
  
  MovingTargetEvent(TaskController delegate, num time,
                    this.startX, this.startY,
                    this.endX, this.endY,
                    [this.duration = 1000]) : super(delegate, time) {
    target.move(startX, startY);
    //target.resize(64,64);
  }
  
  MovingTargetEvent.eventWithLength(TaskController delegate, num time, num length, num this.duration) 
      : super(delegate, time) {
        
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
  
  void execute() {
    window.requestAnimationFrame(update);
  }
  
  bool running = false;
  num startTime;
  
  void update(num time) {
    
    // check for first run and store start time
    if(!running) {
      running = true;
      startTime = time;
      // show target
      target.show();
    }
    // if target has been dismissed, don't do anything
    if(target.visible) {
      // find fraction of time elapsed
      var fraction = (time - startTime) / duration;
      
      // position target
      target.move(startX + fraction * (endX - startX), startY + fraction * (endY - startY));
      
      // call for next frame if not done
      if(fraction < 1) {
        window.requestAnimationFrame(update);
      } else {
        // update score for missed target
        target.remove();
        delegate.score -= 100;
      }
    }
  }
}

/// [AdditionEvent] is a [TaskEvent] that displays an addition problem on the screen
class AdditionEvent extends TaskEvent {
  
  int op1, op2;
  num duration;
  
  static Timer outstanding;
  
  AdditionEvent(TaskController delegate, num time, int this.op1, int this.op2, num this.duration)
      : super(delegate, time) {
  }
  
  AdditionEvent.withRandomOps(TaskController delegate, num time, int op1max, int op2max, num this.duration)
      : super(delegate, time) {
    // set ops randomly within max
    Random rng = new Random();
    op1 = rng.nextInt(op1max);
    op2 = rng.nextInt(op2max);
  }
  
  void execute() {
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
  
  // the task controller
  TaskController delegate;
  
  /// A list of task events ordered by time
  List<TaskEvent> events = [];
  
  /// The index in events that is next to process
  int eventIndex = 0;
  
  /// The timer to control events
  // TODO should we use one global timer?
  Timer timer;
  // how often the timer should fire
  num timerLength = 100;
  
  /// Stopwatch to keep track of progress
  Stopwatch stopwatch = new Stopwatch();
  
  Task(this.delegate);
  
  void start() {
    timer = new Timer.repeating(timerLength, onTimer);
    stopwatch.start();
    // manually call first timer event
    onTimer(timer);
  }
  void stop() {
    timer.cancel();
    stopwatch.stop();
  }
  void reset() {
    stop();
    stopwatch.reset();
  }
  void onTimer(Timer timer) {
    // if we are done processing all events, stop
    if(eventIndex >= events.length) {
      stop();
    }
    
    // process events that are scheduled at or before the current time
    while(eventIndex < events.length && events[eventIndex].time <= stopwatch.elapsedMilliseconds) {
      events[eventIndex].execute();
      eventIndex++;
    }
  }
}

class ExampleTask extends Task {
  
  ExampleTask(TaskController delegate) : super(delegate) {
    events.addAll([new AdditionEvent(delegate, 0, 4, 9, 1000),
                   new MovingTargetEvent(delegate, 0, 500, 200, 100, 600, 1000),
                   new AdditionEvent(delegate, 1000, 11, 6, 1000),
                   new FixedTargetEvent(delegate, 1000, 200, 300),
                   new FixedTargetEvent(delegate, 2000, 500, 200),]);
  }
}

abstract class TrialTask extends Task {
  
  TrialTask(TaskController delegate) : super(delegate) {
    timerLength = iterationTime;
  }
  
  // the number of iterations of the task to present
  int iterations = 12;
  num iterationTime = 5000;
  int maxOp = 15;
}

class SlowTrialTask extends TrialTask {
  
  SlowTrialTask(TaskController delegate) : super(delegate) {
    // generate task events
    for(int i = 0; i < iterations; i++) {
      events.add(new MovingTargetEvent.eventWithLength(delegate, i * iterationTime, 400.0, iterationTime));
      events.add(new AdditionEvent.withRandomOps(delegate, i * iterationTime, maxOp, maxOp, iterationTime));
    }
  }
  
  Random rng = new Random();
}

class FixedTrialTask extends TrialTask {
  
  FixedTrialTask(TaskController delegate) : super(delegate) {
    // generate task events
    for(int i = 0; i < iterations; i++) {
      events.add(new FixedTargetEvent.atRandomPoint(delegate, i * iterationTime, iterationTime));
      events.add(new AdditionEvent.withRandomOps(delegate, i * iterationTime, maxOp, maxOp, iterationTime));
    }
  }
}

class TwoTargetSlowTrialTask extends TrialTask {
  TwoTargetSlowTrialTask(TaskController delegate) : super(delegate) {
    // generate task events
    for(int i = 0; i < iterations; i++) {
      events.add(new MovingTargetEvent.eventWithLength(delegate, i * iterationTime, 400.0, iterationTime));
      events.add(new MovingTargetEvent.eventWithLength(delegate, i * iterationTime, 400.0, iterationTime));
      events.add(new AdditionEvent.withRandomOps(delegate, i * iterationTime, maxOp, maxOp, iterationTime));
      
    }
  }
}