part of WorkloadTask;

/// [Target] is a class that represents a visible target on the screen
class Target {
  
  /// The div element that shows the target
  DivElement element = new DivElement();
  
  // the size of the target
  final num width = 128;
  final num height = 128;
  
  // The coordinates of the target
  num _x = 0, _y = 0;
  
  // access the coordinates of the target
  num get x => _x;
  num get y => _y;
  
  // set the target coordinates
  set x(num x_in) {
    _x = x_in;
    // update css location
    element.style.left = "${x - width/2}px"; 
  }
  set y(num y_in) {
    _y = y_in;
    // update css location
    element.style.top = "${y - height/2}px";
  }
  // set together
  void move(num x, num y) {
    this.x = x;
    this.y = y;
  }
  
  /// Create a new [Target]
  Target(WebSocket ws) {
    element.classes.add("target");
    move(200,200);
    document.body.elements.add(element);
    element.on.mouseDown.add((MouseEvent e) {
      ws.send("target hit: ${e.clientX}, ${e.clientY}");
    });
  }
}
