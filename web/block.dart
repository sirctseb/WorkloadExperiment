part of WorkloadExperiment;

/// Maintains trial / block state and provides block info to the controller
class BlockManager {
  
  // The number of the block we're on. The first two blocks are practice blocks
  // For the real blocks it is 0...7
  int _blockNumber = 0;
  
  /// The "name" of the block. For the practice blocks this is "practice0" and "practice1"
  dynamic get block => _blockNumber < NUM_PRACTICES ? "practice$_blockNumber" : _blockNumber - NUM_PRACTICES;
  
  /// Access to the block number of the real block sequence
  int get blockNumber => _blockNumber - NUM_PRACTICES;
  
  /// The number of practice blocks
  static const int NUM_PRACTICES = 2;
  
  /// The number of real blocks
  static const int NUM_REAL_BLOCKS = 8;
  
  /// True iff we are in the practice blocks
  bool get practicing => blockNumber < 0;
  
  bool get finished => _blockNumber >= (NUM_PRACTICES + NUM_REAL_BLOCKS);
  
  /// Trial state
  int trialNumber = 0;
  
  static const int TRIALS_PER_PRACTICE = 5;
  static const int TRIALS_PER_BLOCK = 3;
  
  /// Retrieve the number of trials in a given block
  int trialsForBlock(int blockNumber) {
    if(blockNumber < NUM_PRACTICES) {
      return TRIALS_PER_PRACTICE;
    }
    return TRIALS_PER_BLOCK;
  }
  
  /// advance the trial. returns true iff we advance to a new block
  bool advance() {
    // increment trial
    trialNumber++;
    // if we have finished the trials for a block, increment the block and reset trial to 0
    if(trialNumber >= trialsForBlock(_blockNumber)) {
      trialNumber = 0;
      _blockNumber++;
      return true;
    }
    return false;
  }
  
  Task getTask(TaskController controller) {
    if(practicing) {
      if(_blockNumber == 0) {
        // return addition only task
        // TODO make operand range variable
        return new ConfigurableTrialTask(controller, numTargets: 0, opRange: [1, 15]);
      } else {
        // return target only task
        // TODO magic number to produce target distance
        // TODO make speed & number variable
        return new ConfigurableTrialTask(controller, opRange: null, numTargets: 3, targetDist: BlockTrialTask.HIGH_SPEED * 5);
      }
    } else {
      // return a block from the current block
      return Block.allBlocks[blockNumber].createTask(controller);
    }
  }
  
  dynamic get blockDesc {
    if(practicing) {
      // TODO return description of practice block
      return "practice block";
    } else {
      // return actual block
      return Block.allBlocks[blockNumber];
    }
  }
}

/// A block of trials in the experiment
class Block {
  Map toJson() {
    return {
      "targetNumber": targetNumberLow ? "low" : "high",
      "targetSpeed": targetSpeedLow ? "low" : "high",
      "additionDifficulty": additionDiffLow ? "low" : "high"
    };
  }
  
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
        rng = new Random(new DateTime.now().millisecond);
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