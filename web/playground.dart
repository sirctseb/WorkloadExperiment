part of WorkloadExperiment;

class Playground implements TaskEventDelegate {
  // target task events
  Map<int, MovingTargetEvent> targetEvents = new Map<int, MovingTargetEvent>();
  Stopwatch stopwatch = new Stopwatch();
  bool running = false;
  Logger logger = new Logger("playground");
  num lastNewStart = 0;
  
  // set up and show the playground
  Playground() {
    targetEvents[0] = new MovingTargetEvent.eventWithLength(this, 5000, true, 1000);
    targetEvents[0].start();
    window.requestAnimationFrame(update);
    stopwatch.start();
    running = true;
  }
  
  void update(num time) {
    for(var startTime in targetEvents.keys) {
      if(targetEvents[startTime].running) {
        targetEvents[startTime].update(stopwatch.elapsedMilliseconds - startTime);
      }
    }
    // start a new one every once in a while
    if(stopwatch.elapsedMilliseconds - lastNewStart > 1000) {
      lastNewStart = stopwatch.elapsedMilliseconds;
      targetEvents[lastNewStart] = new MovingTargetEvent.eventWithLength(this, 5000, true, 1000)..start();
    }
    if(running) {
      window.requestAnimationFrame(update);
    }
  }
  
  // shut down playground
  void kill() {
    stopwatch.stop();
    for(var event in targetEvents.values) {
      event.stop(false);
    }
    running = false;
  }
  

  // TaskEventDelegate Implementation
  void onTargetStart(TargetEvent event, int time) {
    logger.info("target started in playground");
  }
  void onTargetTimeout(TargetEvent event, int time) {
    logger.info("target timed out in playground");
  }
  void onAdditionStart(AdditionEvent event, int time) {
    logger.info("addition started in playground");
  }
  void onAdditionEnd(AdditionEvent event, int time) {
    logger.info("addition ended in playground");
  }

  // TargetDelegate Implementation
  void TargetClicked(Target target, MouseEvent event) {
    logger.info("target clicked in playground");
    if(!target.enemy) {
      target.enemy = true;
    } else {
      target.dismiss();
    }
  }
  void TargetOver(Target target, MouseEvent event) {
    logger.info("target over in playground");
    //target.enemy = !target.enemy;
  }
  void TargetOut(Target target, MouseEvent event) {
    logger.info("target out in playground");
    //target.enemy = !target.enemy;
  }
}

