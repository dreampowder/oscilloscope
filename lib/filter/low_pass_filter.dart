class LowPassFilter {
  double y, a, s;
  bool initialized;

  void setAlpha(double alpha) {
    if (alpha <= 0.0 || alpha > 1.0) {
      throw new Exception("alpha should be in (0.0, 1.0] and is now $alpha");
    }
    a = alpha;
  }

  LowPassFilter(double alpha, [double initval = 0]) {
    _init(alpha, initval);
  }

  void _init(double alpha, double initval) {
    y = s = initval;
    setAlpha(alpha);
    initialized = false;
  }

  double filter(double value) {
    double result;
    if (initialized) {
      result = a * value + (1.0 - a) * s;
    } else {
      result = value;
      initialized = true;
    }
    y = value;
    s = result;
    return result;
  }

  double filterWithAlpha(double value, double alpha) {
    setAlpha(alpha);
    return filter(value);
  }

  bool hasLastRawValue() {
    return initialized;
  }

  double lastRawValue() {
    return y;
  }
}
