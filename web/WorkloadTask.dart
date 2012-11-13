import 'dart:html';

void main() {
  
  WebSocket ws = new WebSocket("ws://localhost:8000/ws");
  
  ws.on.open.add((e) {
    ws.send("hello?");
  });
}
