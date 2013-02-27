part of WorkloadExperiment;

abstract class TargetDelegate {
  void TargetClicked(Target target, MouseEvent event);
  void TargetOver(Target target, MouseEvent event);
  void TargetOut(Target target, MouseEvent event);
}

/// [Target] is a class that represents a visible target on the screen
class Target {
  TargetDelegate delegate;
  
  static const bool ENEMY = true;
  static const bool FRIEND = false;
  
  /// The target is an enemy
  bool get enemy => _enemy;
  bool _enemy;
  set enemy(bool e) {
    // bail if we're not changing
    if(_enemy == e) return;
    // set backing field
    _enemy = e;
    // add enemy or friend class
    if(_enemy) {
      element.classes.remove("friend");
      element.classes.add("enemy");
    } else {
      element.classes.remove("enemy");
      element.classes.add("friend");
    }
  }
  
  // an ID to tell target apart from others
  int _ID = _ID_counter++;
  int get ID => _ID;
  // ID counter
  static int _ID_counter = 0;
  
  /// The div element that shows the target
  DivElement element = new DivElement();
  
  // the size of the target
  num _width = 128;
  num _height = 128;
  num get width => _width;
  num get height => _height;
  set width(num w) {
    // set backing var
    _width = w;
    // update css
    element.style.width = "${w}px";
  }
  set height(num h) {
    // set backing var
    _height = h;
    // update css
    element.style.height = "${h}px";
  }
  // set together
  void resize(num w, num h) {
    width = w;
    height = h;
  }
  
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
  
  Map toJson() {
    return {"id": ID, "width": width, "height": height, "x": x, "y": y, "enemy": enemy};
  }
  
  // whether the target is in the scene
  bool _visible = false;
  bool get visible => _visible;
  
  // add the element to the task div
  void show() {
    document.body.query("#task").children.add(element);
    _visible = true;
  }
  // remove the element from the DOM
  void dismiss() {
    element.classes.add("dismissed");
    _visible = false;
    delayedRemove();
  }
  // remove the element due to it being timed out
  void timeout() {
    element.classes.add("timeout");
    _visible = false;
    // remove after animation
    delayedRemove();
  }
  void delayedRemove() {
    // remove after 200ms
    // TODO if animation time changes, change this delay
    new Timer(200, (timer) {
      element.remove();
    });
  }
  
  /// Create a new [Target]
  Target(this.delegate, bool enemy, {show: false}) {
    
    // add target class
    element.classes.add("target");
    
    // add enemy or friend class
    this.enemy = enemy;
    
    // set default location 
    move(200,200);
    
    // show if flag passed
    if(show) {
      show();
    }
    
    // register mouse down event
    element.onMouseDown.listen((MouseEvent e) {
      // check that the click is within the target image and not just in the div
      num distSq = pow(e.clientX - x, 2) + pow(e.clientY - y, 2);
      if(distSq <= width*width/4) {
        
        // notify delegate
        delegate.TargetClicked(this, e);
      }
    });
    // register mouse over event
    element.onMouseOver.listen((MouseEvent e) {
      // notify delegate
      delegate.TargetOver(this, e);
    });
    // register mouse leave event
    element.onMouseOut.listen((MouseEvent e) {
      // notify delegate
      delegate.TargetOut(this, e);
    });
  }
}
