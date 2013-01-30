part of WorkloadExperiment;

/// Utility math classes

class Point {
  
  num _x, _y;
  
  num get x => _x;
  set x(num value) => _x = value;
  setX(num value) => _x = value;

  num get y => _y;
      set y(num value) => _y = value;
  setY(num value) => _y = value;

  Point(num x, num y) {
    _x = x;
    _y = y;
  }
  Point set(num x, num y) {
    _x = x;
    _y = y;
    return this;
  }
  
  Point clone() {
    return new Point(_x, _y);
  }

  String toString() {
    return '{ x: ${x}, y: ${y} }';
  }


  Point add(/*Point*/ point) {
    return new Point(x + point.x, y + point.y);
  }
  // operator version
  Point operator + (/*Point*/ point) {
    return add(point);
  }

  Point subtract(/*Point*/ point) {
    return new Point(x - point.x, y - point.y);
  }
  // operator version
  Point operator - (/*Point*/ point) {
    return subtract(point);
  }

  Point multiply(/*Point*/ point) {
    return new Point(x * point.x, y * point.y);
  }
  // operator version
  Object operator * (/*Point*/ value) {
    if(value is num) {
      return new Point(x * value, y * value);
    }
    return x * value.x + y * value.y;
  }

  Point divide(/*Point*/ point) {
    return new Point(x / point.x, y / point.y);
  }
  // operator version
  Point operator / (/*Point*/ point) {
    return divide(point);
  }

  Point modulo(/*Point*/ point) {
    return new Point(x % point.x, y % point.y);
  }
  // operator version
  Point operator % (/*Point*/ point) {
    return modulo(point);
  }

  // depending on the language version, this may already be the operator
  Point negate() {
    return new Point(-x, -y);
  }
  // TODO implement operator version once they push the language changes
  Point operator -() {
    return negate();
  }

  /*
  Point transform(Matrix matrix) {
    // TODO operator for matrix-point multiplication?
    return matrix != null ? matrix.transformPoint(this) : this;
  }*/

  num getDistance(/*Point*/ point, [bool squared = false]) {
    num x = point.x - this.x;
    num y = point.y - this.y;
    num d = x * x + y * y;
    return squared ? d : sqrt(d);
  }

  num getLength([bool square = false]) {
    // Supports a hidden parameter 'squared', which controls whether the
    // squared length should be returned. Hide it so it produces a bean
    // property called #length.
    var l = x * x + y * y;
    return square ? l : sqrt(l);
  }
  // property getter for length
  num get length => sqrt(x*x + y*y);

  Point setLength(num length) {
    // TODO: Whenever setting x/y, use #set() instead of direct assignment,
    // so LinkedPoint does not report changes twice.
    if (isZero()) {
      num angle = this.angle;
      x = cos(angle) * length;
      y = cos(angle) * length;
    } else {
      var scale = length / this.length;
      // Force calculation of angle now, so it will be preserved even when
      // x and y are 0
      if (scale == 0)
        this.getAngle();
      this.x *= scale;
      this.y *= scale;
    }
    return this;
  }
  // property setter for length
  set length(num value) => setLength(value);

  Point normalize([num length = 1]) {
    num current = this.length;
    num scale = current != 0 ? length / current : 0;
    Point point = this * scale;
    // Preserve angle.
    // TODO does this not happen automatically
    point.angle = angle;
    return point;
  }

  num getAngle([/*Point*/ point]) {
    // Hide parameters from Bootstrap so it injects bean too
    _angle = getAngleInRadians(point) * 180 / PI;
    return _angle;
  }
  // backing field
  num _angle;
  // property getter
  num get angle => getAngle();

  Point setAngle(angle) {
    angle = this._angle = angle * PI / 180;
    if (!isZero()) {
      var length = this.getLength();
      _x = cos(angle) * length;
      _y = sin(angle) * length;
    }
    return this;
  }
  // property setter
  set angle(num angle) => setAngle(angle);

  num getAngleInRadians([/*Point*/ point]) {
    // Hide parameters from Bootstrap so it injects bean too
    if (point == null) {
      if (_angle == null)
        _angle = atan2(y, x);
      return _angle;
    } else {
      num div = getLength() * point.getLength();
      if (div == 0) {
        return double.NAN;
      } else {
        return acos(this.dot(point) / div);
      }
    }
  }

  num getAngleInDegrees([Point point = null]) {
    return getAngle(point);
  }

  int getQuadrant() {
    return x >= 0 ? y >= 0 ? 1 : 4 : y >= 0 ? 2 : 3;
  }
  // quadrant getter

