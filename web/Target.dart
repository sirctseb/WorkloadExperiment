part of WorkloadTask;

abstract class TargetDelegate {
  void TargetClicked(Target target, MouseEvent event);
}

/// [Target] is a class that represents a visible target on the screen
class Target {
  TargetDelegate delegate;
  
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
  
  // add the element to the task div
  void show() {
    document.body.query("#task").elements.add(element);
  }
  // remove the element from the DOM
  void remove() {
    element.remove();
  }
  
  /// Create a new [Target]
  Target(this.delegate, {show: false}) {
    
    // add target class
    element.classes.add("target");
    
    // set default location 
    move(200,200);
    
    // show if flag passed
    if(show) {
      show();
    }
    
    // register mouse down event
    element.on.mouseDown.add((MouseEvent e) {
      // dismiss the target
      this.remove();
      
      // notify delegate
      delegate.TargetClicked(this, e);
    });
  }
}
