part of WorkloadExperiment;

/// A block of trials in the experiment
class Block {
  
  /// The target number level
  bool targetNumberLow;
  /// The target speed level
  bool targetSpeedLow;
  /// The addition difficulty level
  bool additionDiffLow;
  
  Block(bool this.targetNumberLow, bool this.targetSpeedLow, bool this.additionDiffLow);
  
  Task createTask(TaskController controller) {
    return new BlockTrialTask(controller,
        targetSpeedLow ? BlockTrialTask.LOW_SPEED : BlockTrialTask.HIGH_SPEED,
        targetNumberLow ? BlockTrialTask.LOW_TARGET_NUMBER : BlockTrialTask.HIGH_TARGET_NUMBER,
        additionDiffLow ? BlockTrialTask.LOW_OPERANDS : BlockTrialTask.HIGH_OPERANDS);
  }
  
}