  num getDirectedAngle(/*Point*/ point) {
    return atan2(cross(point), dot(point)) * 180 / PI;
  }

  Point rotate(num angle, [Point center = null]) {
    angle = angle * PI / 180;
    Point point = center != null ? this - center : this;
    num s = sin(angle);
    num c = cos(angle);
    point = new Point(
      point.x * c - point.y * s,
      point.y * c + point.x * s
    );
    return center != null ? point + center : point;
  }

  bool equals(/*Point*/ point) {
    if(point == null) return false;
    return x == point.x && y == point.y;
  }
  // operator version
  bool operator == (Point point) => equals(point);

  /*bool isInside(Rectangle rect) {
    return rect.contains(this);
  }*/

  bool isClose(Point point, num tolerance) {
    return this.getDistance(point) < tolerance;
  }
  /*bool isColinear(Point point) {
    return this.cross(point) < Numerical.TOLERANCE;
  }*/
/*  bool isOrthogonal(point) {
    return dot(point) < Numerical.TOLERANCE;
  }*/

  bool isZero() {
    return _x == 0 && _y == 0;
  }

  bool isNaN() {
    return x.isNaN || y.isNaN;
  }

  num dot(/*Point*/ point) {
    return x * point.x + y * point.y;
  }

  num cross(/*Point*/ point) {
    return x * point.y - y * point.x;
  }

  /**
   * Returns the projection of the point on another point.
   * Both points are interpreted as vectors.
   *
   * @param {Point} point
   * @returns {Point} the projection of the point on another point
   */
  Point project(/*Point*/ point) {
    if (point.isZero()) {
      return new Point(0, 0);
    } else {
      num scale = dot(point) / point.dot(point);
      return new Point(
        point.x * scale,
        point.y * scale
      );
    }
  }

  Point.random() {
    Random rng = new Random();
    _x = rng.nextDouble();
    _y = rng.nextDouble();
  }

  Point round() {
    // TODO check if dart's round is the same as js
    return new Point(x.round(), y.round());
  }

  Point ceil() {
    return new Point(x.ceil(), y.ceil());
  }

  Point floor() {
    return new Point(x.floor(), y.floor());
  }

  Point abs() {
    return new Point(x.abs(), y.abs());
  }
}


class Rectangle {
  num _x, _y, _width, _height;
  /**
   * Creates a Rectangle object.
   *
   * @name Rectangle#initialize
   * @param {Point} point the top-left point of the rectangle
   * @param {Size} size the size of the rectangle
   */
  /**
   * Creates a rectangle object.
   *
   * @name Rectangle#initialize
   * @param {Number} x the left coordinate
   * @param {Number} y the top coordinate
   * @param {Number} width
   * @param {Number} height
   */
  /**
   * Creates a rectangle object from the passed points. These do not
   * necessarily need to be the top left and bottom right corners, the
   * constructor figures out how to fit a rectangle between them.
   *
   * @name Rectangle#initialize
   * @param {Point} point1 The first point defining the rectangle
   * @param {Point} point2 The second point defining the rectangle
   */
  /**
   * Creates a new rectangle object from the passed rectangle object.
   *
   * @name Rectangle#initialize
   * @param {Rectangle} rt
   */
  Rectangle([arg0, arg1, arg2, arg3]) {
    if(arg3 is num) {
      // Rectangle(x, y, width, height)
      _x = arg0;
      _y = arg1;
      _width = arg2;
      _height = arg3;
    } else if(arg1 is Point) {
      // Rectangle(Point, Point)
      var point1 = arg0;
      var point2 = arg1;
      _x = point1.x;
      _y = point1.y;
      _width = point2.x - point1.x;
      _height = point2.y - point1.y;
      if(_width < 0) {
        _x = point2.x;
        _width = -_width;
      }
      if(_height < 0) {
        _y = point2.y;
        _height = -_height;
      }
    } else if(arg1 != null) {
      // Rectangle(Point, Size);
      var point1 = arg0;
      var point2 = arg1;
      _x = point1.x;
      _y = point1.y;
      _width = point2.width;
      _height = point2.height;
    } else if(arg0 is Rectangle) {
      // Rectangle(Rectangle)
      _x = arg0.x;
      _y = arg0.y;
      _width = arg0.width;
      _height = arg0.height;
    } else if(arg0 is Map && arg0.containsKey("width")) {
      _x = arg0["x"];
      _y = arg0["y"];
      _width = arg0["width"];
      _height = arg0["height"];
    } else {
      _x = _y = _width = _height = 0;
    }
  }

