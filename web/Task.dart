part of WorkloadTask;

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
  
  FixedTargetEvent(TaskController delegate, num time, this.x, this.y): super(delegate, time) {
    target.move(x, y);
  }
  
  void execute() {
    // show the target
    target.show();
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
  
  /// Stopwatch to keep track of progress
  Stopwatch stopwatch = new Stopwatch();
  
  Task(this.delegate);
  
  void start() {
    timer = new Timer.repeating(100, onTimer);
    stopwatch.start();
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
    events.addAll([new FixedTargetEvent(delegate, 1000, 200, 300),
                   new FixedTargetEvent(delegate, 2000, 500, 200)]);
  }
}
