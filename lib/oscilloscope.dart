// Copyright (c) 2018, Steve Rogers. All rights reserved. Use of this source code
// is governed by an Apache License 2.0 that can be found in the LICENSE file.
library oscilloscope;

import 'dart:math' as Math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:oscilloscope/curved.dart';
import 'package:oscilloscope/filter/signal_filter.dart';

/// A widget that defines a customisable Oscilloscope type display that can be used to graph out data
///
/// The [dataSet] arguments MUST be a List<double> -  this is the data that is used by the display to generate a trace
///
/// All other arguments are optional as they have preset values
///
/// [showYAxis] this will display a line along the yAxisat 0 if the value is set to true (default is false)
/// [yAxisColor] determines the color of the displayed yAxis (default value is Colors.white)
///
/// [yAxisMin] and [yAxisMax] although optional should be set to reflect the data that is supplied in [dataSet]. These values
/// should be set to the min and max values in the supplied [dataSet].
///
/// For example if the max value in the data set is 2.5 and the min is -3.25  then you should set [yAxisMin] = -3.25 and [yAxisMax] = 2.5
/// This allows the oscilloscope display to scale the generated graph correctly.
///
/// You can modify the background color of the oscilloscope with the [backgroundColor] argument and the color of the trace with [traceColor]
///
/// The [padding] argument allows space to be set around the display (this defaults to 10.0 if not specified)
///
/// NB: This is not a Time Domain trace, the update frequency of the supplied [dataSet] determines the trace speed.
class Oscilloscope extends StatefulWidget {
  final List<double> dataSet;
  final double yAxisMin;
  final double yAxisMax;
  final double padding;
  final Color backgroundColor;
  final Color traceColor;
  final double xScale;
  final bool isScrollable;
  final bool isZoomable;
  final bool isAdaptiveRange;
  final bool willNormalizeData;
  final bool curved;
  final bool signalFilterActive;
  final double centerPoint;
  final double strokeWidth;
  final double dataMultiplier;
  final double yScaleFactor;
  final double yTranslateFactor;
  final GridDrawingSetting gridDrawingSetting;
  final ReverseSetting reverseSetting;
  final FilterOptions filterOptions;
  final Function(double x, double y) onScaleChange;

  Oscilloscope({
    this.traceColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.padding = 10.0,
    this.yAxisMax = 1.0,
    this.yAxisMin = 0.0,
    this.xScale = 1.0,
    this.isScrollable = false,
    this.isZoomable = false,
    this.isAdaptiveRange = false,
    this.willNormalizeData = false,
    this.gridDrawingSetting,
    this.strokeWidth = 2.0,
    this.reverseSetting,
    this.signalFilterActive = false,
    this.dataMultiplier = 1.0,
    @required this.dataSet,
    @required this.centerPoint,
    this.onScaleChange,
    this.yScaleFactor = 0.03,
    this.yTranslateFactor = 0.8,
    this.curved = false,
    this.filterOptions,
  });

  @override
  _OscilloscopeState createState() => _OscilloscopeState();
}

class _OscilloscopeState extends State<Oscilloscope> {
  double yRange;
  double yScale;

  double yZoomFactor = 1.0;
  double xZoomFactor = 1.0;
  double prevXValue;
  double prevYValue;

  double verticalDragStart;

  double yMin;
  double yMax;
  List<double> normaliedDataSet;
  ScrollController _scrollController = ScrollController(keepScrollOffset: true);

  GlobalKey _widgetKey = GlobalKey();

  bool reverse = false;
  double yOffset = 0.0;
  double centerPoint;

  ReverseSetting get reverseSetting =>
      widget.reverseSetting ?? ReverseSetting();
  bool get isReversable => reverseSetting.reversable == true;

