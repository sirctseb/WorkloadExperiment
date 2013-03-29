library WorkloadExperiment;
import 'dart:html';
import 'dart:isolate';
import 'dart:math';
import 'dart:async';
import 'dart:json';
import 'package:logging/logging.dart';
part 'Target.dart';
part 'TaskController.dart';
part 'Task.dart';
part 'block.dart';
part 'tlxweights.dart';
part 'mathutility.dart';
part 'trialreplay.dart';
part 'playground.dart';

void main() {

  // print log messages to console
  Logger.root.onRecord.listen((LogRecord record) {
    print(record.message);
  });
  Logger.root.level = Level.FINE;
  hierarchicalLoggingEnabled = true;

  // disable all selection
  document.onSelectStart.listen((e) {
    e.preventDefault();
  });
  
  // create task controller
  TaskController controller = new TaskController();
}
