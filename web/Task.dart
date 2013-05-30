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

abstract class TaskEventDelegate extends TargetDelegate {
  void onTargetStart(TargetEvent event, int time);
  void onTargetTimeout(TargetEvent event, int time);
  void onAdditionStart(AdditionEvent event, int time);
  void onAdditionEnd(AdditionEvent event, int time);
}

abstract class TaskEvent {
  /// The task controller
  TaskEventDelegate delegate;
  
  void start();
  void restart();
  void stop() {}
  
  TaskEvent(TaskEventDelegate this.delegate);

  Map toJson() {
    return {};
  }
}

/// [TargetEvent] is an [Event] that shows a target
abstract class TargetEvent extends TaskEvent {
  Target target;
  bool get running => target.visible;
  
  TargetEvent(TaskEventDelegate delegate, bool enemy) : super(delegate) {
    target = new Target(delegate, enemy);
  }
  Map toJson() {
    return merge(super.toJson(), {"target": target.toJson()});
  }
}

/// [FixedTargetEvent] is a [TargetEvent] that shows a target in a fixed position
class FixedTargetEvent extends TargetEvent {
  num x, y;

  Random rng = new Random();
  FixedTargetEvent(TaskEventDelegate delegate, this.x, this.y, bool enemy): super(delegate, enemy) {
    target.move(x, y);
  }
  
  FixedTargetEvent.atRandomPoint(TaskEventDelegate delegate, bool enemy) : super(delegate, enemy) {
  }
  
  void start() {
    print("starting target event");
    // put target at random place on screen
    num x = rng.nextInt(document.body.clientWidth - target.width) + target.width/2;
    num y = rng.nextInt(document.body.clientHeight - target.height) + target.height/2;
    target.move(x, y);
    // show the target
    target.show();
    delegate.onTargetStart(this, new DateTime.now().millisecondsSinceEpoch);
  }
  void restart() {
    print("restarting target event");
    print("calling stop");
    stop();
    print("calling start");
    start();
  }
  void stop() {
    print("stopping target event");
    if(target.visible) {
      print("dismissing because visible");
      target.dismiss();
    }
  }
  
  Map toJson() {
    return merge(super.toJson(), {"x": x, "y": y});
  }
}

/// [AdditionEvent] is a [TaskEvent] that displays an addition problem on the screen
class AdditionEvent extends TaskEvent {
  
  int op1, op2;
  int opMin, opMax;
  Random rng = new Random();
  bool firstHalfSecond;
  
  Map toJson() {
    return merge(super.toJson(), {"op1": op1, "op2": op2});
  }
  
  AdditionEvent(TaskEventDelegate delegate, int this.op1, int this.op2)
      : super(delegate) {
  }
  
  AdditionEvent.withRandomOps(TaskEventDelegate delegate, int this.opMin, int this.opMax)
      : super(delegate) {
  }
  
  void start() {
    // set ops randomly within max
    if(opMax != null) {
      int range = opMax - opMin;
      op1 = rng.nextInt(range) + opMin;
      op2 = rng.nextInt(range) + opMin;
    }
    
    // display text in addition task problem
    query("#addition").text = "$op1 + $op2";
    
    firstHalfSecond = true;

    // notify delegate
    delegate.onAdditionStart(this, new DateTime.now().millisecondsSinceEpoch);
    
    // set first half second to false in a half second
    new Timer(new Duration(milliseconds: 500), () => firstHalfSecond = false);
  }
  void restart() {
    // hide the problem for a brief time
    query("#addition").classes.add("hidden");
    new Timer(new Duration(milliseconds: 200), () => query("#addition").classes.remove("hidden"));
    start();
  }
  
