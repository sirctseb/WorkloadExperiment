library WorkloadTask;
import 'dart:html';
part 'Target.dart';

void main() {
  
  WebSocket ws = new WebSocket("ws://localhost:8000/ws");
  
  ws.on.open.add((e) {
    ws.send("hello?");
  });
  
  query("body").on.click.add((MouseEvent event) {
    // notify data server of click
    ws.send("${event.screenX}, ${event.screenY}");
  });
  
  // create target display
  Target target = new Target(ws);
}