  SignalFilter _signalFilter;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    centerPoint = widget.centerPoint;
    if (widget.willNormalizeData) {
      yMax = 1;
      yMin = 0;
      yRange = 1;
    } else {
      yMax = widget.yAxisMax;
      yMin = widget.yAxisMin;
      yRange = yMax - yMin;
    }
    if (reverseSetting.initialReversed) {
      notifyReverseChangeIfNeeded(false);
    }
  }

  void setSignalFilter() {
    if (widget.filterOptions != null) {
      if (_signalFilter == null) {
        _signalFilter = SignalFilter(widget.filterOptions.filterSize);
      }
      _signalFilter.setFrequency(widget.filterOptions.frequency);
      _signalFilter.setMinCutoff(widget.filterOptions.minCutOff);
      _signalFilter.setBeta(widget.filterOptions.beta);
      _signalFilter.setDerivateCutoff(widget.filterOptions.dCutOff);
    }
  }

  void notifyReverseChangeIfNeeded(bool notifyChange) {
    double yMinTemp = yMin;
    yMin = (-1) * yMax;
    yMax = (-1) * yMinTemp;
    centerPoint = (-1) * centerPoint;
    reverse = !reverse;
    if (notifyChange && reverseSetting.onReverseChange != null) {
      reverseSetting.onReverseChange(reverse);
    }
  }

  void notifyScaleChangeIfNeeded() {
    if (widget.onScaleChange != null) {
      widget.onScaleChange(xZoomFactor, yZoomFactor);
    }
  }

  Offset lastOffset;
  bool yDeltaCheck(Offset off) {
    bool delta;
    if (((lastOffset?.dy ?? 0.0) - off.dy) != 0) {
      delta = ((lastOffset?.dy ?? 0.0) - off.dy) > 0 ? true : false;
    }
    setState(() {
      lastOffset = off;
    });
    return delta;
  }

  @override
  Widget build(BuildContext context) {
    setSignalFilter();
    scrollToEndIfNeeded(context);
    normalizeDataIfNeeded();
    updateYRangeIfNeeded();
    return GestureDetector(
      onLongPressMoveUpdate: (details) {
        setState(() {
          bool delta = yDeltaCheck(details.offsetFromOrigin);
          double tranlateValue = 0.0;
          if (delta != null) {
            tranlateValue =
                delta ? widget.yTranslateFactor : -widget.yTranslateFactor;
          }
          yOffset = yOffset + tranlateValue;
        });
        notifyScaleChangeIfNeeded();
      },
      onVerticalDragUpdate: (details) {
        if (widget.isZoomable) {
          setState(() {
            yZoomFactor = yZoomFactor +
                ((details.primaryDelta >= 0)
                    ? widget.yScaleFactor
                    : -widget.yScaleFactor);
            yZoomFactor = yZoomFactor <= 0 ? widget.yScaleFactor : yZoomFactor;
          });
          notifyScaleChangeIfNeeded();
        }
      },
      onScaleStart: (state) {
        prevXValue = xZoomFactor;
      },
      onScaleUpdate: (ScaleUpdateDetails state) {
        if (widget.isZoomable) {
          setState(() {
            xZoomFactor = prevXValue * state.horizontalScale;
            if (xZoomFactor <= 0) xZoomFactor = 0.0000001;
          });
          notifyScaleChangeIfNeeded();
        }
      },
      onScaleEnd: (_) {
        prevXValue = null;
        prevYValue = null;
      },
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            key: _widgetKey,
            physics: ClampingScrollPhysics(),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: getWidth(context),
              child: Container(
                padding: EdgeInsets.all(widget.padding),
                width: double.infinity,
                height: double.infinity,
                color: widget.backgroundColor,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _TracePainter(
                      dataSet: normaliedDataSet,
                      traceColor: widget.traceColor,
                      yMin: yMin,
                      yMax: yMax,
                      yRange: yRange,
                      centerValue: centerPoint,
                      xScale: widget.xScale * xZoomFactor,
                      isScrollable: widget.isScrollable,
                      gridDrawingSetting: widget.gridDrawingSetting,
                      strokeWidth: widget.strokeWidth,
                      yOffsetValue: yOffset,
                      yZoomFactor: yZoomFactor,
                      multiplier: widget.dataMultiplier ?? 1.0,
                      curved: widget.curved,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: (yZoomFactor != 1.0 || xZoomFactor != 1.0)
                ? IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: widget.traceColor,
                    ),
                    onPressed: () {
                      setState(() {
                        yZoomFactor = 1.0;
                        xZoomFactor = 1.0;
                        yOffset = 0.0;
                        notifyScaleChangeIfNeeded();
                      });
                    },
                  )
                : Container(),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: isReversable
                ? IconButton(
                    icon: Icon(reverseSetting.icon),
                    onPressed: () {
                      setState(() {
                        notifyReverseChangeIfNeeded(true);
                        normalizeDataIfNeeded();
                      });
                    },
                  )
                : Container(),
          ),
        ],
      ),
    );
  }

  void normalizeDataIfNeeded() {
    List<double> _tempDataList = widget.willNormalizeData
        ? reverseData(getNormalizedData(widget.dataSet))
        : reverseData(widget.dataSet);

    normaliedDataSet = (widget.signalFilterActive &&
            _signalFilter != null &&
            widget.filterOptions != null &&
            widget.filterOptions.filterSize >= _tempDataList.length)
        ? _signalFilter.filterValues(_tempDataList)
        : _tempDataList;
  }

  List<double> reverseData(List<double> dataSet) {
    if (reverse && dataSet.length > 0) {
      List<double> dataArray = [];
      dataSet.forEach((element) {
        dataArray.add(element * (-1));
      });
      return dataArray;
    } else {
      return dataSet;
    }
  }

  List<double> getNormalizedData(List<double> dataSet) {
    if (dataSet.length > 0) {
      List<double> dataArray = [];
      double min = dataSet.reduce(Math.min);
      double max = dataSet.reduce(Math.max);
      for (int i = 0; i < dataSet.length; i++) {
        if (max == min) {
          dataArray.add(0.5);
        } else {
          double normalized = (dataSet[i] - min) / (max - min);
          dataArray.add(normalized);
        }
      }
      return dataArray;
    } else {
      return [];
    }
  }

  void updateYRangeIfNeeded() {
    if (widget.isAdaptiveRange && normaliedDataSet.length > 0) {
      yMin = normaliedDataSet.reduce(Math.min) * 1.1;
      yMax = normaliedDataSet.reduce(Math.max) * 1.1;
    } else {
      yMin = widget.yAxisMin;
      yMax = widget.yAxisMax;
    }
    yMin = yMin;
    yMax = yMax;
    yRange = (yMax - yMin) * yZoomFactor;
  }

  void scrollToEndIfNeeded(BuildContext context) {
    if (!widget.isScrollable || context == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        double width = MediaQuery.of(context).size.width;
        if (widget.dataSet.length * widget.xScale > width) {
          if (!_scrollController.position.isScrollingNotifier.value &&
              _scrollController.offset >
                  _scrollController.position.maxScrollExtent - 100) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      } catch (exception) {
        print("Got Error from osciloscope: $exception");
      }
    });
  }

  double getWidth(BuildContext context) {
    double mediaQueryWidth = MediaQuery.of(context).size.width;
    double width = mediaQueryWidth * xZoomFactor;
    if (!widget.isScrollable) {
      return mediaQueryWidth;
    }
    if (widget.dataSet.length == 0) {
      return width;
    }
    double calculatedWidth =
        widget.dataSet.length.toDouble() * widget.xScale * xZoomFactor;
    if (calculatedWidth <= mediaQueryWidth) {
      calculatedWidth = mediaQueryWidth;
    }
    return calculatedWidth;
  }
}