  // generate Rectangles from Rectangle-like things
  // TODO make a factory constructor
  static Rectangle read(arg) {
    if(arg is Rectangle) return arg;
    return new Rectangle(arg);
  }

  /**
   * The x position of the rectangle.
   *
   * @name Rectangle#x
   * @type Number
   */
  void setX(num value) { _x = value; }
  num get x => _x;
      set x(num value) => _x = value;

  /**
   * The y position of the rectangle.
   *
   * @name Rectangle#y
   * @type Number
   */
  void setY(num value) { _y = value; }
  num get y => _y;
      set y(num value) => _y = value;

  /**
   * The width of the rectangle.
   *
   * @name Rectangle#width
   * @type Number
   */
  num get width => _width;
      set width(num value) => _width = value;

  /**
   * The height of the rectangle.
   *
   * @name Rectangle#height
   * @type Number
   */
  num get height => _height;
      set height(num value) => _height = value;

  // DOCS: why does jsdocs document this function, when there are no comments?
  /**
   * @ignore
   */
  Rectangle set(num x, num y, num width, num height) {
    _x = x;
    _y = y;
    _width = width;
    _height = height;
    return this;
  }

  /**
   * The top-left point of the rectangle
   *
   * @type Point
   * @bean
   */
  Point getPoint() {
    // Pass on the optional argument dontLink which tells LinkedPoint to
    // produce a normal point instead. Used internally for speed reasons.
    return new Point(x, y);
  }
  // point property
  Point get point => getPoint();

  Rectangle setPoint(/*Point*/ point) {
    x = point.x;
    y = point.y;
    return this;
  }
  // TODO does js version have this setter?
   setpoint(Point value) => setPoint(value);

  /**
   * The size of the rectangle
   *
   * @type Size
   * @bean
   */
  //Size getSize([dontLink = false]) {
    // See Rectangle#getPoint() about arguments[0]
  //  return LinkedSize.create(this, 'setSize', width, height,
  //      dontLink);
  //}
  // property
  //Size get size => getSize();

  //Rectangle setSize(/*Size*/ size) {
  //  size = Size.read(size);
  //  width = size.width;
  //  height = size.height;
  //  return this;
  //}
  // TODO does js version have this setter?
  /*set size(Size value) => setSize(value);*/

  /**
   * {@grouptitle Side Positions}
   *
   * The position of the left hand side of the rectangle. Note that this
   * doesn't move the whole rectangle; the right hand side stays where it was.
   *
   * @type Number
   * @bean
   */
  num getLeft() {
    return x;
  }
  // property
  num get left => x;

  Rectangle setLeft(num left) {
    width -= left - x;
    x = left;
    return this;
  }
  // property
  set left(value) => setLeft(value);

  /**
   * The top coordinate of the rectangle. Note that this doesn't move the
   * whole rectangle: the bottom won't move.
   *
   * @type Number
   * @bean
   */
  num getTop() {
    return y;
  }
  // property
  num get top => y;

  Rectangle setTop(num top) {
    height -= top - y;
    y = top;
    return this;
  }
  // property
  set top(num value) => setTop(value);

  /**
   * The position of the right hand side of the rectangle. Note that this
   * doesn't move the whole rectangle; the left hand side stays where it was.
   *
   * @type Number
   * @bean
   */
  num getRight() {
    return x + width;
  }
  // property
  num get right => getRight();

  Rectangle setRight(num right) {
    width = right - x;
    return this;
  }
  // property
  set right(num value) => setRight(value);

  /**
   * The bottom coordinate of the rectangle. Note that this doesn't move the
   * whole rectangle: the top won't move.
   *
   * @type Number
   * @bean
   */
  num getBottom() {
    return y + height;
  }
  // property
  num get bottom => getBottom();

  Rectangle setBottom(num bottom) {
    height = bottom - y;
    return this;
  }
  // property
  set bottom(num value) => setBottom(value);

  /**
   * The center-x coordinate of the rectangle.
   *
   * @type Number
   * @bean
   * @ignore
   */
  num getCenterX() {
    return x + width * 0.5;
  }
  // property
  num get centerX => getCenterX();

  Rectangle setCenterX(num x) {
    this.x = x - width * 0.5;
    return this;
  }
  // property
  set centerX(num value) => setCenterX(value);

  /**
   * The center-y coordinate of the rectangle.
   *
   * @type Number
   * @bean
   * @ignore
   */
  num getCenterY() {
    return y + height * 0.5;
  }
  // property
  num get centerY => getCenterY();

