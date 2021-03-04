
import 'one_euro_filter.dart';
import 'pvector.dart';

class SignalFilter {
  // Default Parameters of the OneEuroFilter
  // They can be changed using the corresponding setters
  double freq = 125.0;
  double mincutoff = 3.0;
  double beta = 0.007;
  double dcutoff = 1.0;

  // Each SignalFilter can have a number of OneEuroFilter objects
  List<OneEuroFilter> _channels;

  // Number of channels
  int size;

  SignalFilter(int size) {
    size ??= 1;
    if (size <= 0) {
      print(
          "Error in SignalFilter(): The number of channels cannot be $size. The size should be at least 1");
    }
    try {
      _init(size);
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  PVector filterUnitVector(PVector noisyVector) {
    if (_channels.length < 3) {
      print(
          'Error in filterUnit(): The number of channels cannot be $size. You need 3 channels to filter a PVector (even if you only use the x and y values).');
    }

    // Convert the source vector to an array
    List<double> noisyValues = noisyVector.array();

    // Create the target array to receive the filtered values
    List<double> filteredValues = List<double>(3);

    // Filter the noise and return an array of filtered values
    try {
      filteredValues = filterValues(noisyValues);
    } catch (e, s) {
      print(e);
      print(s);
    }

    // Create the target vector to receive the filtered values
    PVector filteredVector = new PVector(0, 0, 0);

    // Convert the array to a PVector
    try {
      filteredVector = toVector(filteredValues);
    } catch (e, s) {
      print(e);
      print(s);
    }

    // Return the filtered values
    return filteredVector;
  }

  PVector filterCoord2D(
      double coordX, double coordY, double scaleX, double scaleY) {
    PVector unitVector = new PVector(0, 0);

    // Convert the coordinate values to unit scale [0.0, 1.0]
    unitVector.x = coordX / scaleX;
    unitVector.y = coordY / scaleY;

    // Create the target vector and filter the noise
    PVector filteredVector = filterUnitVector(unitVector);

    // Scale the values back to the original coordinate system
    filteredVector.x = filteredVector.x * scaleX;
    filteredVector.y = filteredVector.y * scaleY;

    // Return the filtered values
    return filteredVector;
  }

  PVector filterCoord3D(double coordX, double coordY, double coordZ,
      double scaleX, double scaleY, double scaleZ) {
    PVector unitVector = new PVector(0, 0);

    // Convert the coordinate values to unit scale [0.0, 1.0]
    unitVector.x = coordX / scaleX;
    unitVector.y = coordY / scaleY;
    unitVector.z = coordZ / scaleZ;

    // Create the target vector and filter the noise
    PVector filteredVector = filterUnitVector(unitVector);

    // Scale the values back to the original coordinate system
    filteredVector.x = filteredVector.x * scaleX;
    filteredVector.y = filteredVector.y * scaleY;
    filteredVector.z = filteredVector.z * scaleZ;

    // Return the filtered values
    return filteredVector;
  }

  void setFrequency(double f) {
    // Store the value as double
    freq = f;

    // Pass the value to all channels
    for (final OneEuroFilter filter in _channels) {
      try {
        filter.setFrequency(freq);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  void setMinCutoff(double mc) {
    // Store the value as double
    mincutoff = mc;

    // Pass the value to all channels
    for (final OneEuroFilter filter in _channels) {
      try {
        filter.setMinCutoff(mincutoff);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  void setBeta(double b) {
    // Store the value as double
    beta = b;

    // Pass the value to all channels
    for (final OneEuroFilter filter in _channels) {
      try {
        filter.setBeta(beta);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  void setDerivateCutoff(double dc) {
    // Store the value as double
    dcutoff = dc;

    // Pass the value to all channels
    for (final OneEuroFilter filter in _channels) {
      try {
        filter.setDerivateCutoff(dcutoff);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  void _init(int channelCount) {
    if (channelCount <= 0) {
      throw new Exception(
          "Exception in _init(): The number of channels cannot be $channelCount. The size should be at least 1");
    }
    try {
      _createChannels(channelCount);
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  void _createChannels(int channelCount) {
    if (channelCount <= 0) {
      throw new Exception(
          "Exception in createChannels(): The number of channels cannot be $channelCount. The size should be at least 1");
    }
    _channels = new List<OneEuroFilter>();
    for (int i = 0; i < channelCount; i++) {
      try {
        _channels.add(new OneEuroFilter(freq, mincutoff, beta,
            dcutoff)); // Create a default filter for this channel
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  List<double> filterValues(List<double> noisyValues) {
    // Save the amount of source values and channels array (they should match)
    int valueCount = noisyValues.length;
    int channelCount = _channels.length;

    if (valueCount != channelCount) {
      throw new Exception(
          "Exception in filterValues(): The number of filtering channels ($channelCount) must match the number of signals you want to filter ($valueCount)");
    }

    // Create the array to return
    List<double> filteredValues = List<double>(valueCount);

    // Create timestamp
    // double timestamp = 1;

    // Get the filtered values for each noisy value
    for (int i = 0; i < valueCount; i++) {
      OneEuroFilter f = _channels[i];
      double value = noisyValues[i];
      filteredValues[i] = f.filter(value);
    }

    // Return the filtered values
    return filteredValues;
  }

  PVector toVector(List<double> array) {
    int valueCount = array.length;

    if (valueCount > 3) {
      throw new Exception(
          "Exception in toVector(): An array of length $valueCount cannot be converted to PVector. The maximum number of values is 3");
    } else if (valueCount < 2) {
      throw new Exception(
          "Exception in toVector(): An array of length $valueCount cannot be converted to PVector. The minimum number of values is 2");
    }

    List<double> a = array;

    // Convert the array back to a PVector
    double x = a[0];
    double y = a[1];
    double z = a[2];
    PVector v = new PVector(x, y, z);

    // Return the resulting PVector
    return v;
  }
}
