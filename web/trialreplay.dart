part of WorkloadExperiment;

/// A class to manage the replay of trials
class TrialReplay {
  // trial state
  /// The current time (in seconds from the start of the trial. can be negative)
  num get time;
  /// The current iteration
  int iteration;
  /// The targets
  List<Target> targets;
  /// The addition operands
  int op1, op2;
  
  // data source
  List<Map> mouseMoves;
  List<Map> events;
  
  // load data
  void loadTrial(String path);
  
  /// Move the replay to a given time
  set time(num t);
  
  // ui elements
  InputElement iterationSlider;
  InputElement trialSlider;
  InputElement iterationTime;
  InputElement trialTime;
}