  Rectangle setCenterY(y) {
    this.y = y - height * 0.5;
    return this;
  }
  // property
  set centerY(num value) => setCenterY(value);

  /**
   * {@grouptitle Corner and Center Point Positions}
   *
   * The center point of the rectangle.
   *
   * @type Point
   * @bean
   */
  Point getCenter() {
    return new Point(
        getCenterX(), getCenterY());
  }
  // property
  Point get center => getCenter();

  Rectangle setCenter(/*Point*/ point) {
    return setCenterX(point.x).setCenterY(point.y);
  }
  // property
  set center(Point value) => setCenter(value);

  // Get a point by name
  Point getNamedPoint(String name) {
    switch(name) {
      case "TopLeft": return topLeft;
      case "TopRight": return topRight;
      case "BottomLeft": return bottomLeft;
      case "BottomRight": return bottomRight;
      case "LeftCenter": return leftCenter;
      case "TopCenter": return topCenter;
      case "RightCenter": return rightCenter;
      case "BottomCenter": return bottomCenter;
      default: return null;
    }
  }
  /**
   * The top-left point of the rectangle.
   *
   * @name Rectangle#topLeft
   * @type Point
   */
  Point getTopLeft() {
    return new Point(getLeft(), getTop());
  }
  // property
  Point get topLeft => getTopLeft();

  Rectangle setTopLeft(/*Point*/ point) {
    return setLeft(point.x).setTop(point.y);
  }
  // property
  set topLeft(/*Point*/ value) => setTopLeft(value);

  /**
   * The top-right point of the rectangle.
   *
   * @name Rectangle#topRight
   * @type Point
   */
  Point getTopRight() {
    return new Point(getRight(), getTop());
  }
  // property
  Point get topRight => getTopRight();

  Rectangle setTopRight(/*Point*/ point) {
    return setRight(point.x).setTop(point.y);
  }
  // property
  set topRight(/*Point*/ value) => setTopRight(value);

  /**
   * The bottom-left point of the rectangle.
   *
   * @name Rectangle#bottomLeft
   * @type Point
   */
  Point getBottomLeft() {
    return new Point(getLeft(), getBottom());
  }
  // property
  Point get bottomLeft => getBottomLeft();

  Rectangle setBottomLeft(/*Point*/ point) {
    return setLeft(point.x).setBottom(point.y);
  }
  // property
  set bottomLeft(/*Point*/ value) => setBottomLeft(value);

  /**
   * The bottom-right point of the rectangle.
   *
   * @name Rectangle#bottomRight
   * @type Point
   */
  Point getBottomRight() {
    return new Point(getRight(), getBottom());
  }
  // property
  Point get bottomRight => getBottomRight();

  Rectangle setBottomRight(/*Point*/ point) {
    return setRight(point.x).setBottom(point.y);
  }
  // property
  set bottomRight(/*Point*/ value) => setBottomRight(value);

  /**
   * The left-center point of the rectangle.
   *
   * @name Rectangle#leftCenter
   * @type Point
   */
  Point getLeftCenter() {
    return new Point(getLeft(), getCenterY());
  }
  // property
  Point get leftCenter => getLeftCenter();

  Rectangle setLeftCenter(/*Point*/ point) {
    return setCenterY(point.y).setLeft(point.x);
  }
  // property
  set leftCenter(/*Point*/ value) => setLeftCenter(value);

  /**
   * The top-center point of the rectangle.
   *
   * @name Rectangle#topCenter
   * @type Point
   */
  Point getTopCenter() {
    return new Point(getCenterX(), getTop());
  }
  // property
  Point get topCenter => getTopCenter();

  Rectangle setTopCenter(/*Point*/ point) {
    return setCenter(point.x).setTop(point.y);
  }
  // property
  set topCenter(/*Point*/ value) => setTopCenter(value);

  /**
   * The right-center point of the rectangle.
   *
   * @name Rectangle#rightCenter
   * @type Point
   */
  Point getRightCenter() {
    return new Point(getRight(), getCenterY());
  }
  // property
  Point get rightCenter => getRightCenter();

  Rectangle setRightCenter(/*Point*/ point) {
    return setCenter(point.y).setRight(point.x);
  }
  // property
  set rightCenter(/*Point*/ value) => setRightCenter(value);

  /**
   * The bottom-center point of the rectangle.
   *
   * @name Rectangle#bottomCenter
   * @type Point
   */
  Point getBottomCenter() {
   return new Point(getCenterX(), getBottom());
  }
  // property
  Point get bottomCenter => getBottomCenter();
  
