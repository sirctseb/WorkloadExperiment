library WorkloadExperiment;
import 'dart:html';
import 'dart:isolate';
import 'dart:math';
import 'package:logging/logging.dart';
part 'Target.dart';
part 'TaskController.dart';
part 'Task.dart';
part 'mathutility.dart';


void main() {

  // print log messages to console
  Logger.root.on.record.add((LogRecord record) {
    print(record.message);
  });

  // disable all selection
  document.on.selectStart.add((e) {
    e.preventDefault();
  });
  
  // create task controller
  TaskController controller = new TaskController();
}