/// A Custom Painter used to generate the trace line from the supplied dataset
class _TracePainter extends CustomPainter {
  final List dataSet;
  final double xScale;
  final double yMin;
  final double yMax;
  final Color traceColor;
  final double yRange;
  final bool isScrollable;
  final GridDrawingSetting gridDrawingSetting;
  final double strokeWidth;
  final double yOffsetValue;
  final double centerValue;
  final double yZoomFactor;
  final double multiplier;
  final bool curved;

  _TracePainter({
    this.yRange,
    this.yMin,
    this.yMax,
    this.dataSet,
    this.xScale = 1.0,
    this.traceColor = Colors.white,
    this.isScrollable = false,
    this.gridDrawingSetting,
    this.strokeWidth = 2.0,
    this.yOffsetValue = 0.0,
    this.yZoomFactor = 0.0,
    this.centerValue = 0.75,
    this.multiplier = 1.0,
    this.curved = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tracePaint = Paint()
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = traceColor
      ..style = PaintingStyle.stroke;

    //If GRid Drawing is enabled
    if (gridDrawingSetting != null) {
      final gridPaint = Paint()
        ..color = gridDrawingSetting.gridColor
        ..strokeWidth = gridDrawingSetting.strokeWidth;

      if (gridDrawingSetting.drawXAxisGrid) {
        for (int i = 0;
            i < size.height;
            i = i + gridDrawingSetting.xAxisGridSpace) {
          canvas.drawLine(Offset(0, i.toDouble()),
              Offset(size.width, i.toDouble()), gridPaint);
        }
      }
      if (gridDrawingSetting.drawYAxisGrid) {
        for (int i = 0;
            i < size.width;
            i = i + gridDrawingSetting.yAxisGridSpace) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble(), size.height), gridPaint);
        }
      }
    }

    int length = dataSet.length;
    if (length > 0) {
      double baseY = size.height * 0.5;
      double yScale = (size.height / yRange) * multiplier;

      if (!isScrollable) {
        int maxSize = (size.width.toDouble() ~/ xScale) + 1;
        if (length > maxSize) {
          dataSet.removeRange(0, length - maxSize);
          length = dataSet.length;
        }
      }

      List<Math.Point> points = [];
      Path trace;
      for (int i = 0; i < length; i++) {
        try {
          double x = i * xScale;
          double y =
              (baseY - (dataSet[i] - centerValue ?? 0) * yScale) - yOffsetValue;
          points.add(Math.Point(x, y));
        } catch (error, stackTrace) {
          print("Error Value: ${dataSet[i]}, $centerValue");
          print("ERROR: $error");
          print("Stack: $stackTrace");
        }
      }
      if (curved) {
        trace = curveTrace(points);
      } else {
        trace = lineTrace(points, baseY);
      }
      canvas.drawPath(trace, tracePaint);
    }
  }

  Path curveTrace(List<Math.Point> points) {
    return Curved.initPath(points);
  }

  Path lineTrace(List<Math.Point> points, double baseY) {
    Path trace = Path();
    trace.moveTo(0, baseY * 0.5);
    for (final point in points) {
      trace.lineTo(point.x, point.y);
    }
    return trace;
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}

class GridDrawingSetting {
  final bool drawXAxisGrid;
  final bool drawYAxisGrid;
  final int xAxisGridSpace;
  final int yAxisGridSpace;
  final Color gridColor;
  final double strokeWidth;

  GridDrawingSetting(
    this.drawXAxisGrid,
    this.drawYAxisGrid, {
    this.xAxisGridSpace = 10,
    this.yAxisGridSpace = 10,
    this.gridColor = Colors.grey,
    this.strokeWidth = 0.5,
  });
}

class ReverseSetting {
  final bool reversable;
  final IconData icon;
  final bool initialReversed;
  final Function(bool value) onReverseChange;
  ReverseSetting({
    this.reversable = false,
    this.icon = Icons.import_export,
    this.initialReversed = false,
    this.onReverseChange,
  });
}

class FilterOptions {
  final double frequency;
  final double minCutOff;
  final double beta;
  final double dCutOff;
  final int filterSize;

  FilterOptions({
    @required this.filterSize,
    this.frequency = 125,
    this.minCutOff = 1,
    this.beta = 0.007,
    this.dCutOff = 1,
  });
}
