part of WorkloadExperiment;

class Playground implements TaskEventDelegate {
  Logger logger = new Logger("playground");
  Timer newEventTimer;
  
  // set up and show the playground
  Playground() {
    newEventTimer = new Timer.periodic(new Duration(seconds:1), (timer) => new FixedTargetEvent.atRandomPoint(this, true).start());
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

