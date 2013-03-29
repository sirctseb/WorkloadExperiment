part of WorkloadExperiment;

class Playground implements TaskEventDelegate {
  // target task events
  List<MovingTargetEvent> targetEvents;
  Stopwatch stopwatch = new Stopwatch();
  bool running = false;
  
  // set up and show the playground
  Playground() {
    targetEvents = [new MovingTargetEvent.eventWithLength(this, 5000, true, 1000)];
    targetEvents.first.start();
    window.requestAnimationFrame(update);
    stopwatch.start();
    running = true;
  }
  
  void update(num time) {
    for(var event in targetEvents) {
      event.update(stopwatch.elapsedMilliseconds);
    }
    if(running) {
      window.requestAnimationFrame(update);
    }
  }
  
  // shut down playground
  void kill() {
    stopwatch.stop();
    for(var event in targetEvents) {
      event.stop(false);
    }
    running = false;
  }
  

  // TaskEventDelegate Implementation
  void onTargetStart(TargetEvent event, int time) {
  }
  void onTargetTimeout(TargetEvent event, int time) {
  }
  void onAdditionStart(AdditionEvent event, int time) {
  }
  void onAdditionEnd(AdditionEvent event, int time) {
  }

  // TargetDelegate Implementation
  void TargetClicked(Target target, MouseEvent event) {
  }
  void TargetOver(Target target, MouseEvent event) {
  }
  void TargetOut(Target target, MouseEvent event) {
  }
}

