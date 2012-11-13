import 'dart:html';

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
  Element target = new DivElement()..classes.add("target")
      ..style.left = "200px"
      ..style.top = "200px";
  document.body.elements.add(target);
  target.on.mouseDown.add((MouseEvent e) {
    ws.send("target hit: ${e.clientX}, ${e.clientY}");
  });
}