  Rectangle setBottomCenter(/*Point*/ point) {
    return setCenter(point.x).setBottom(point.y);
  }
  // property
  set bottomCenter(/*Point*/ value) => setBottomCenter(value);

  bool equals(/*Rectangle*/ rect) {
    rect = Rectangle.read(rect);
    return this.x == rect.x && this.y == rect.y
        && this.width == rect.width && this.height == rect.height;
  }
  // operator
  bool operator ==(Rectangle rect) => equals(rect);

  /**
   * @return {Boolean} {@true the rectangle is empty}
   */
  bool isEmpty() {
    return width == 0 || height == 0;
  }

  String toString() {
    return '{ x: ${x}'
           ', y: ${y}'
           ', width: ${width}'
           ', height: ${height} }';
  }

  bool contains(arg) {
    // Detect rectangles either by checking for 'width' on the passed object
    // or by looking at the amount of elements in the arguments list,
    // or the passed array:
//    return arg && arg.width !== undefined
//        || (Array.isArray(arg) ? arg : arguments).length == 4
//        ? this._containsRectangle(Rectangle.read(arguments))
//        : this._containsPoint(Point.read(arguments));
    // TODO to what extent can we accept Rectangle-like and Point-like objects in the same argument?
    if(arg is Rectangle) return _containsRectangle(arg);
    return containsPoint(arg);
  }

  bool containsPoint(Point point) {
    num x = point.x;
    num y = point.y;
    return x >= this.x && y >= this.y
        && x <= this.x + this.width
        && y <= this.y + this.height;
  }

  bool _containsRectangle(Rectangle rect) {
    num x = rect.x;
    num y = rect.y;
    return x >= this.x && y >= this.y
        && x + rect.width <= this.x + this.width
        && y + rect.height <= this.y + this.height;
  }

  bool intersects(/*Rectangle*/ rect) {
    rect = Rectangle.read(rect);
    return rect.x + rect.width > this.x
        && rect.y + rect.height > this.y
        && rect.x < this.x + this.width
        && rect.y < this.y + this.height;
  }

  Rectangle intersect(/*Rectangle*/ rect) {
    rect = Rectangle.read(rect);
    num x1 = max(this.x, rect.x);
    num y1 = max(this.y, rect.y);
    num x2 = min(this.x + this.width, rect.x + rect.width);
    num y2 = min(this.y + this.height, rect.y + rect.height);
    return new Rectangle.create(x1, y1, x2 - x1, y2 - y1);
  }

  Rectangle unite(/*Rectangle*/ rect) {
    rect = Rectangle.read(rect);
    num x1 = min(this.x, rect.x);
    num y1 = min(this.y, rect.y);
    num x2 = max(this.x + this.width, rect.x + rect.width);
    num y2 = max(this.y + this.height, rect.y + rect.height);
    return new Rectangle.create(x1, y1, x2 - x1, y2 - y1);
  }

  Rectangle include(/*Point*/ point) {
    num x1 = min(this.x, point.x);
    num y1 = min(this.y, point.y);
    num x2 = max(this.x + this.width, point.x);
    num y2 = max(this.y + this.height, point.y);
    return new Rectangle.create(x1, y1, x2 - x1, y2 - y1);
  }

  Rectangle expand(num hor, [num ver]) {
    if (ver == null)
      ver = hor;
    return new Rectangle.create(this.x - hor / 2, this.y - ver / 2,
        this.width + hor, this.height + ver);
  }

  Rectangle scale(num hor, [num ver]) {
    return this.expand(this.width * hor - this.width,
        this.height * (ver == null ? hor : ver) - this.height);
  }

  Rectangle.create(num x, num y, num width, num height) {
    this.set(x,y,width,height);
  }
}

class Circle {
  
  Point _center;
  Point get center => _center;
  
  double _radius;
  double get radius => _radius;
  
  Circle(Point center, num length) {
    _center = center;
    _radius = length.toDouble();
  }
  
  Point randomPoint() {
    return new Point(center.x + radius, center.y).rotate(360 * new Random().nextDouble(), center);
  }
  Point randomPointInRect(Rectangle rectangle) {
    // TODO do this analytically
    
    // generate random points until they are in the rectangle
    Point ret;
    while(!rectangle.contains(ret = randomPoint()));
    return ret;
  }
  
  bool contains(Point point) {
    return center.getDistance(point, true) <= radius*radius;
  }
}
