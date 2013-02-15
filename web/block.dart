part of WorkloadExperiment;

/// Maintains trial / block state and provides block info to the controller
class BlockManager {
  
  // The number of the block we're on.
  int _blockNumber = 0;
  
  /// Access the number of the block.
  int get blockNumber => _blockNumber;

  /// Access to the current block object
  Block get block => allBlocks[blockNumber];
  
  /// The number of blocks
  int get numBlocks => allBlocks.length;
  
  /// True iff we are in the practice blocks
  bool get practicing => blockNumber < 0;
  
  bool get finished => _blockNumber >= numBlocks;
  
  /// Trial state
  int trialNumber = 0;
  
  /// advance the trial. returns true iff we advance to a new block
  bool advance() {
    // increment trial
    trialNumber++;
    // if we have finished the trials for a block, increment the block and reset trial to 0
    if(trialNumber >= block.trials) {
      trialNumber = 0;
      _blockNumber++;
      return true;
    }
    return false;
  }
  
  Task getTask(TaskController controller) {
    return block.createTask(controller);
  }
  

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
    var practiceBlocks = [
      new Block(0, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(0, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, null, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, null, Block.HIGH_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, null, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, null, Block.HIGH_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.HIGH_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.HIGH_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.LOW_OPERANDS, Block.HIGH_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY, true),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.HIGH_OPERANDS, Block.HIGH_DIFFICULTY, true)];
    var experimentalBlocks = [
      new Block(0, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(0, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, null, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, null, Block.HIGH_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, null, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, null, Block.HIGH_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.LOW_OPERANDS, Block.HIGH_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.LOW_SPEED, Block.HIGH_OPERANDS, Block.HIGH_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.LOW_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.LOW_OPERANDS, Block.HIGH_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.HIGH_OPERANDS, Block.LOW_DIFFICULTY),
      new Block(Block.HIGH_TARGET_NUMBER, Block.HIGH_SPEED, Block.HIGH_OPERANDS, Block.HIGH_DIFFICULTY)
    ];
    if(random) {
      Random rng;
      if(moreRandom) {
        rng = new Random(new DateTime.now().millisecond);
      } else {
        rng = new Random(0);
      }
      // randomize practice blocks
      while(practiceBlocks.length > 0) {
        _allBlocks.add(practiceBlocks.removeAt(rng.nextInt(practiceBlocks.length)));
      }
      while(experimentalBlocks.length > 0) {
        _allBlocks.add(experimentalBlocks.removeAt(rng.nextInt(experimentalBlocks.length)));
      }
    } else {
      _allBlocks..addAll(practiceBlocks)..addAll(experimentalBlocks);
    }
  }
}

/// A block of trials in the experiment
class Block {
  /// Is a practice block
  bool practice = false;
  /// The number of trials in the block
  int trials = EXPERIMENTAL_TRIALS;

  // The levels of the target speed independent variable in pixels per second
  static const int LOW_SPEED = 0;
  static const int HIGH_SPEED = 160;
  // The levels of the target count indpendent variable
  static const int LOW_TARGET_NUMBER = 0;
  static const int HIGH_TARGET_NUMBER = 3;
  // The levels of the addition operand ranges
  static const List<int> LOW_OPERANDS = const [1,12];
  static const List<int> HIGH_OPERANDS = const [13,25];
  // The levels of the targeting difficulty
  static const int LOW_DIFFICULTY = 0;
  static const int HIGH_DIFFICULTY = 1;
  
  // The number of trials for practice blocks
  static const int PRACTICE_TRIALS = 1;
  static const int EXPERIMENTAL_TRIALS = 2;
  
  Map toJson() {
    return {
      "trials": trials,
      "practice": practice,
      "targetNumber": targetNumber,
      "targetSpeed": targetSpeed,
      "additionDifficulty": additionDiff,
      "targetDifficulty": targetDiff,
    };
  }
  
  /// The target number level
  int targetNumber;
  /// The target speed level
  int targetSpeed;
  /// The addition difficulty level
  List<int> additionDiff;
  /// The target difficulty level
  int targetDiff;
  
  Block(int this.targetNumber, int this.targetSpeed, List<int> this.additionDiff, int this.targetDiff, [this.practice = false, this.trials]) {
    trials = practice ? PRACTICE_TRIALS : EXPERIMENTAL_TRIALS;
  }
  Block.flags(bool lowTargetNumber, bool lowSpeed, bool lowAddition, bool lowDiff) {
    targetNumber = lowTargetNumber ? Block.LOW_TARGET_NUMBER : Block.HIGH_TARGET_NUMBER;
    targetSpeed = lowSpeed ? Block.LOW_SPEED : Block.HIGH_SPEED;
    additionDiff = lowAddition == null ? null : lowAddition ? Block.LOW_OPERANDS : Block.HIGH_OPERANDS;
    targetDiff = lowDiff ? Block.LOW_DIFFICULTY : Block.HIGH_DIFFICULTY;
  }
  
  Task createTask(TaskController controller) {
    return new BlockTrialTask(controller,
        targetSpeed,
        targetNumber,
        additionDiff,
        targetDiff);
  }
}