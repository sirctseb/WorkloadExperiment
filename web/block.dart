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
  
  /// The number of trials per block we will run
  static const int trialsPerBlock = 3;

  static bool random = true;
  static bool moreRandom = true;
  static List<Block> _allBlocks;
  /// A list of all experiment blocks
  static List<Block> get allBlocks {
    if(_allBlocks == null) {
      _generateAllBlocks();
    }
    return _allBlocks;
  }
  static void _generateAllBlocks() {
    _allBlocks = [];
    var blocks = [
      new Block(false, false, false),
      new Block(false, false, true),
      new Block(false, true, false),
      new Block(false, true, true),
      new Block(true, false, false),
      new Block(true, false, true),
      new Block(true, true, false),
      new Block(true, true, true)
    ];
    if(random) {
      Random rng;
      if(moreRandom) {
        rng = new Random(new Date.now().millisecond);
      } else {
        rng = new Random(0);
      }
      while(blocks.length > 0) {
        _allBlocks.add(blocks.removeAt(rng.nextInt(blocks.length)));
      }
    } else {
      _allBlocks = blocks;
    }
  }
}