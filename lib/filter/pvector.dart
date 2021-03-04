class PVector {
  double x;
  double y;
  double z;

  PVector(x, y, [z = 0]);

  List<double> array() {
    return [x, y, z];
  }
}
