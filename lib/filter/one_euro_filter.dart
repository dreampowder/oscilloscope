import 'dart:math' as math;

import 'package:oscilloscope/filter/low_pass_filter.dart';

class OneEuroFilter {
  double freq;
  double mincutoff;
  double beta;
  double dcutoff;
  LowPassFilter x;
  LowPassFilter dx;
  double lasttime;
  double undefinedTime = -1;

  double alpha(double cutoff) {
    double te = 1.0 / freq;
    double tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / te);
  }

  void setFrequency(double f) {
    if (f <= 0) {
      throw new Exception("freq should be >0");
    }
    freq = f;
  }

  void setMinCutoff(double mc) {
    if (mc <= 0) {
      throw new Exception("mincutoff should be >0");
    }
    mincutoff = mc;
  }

  void setBeta(double b) {
    beta = b;
  }

  void setDerivateCutoff(double dc) {
    if (dc <= 0) {
      throw new Exception("dcutoff should be >0");
    }
    dcutoff = dc;
  }

  OneEuroFilter(double freq,
      [double mincutoff = 1.0, double beta = 0.0, double dcutoff = 1.0]) {
    init(freq, mincutoff, beta, dcutoff);
  }

  void init(double freq, double mincutoff, double beta, double dcutoff) {
    setFrequency(freq);
    setMinCutoff(mincutoff);
    setBeta(beta);
    setDerivateCutoff(dcutoff);
    x = new LowPassFilter(alpha(mincutoff));
    dx = new LowPassFilter(alpha(dcutoff));
    lasttime = undefinedTime;
  }

  double filter(double value, [double timestamp]) {
    timestamp ??= undefinedTime;
    // update the sampling frequency based on timestamps
    if (lasttime != undefinedTime && timestamp != undefinedTime) {
      freq = 1.0 / (timestamp - lasttime);
    }

    lasttime = timestamp;
    // estimate the current variation per second
    double dvalue =
        x.hasLastRawValue() ? (value - x.lastRawValue()) * freq : 0.0;
    double edvalue = dx.filterWithAlpha(dvalue, alpha(dcutoff));
    // use it to update the cutoff frequency
    double cutoff = mincutoff + beta * edvalue.abs();
    // filter the given value
    return x.filterWithAlpha(value, alpha(cutoff));
  }
}
