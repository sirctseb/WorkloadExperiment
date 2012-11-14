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
  num timeOut;
  
  FixedTargetEvent(TaskController delegate, num time, this.x, this.y, [this.timeOut = 1000]): super(delegate, time) {
    target.move(x, y);
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
    target.resize(64,64);
  }
  
  void execute() {
    // show the target
    target.show();
    
    // start a stopwatch for measuring time
    Stopwatch stopwatch = new Stopwatch()..start();
    
    // start a timer for animation
    new Timer.repeating(10, (timer) {
      // if target is not visible, then it has been dismissed, so shut it down
      if(!target.visible) {
        // stop stopwatch
        stopwatch.stop();
        // cancel timer
        timer.cancel();
        return;
      }
      // find fraction of animation complete
      var fraction = stopwatch.elapsedMilliseconds / duration;
      
      // position target
      target.move(startX + fraction * (endX - startX), startY + fraction * (endY - startY));
      
      // kill timer and update score if duration is up
      if(stopwatch.elapsedMilliseconds > duration) {
        // stop stopwatch
        stopwatch.stop();
        // kill timer
        timer.cancel();
        // remove target
        target.remove();
        // update score
        delegate.score -= 100;
      }
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
    events.addAll([
                   new MovingTargetEvent(delegate, 0, 500, 200, 100, 600, 1000),
                   new FixedTargetEvent(delegate, 1000, 200, 300),
                   new FixedTargetEvent(delegate, 2000, 500, 200),]);
  }
}
