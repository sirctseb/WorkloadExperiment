/// [TaskEvent] is an event that occurs during a task
abstract class TaskEvent {
  /// The time after the beginning of the task that the event occurs
  num time;
  
  void execute();
  
  TaskEvent(num this.time);
}

/// [TargetEvent] is an [Event] that shows a target
class TargetEvent extends TaskEvent {
  Target target = new Target();
  
  TargetEvent(num time) : super(time) {}
}

/// [Task] represents an experimental task
class Task {
  
  /// A list of task events ordered by time
  List<TaskEvent> events;
}