  void stop() {
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
  
  FixedTargetEvent enemyTargetEvent1;
  FixedTargetEvent enemyTargetEvent2;
  FixedTargetEvent friendTargetEvent;
  AdditionEvent additionEvent;
  
  /// Generate the task events
  void buildEvents();
  
  Map toJson() {
    return {"enemyTargetEvent1": enemyTargetEvent1,
            "enemyTargetEvent2": enemyTargetEvent2,
            "friendTargetEvent": friendTargetEvent,
            "additionEvent": additionEvent};
  }
  
  Task(this.delegate);
  
  bool get firstHalfSecondOfAddition => additionEvent == null ? false : additionEvent.firstHalfSecond;
  
  void start() {
    running = true;

    // tell delegate that task started
    delegate.onTrialStart(new DateTime.now().millisecondsSinceEpoch);
    
    // start tasks
    if(enemyTargetEvent1 != null) {
      enemyTargetEvent1.start();
      enemyTargetEvent2.start();
      friendTargetEvent.start();
    }
    if(additionEvent != null) {
      additionEvent.start();
    }
    
    // stop after 1 minute
    new Timer(new Duration(minutes:1), stop);
  }
  void stop() {
    // kill tasks
    if(enemyTargetEvent1 != null) {
      enemyTargetEvent1.stop();
      enemyTargetEvent2.stop();
      friendTargetEvent.stop();
    }
    
    // tell delegate that task ended
    delegate.onTrialEnd(new DateTime.now().millisecondsSinceEpoch);
    
    running = false;
  }
  
  /// End the current addition task
  void endAdditionEvent() {
    // stop the addition event
    additionEvent.stop();
    // restart it
    additionEvent.restart();
  }
  /// notification that a target was clicked
  void targetClicked() {
    // if enemy targets are both done, restart
    if(!enemyTargetEvent1.running && !enemyTargetEvent2.running) {
      enemyTargetEvent1.restart();
      enemyTargetEvent2.restart();
      friendTargetEvent.restart();
    }
  }
  
  /// Set up the task interface for this task
  void setupUI();
}

abstract class TrialTask extends Task {
  List<int> opRange = [1,15];
  
  // the number of targets to present
  int numTargets;
  
  Map toJson() {
    return merge(super.toJson(), {"opRange": opRange, "numTargets": numTargets});
  }
  
  TrialTask(TaskController delegate, {int this.numTargets: 3,
                                      List<int> this.opRange: const [1, 15]})
      : super(delegate) {
  }
  
  void buildEvents() {
    if(numTargets != 0) {
      enemyTargetEvent1 = new FixedTargetEvent.atRandomPoint(delegate, true);
      enemyTargetEvent2 = new FixedTargetEvent.atRandomPoint(delegate, true);
      friendTargetEvent = new FixedTargetEvent.atRandomPoint(delegate, false);
    }
    if(opRange != null) {
      additionEvent = new AdditionEvent.withRandomOps(delegate, opRange[0], opRange[1]);
    }
  }
}

// TODO this just adds one parameter to the constructor and a buildTargetEvent method
class ConfigurableTrialTask extends TrialTask {

  int targetSize = 128;
  int targetDifficulty;
  
  Map toJson() {
    return merge(super.toJson(), {"targetSize": targetSize, "targetDifficulty": targetDifficulty});
  }
  
  ConfigurableTrialTask(TaskController delegate,
      { int numTargets: 1,
        List<int> opRange: const [1, 15],
        int this.targetSize: 128,
        int this.targetDifficulty: 1})
      : super(delegate, numTargets: numTargets, opRange: opRange);

  /// Set up UI by added classes based on targeting difficulty and single-task vs dual-task
  void setupUI() {
    // set css based on target difficulty
    if(targetDifficulty == Block.HIGH_DIFFICULTY) {
      document.body.classes.add("high-targeting-difficulty");
    } else {
      document.body.classes.remove("high-targeting-difficulty");
    }
    
    // set css based on whether there is an addition task
    if(opRange == null) {
      document.body.classes.add("targeting-only");
    } else {
      document.body.classes.remove("targeting-only");
    }
    
    // set css based on whether there is a targeting task
    if(numTargets == 0) {
      document.body.classes.add("addition-only");
    } else {
      document.body.classes.remove("addition-only");
    }
  }
}

class BlockTrialTask extends ConfigurableTrialTask {
  
  // trial task constants
  static const int TARGET_SIZE = 128;
  
  BlockTrialTask(TaskController delegate,
      int speed, int target_number, List<int> operand_range, int target_difficulty)
      : super(delegate, numTargets: target_number, opRange: operand_range,
          targetSize: TARGET_SIZE, targetDifficulty: target_difficulty);
}