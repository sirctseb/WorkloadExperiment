part of WorkloadTask;

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

class Circle {
  
  Point _center;
  Point get center => _center;
  
  double _length;
  double get length => _length;
  
  Circle(Point center, double length) {
    _center = center;
    _length = length;
  }
  
  Point randomPoint() {
    return new Point(center.x + length, center.y).rotate(360 * new Random().nextDouble(), center);
  }
}
