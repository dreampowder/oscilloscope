import 'dart:typed_data';

import 'package:example/signal_filter/signal_filter.dart';
/// Demo of using the oscilloscope package
///
/// In this demo 2 displays are generated showing the outputs for Sine & Cosine
/// The scope displays will show the data sets  which will fill the yAxis and then the screen display will 'scroll'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oscilloscope/oscilloscope.dart';
import 'dart:math';
import 'dart:async';


void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Oscilloscope Display Example",
      home: Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  @override
  _ShellState createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  List<double> traceSine = List();
  List<double> traceCosine = List();
  double radians = 0.0;
  Timer _timer;

  var isNegative = false;

  var heightScale = 1.0;

  List<double> ecgData = List();
  List<double> ecgBuffer = List();
  List<double> ecgPreviewData = List();
  double ecgMin = -1;
  double ecgMax = 1;
  double currentProgress = 0.0;
  double width = 0.0;
  Timer playTimer;

  SignalFilter _signalFilter;

  @override
  initState() {

    super.initState();
  }


  void loadECGData() async{
    print("Loading Data");
//    ByteData byteData = await rootBundle.load("assets/adroid_14min.dat");
    ByteData byteData = await rootBundle.load("assets/RAWTEST4.dat");
    Uint8List list = byteData.buffer.asUint8List();
    print("DATA VALUE COUNT: ${list.length}");
    List<double> values = [];

    double accuracy = 2.656399965286255;
    double last;
    int du1 = 21.252 ~/ accuracy;
    int du2 = 15.9384 ~/ accuracy;
    // int offset = 0;
    // int step = 12;

    // bool isLeadBit = false;
    // int dataBitCounter = 0;
    // int bitCounter = 0;
    // List<double> valueBuffer = [];

    int packageCounter = 0;
    Int8List data = Int8List(12);
    for(int i = 0;i<list.length;i++){
      if (packageCounter < 12) {
        data[packageCounter] = list[i];
        packageCounter++;
      }else{
        int i1 = data[0] & 255;
        int i2 = (data[1] & 15) << 8;
        values.add(((i1|i2)&4095).toDouble() - 2048);
        i1 = (data[1] & 240) >> 4;
        i2 = (data[2] & 255) << 4;
        values.add(((i1|i2)&4095).toDouble() - 2048);
        i1 = data[3] & 255;
        i2 = (data[4] & 15) << 8;
        values.add(((i1|i2)&4095).toDouble() - 2048);
        i1 = (data[4] & 240) >> 4;
        i2 = (data[5] & 255) << 4;
        values.add(((i1|i2)&4095).toDouble() - 2048);
        if (12 < data.length) {
          i1 = data[6] & 255;
          i2 = (data[7] & 15) << 8;
          values.add(((i1|i2)&4095).toDouble() - 2048);
          i1 = (data[7] & 240) >> 4;
          i2 = (data[8] & 255) << 4;
          values.add(((i1|i2)&4095).toDouble() - 2048);
          i1 = data[9] & 255;
          i2 = (data[10] & 15) << 8;
          values.add(((i1|i2)&4095).toDouble() - 2048);
          i1 = (data[10] & 240) >> 4;
          i2 = (data[11] & 255) << 4;
          values.add(((i1|i2)&4095).toDouble());
        }
        packageCounter = 0;
      }
    }

    print("VALUE COUNT: ${values.length}, $width");
    ecgMin = values.reduce(min);
    ecgMax = values.reduce(max);

    List<double> fixedEcgValues = [];
    ecgPreviewData = [];
    int stepCount = 0;
    int previewSteps = values.length ~/ width;
    if(previewSteps == 0){
      previewSteps = 1;
    }
    print("PreviewSteps = ${values.length} / $width");
    print("PreviewSteps = $previewSteps");
    values.forEach((temp){
      double value = temp;
      if (last == null) {
        last = value;
      }
      if((value - last).abs() <= du1){
        value = (value + last * 3) / 4;
      }else if (value - last > du1) {
        value = (value - du2);
      }else{
        value = value + du2;
      }
      fixedEcgValues.add(value);
      last = temp;
      if (stepCount%previewSteps == 0) {
        ecgPreviewData.add(value);
      }
      stepCount++;
    });

    setState(() {
      currentProgress = 0;
      ecgData = fixedEcgValues;
      // ecgData = fixedEcgValues;
    });
    print("Done converting: ${values.length} - $ecgMax");

  }

  void loadDataForCurrentProgress(double progress){
    //print("Val: ${((((currentProgress/ecgData.length)*ecgPreviewData.length))/ecgPreviewData.length)* (MediaQuery.of(context).size.width)}");
    setState(() {
      currentProgress = progress;
      int end = (progress+width).toInt();
      int start = progress.toInt();
      if (end > ecgData.length) {
        end = ecgData.length;
        start = ecgData.length - width.toInt();
      }

      // ecgBuffer = ecgData.sublist(start,end);
      if(_signalFilter == null){
        ecgBuffer = ecgData.sublist(start,end);
      }else{
        ecgBuffer = _signalFilter.filterValues(ecgData.sublist(start,end));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  double prevScale;

  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width;
    if(_signalFilter == null){
      _signalFilter = SignalFilter(width.toInt());
      // _signalFilter.setBeta(0.01);

    }
    _signalFilter.setFrequency(125);
    // _signalFilter.setMinCutoff(50);
    // _signalFilter.setDerivateCutoff(10);
    // _signalFilter.setBeta(1);
    // Generate the Scaffold
    return Scaffold(
      appBar: AppBar(
        title: Text("OscilloScope Demo"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: loadECGData,
          )
        ],
      ),
      body:
      SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Oscilloscope(
                // showYAxis: false,
                // yAxisColor: Colors.lightBlue,
                padding: 0.0,
                backgroundColor: Colors.white60,
                traceColor: Colors.black,
                yAxisMax: ecgMax,
                yAxisMin: ecgMin,
                xScale: 1,
                dataSet: ecgBuffer,
                centerPoint: ecgBuffer.isNotEmpty ? ecgBuffer.first : null,
                isZoomable: true,
                isScrollable: false,
                strokeWidth: 1,
                gridDrawingSetting: GridDrawingSetting(
                  true, //X Ekseni Gridini Göster
                  true, //Y Ekseni Gridini göster
                  gridColor: Color(0xfff2a88d), //Opsiyonel - Grid Rengi
                  yAxisGridSpace: 5, //X Ekseni Grid Aralığı
                  xAxisGridSpace:  5, //Y Ekseni Grid Aralığı
                  strokeWidth: 0.5,
                ),
              ),
            ),
            Stack(
              children: [
                Positioned(
                  left:((((currentProgress/ecgData.length)*ecgPreviewData.length))/ecgPreviewData.length)* (MediaQuery.of(context).size.width),
                  child: Container(
                    height: 50,
                    width: 1,
                    color: Colors.black,
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: Oscilloscope(
                    // showYAxis: false,
                    // yAxisColor: Colors.lightBlue,
                    padding: 0.0,
                    backgroundColor: Colors.white60,
                    traceColor: Colors.black.withAlpha(100),
                    yAxisMax: ecgMax,
                    yAxisMin: ecgMin,
                    xScale: 1,
                    dataSet: ecgPreviewData,
                    centerPoint: ecgPreviewData.isNotEmpty ? ecgPreviewData.first : null,
                    isZoomable: false,
                    isScrollable: true,
                    strokeWidth: 0.5,
                    gridDrawingSetting: GridDrawingSetting(
                      true, //X Ekseni Gridini Göster
                      true, //Y Ekseni Gridini göster
                      gridColor: Color(0xfff2a88d).withAlpha(100), //Opsiyonel - Grid Rengi
                      yAxisGridSpace: 2, //X Ekseni Grid Aralığı
                      xAxisGridSpace:  2, //Y Ekseni Grid Aralığı
                      strokeWidth: 0.25,
                    ),
                  ),
                ),

              ],
            ),
            Row(
              children: <Widget>[
                IconButton(
                  icon: Icon(playTimer != null ? Icons.pause : Icons.play_arrow),
                  onPressed: (){
                    if (playTimer != null) {
                      playTimer.cancel();
                      playTimer = null;
                      setState(() {

                      });
                    }else{
                      playTimer = Timer.periodic(Duration(milliseconds: 10), (timer){
                        setState(() {
                          currentProgress = currentProgress + 1;
                          if (currentProgress >= ecgData.length) {
                            currentProgress = 0;
                            print("Zero set");
                          }
                          loadDataForCurrentProgress(currentProgress);
                        });
                      });
                    }
                  },
                ),
                Expanded(
                  child: Slider(
                    max: ecgData.length.toDouble(),
                    min: 0,
                    value: currentProgress,
                    onChanged: loadDataForCurrentProgress,
                  ),
                )
              ],
            )
          ],
        ),
      )
//
//      Column(
//        children: <Widget>[
//
//          Expanded(flex: 1, child: scopeOne),
////          Expanded(
////            flex: 1,
////            child: scopeTwo,
////          ),
//        ],
//      ),
    );
  }

//  double getWidth(BuildContext context){
//    double minWidth = MediaQuery.of(context).size.width;
//    if (traceSine.length <= minWidth) {
//      return minWidth;
//    }else{
//      return traceSine.length.toDouble()*5.0;
//    }
//  }
}
