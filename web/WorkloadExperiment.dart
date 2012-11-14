library WorkloadExperiment;
import 'dart:html';
import 'dart:isolate';
import 'dart:math';
part 'Target.dart';
part 'TaskController.dart';
part 'Task.dart';
part 'mathutility.dart';

void main() {
  // disable all selection
  document.on.selectStart.add((e) {
    e.preventDefault();
  });
  
  // create task controller
  TaskController controller = new TaskController();
}
