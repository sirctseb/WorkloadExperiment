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
  
  /// A list of task events ordered by time
  List<TaskEvent> events;
}
