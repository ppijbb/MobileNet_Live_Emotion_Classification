import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live_emotion/main.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:tflite/tflite.dart';
import 'package:opencv/opencv.dart' as cv;
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_live_emotion/src/detections.dart';
import 'package:flutter_live_emotion/painters/face_detector_painter.dart';
// import 'package:syncfusion_flutter_gauges/gauges.dart';

class Home extends StatefulWidget {
  Home({
    Key? key,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _canProcess = true;
  bool _doFaceDetection = false;
  CameraImage? cameraImage;
  late CameraController? cameraController;
  CustomPaint? customPaint;
  String output = 'Output label here';
  String label = "";
  int _isFrontCamera = 0;
  double? _size = 150; // 모델 이미지 input 사이즈는 224
  double? _value = 0;
  String level = "";
  int _pointers = 0;
  InputImageData? _inputImageData;
  Uint8List? cameraImage_bytes;
  List<Face>? faces = null;
  Rect? boundingBox;
  @override
  void initState() {
    super.initState();
    loadmodel();
    loadCamera();
  }

  void loadCamera() {
    cameraController =
        CameraController(cameras![_isFrontCamera], ResolutionPreset.high);
    cameraController!.initialize().then((value) async {
      if (!mounted) {
        return;
      } else {
        await cameraController!
            .startImageStream((CameraImage imageStream) async {
          setState(() {
            this.cameraImage = imageStream;
            // print("호출시간 ${DateTime.now().millisecondsSinceEpoch}");
          });
          await loop().then((_) {});
        });
      }
    });
  }

  _dfd_state({bool val = false}) async {
    setState(() => this._doFaceDetection = val);
  }

  loop() async {
    // if (this._doFaceDetection == true) {
    await this._dfd_state(val: false).then((_) async {
      detect_func(this.cameraImage!);
      this._doFaceDetection = false;
      await Future.delayed(Duration(seconds: 10))
          .then((_) async => await this._dfd_state(val: true));
    });
    // } else {
    //   .then((_) {
    //     sleep(Duration(seconds: 5));
    //   });
    // }
  }

  Future detect_func(CameraImage imageStream) async {
    Size _size_ =
        Size(imageStream.width.toDouble(), imageStream.height.toDouble());
    await detect_face(imageStream, _size_).then((result) {
      faces = result;
    });
    if (faces != null && faces!.length > 0) {
      FaceDetectorPainter fd_painter = await FaceDetectorPainter(
          faces!, _size_, InputImageRotation.rotation0deg);
      Face face = faces![0];
      setState(() {
        customPaint = CustomPaint(painter: fd_painter, size: _size_);
        boundingBox = face.boundingBox;
      });
      // double? rotX =
      //     face.headEulerAngleX; // Head is tilted up and down rotX degrees
      // double? rotY =
      //     face.headEulerAngleY; // Head is rotated to the right rotY degrees
      // double? rotZ =
      //     face.headEulerAngleZ; // Head is tilted sideways rotZ degrees
      if (face.smilingProbability != null) {
        double smileProb = face.smilingProbability!;
        print("#### SmileProb : $smileProb");
      }
      if (face.trackingId != null) {
        int id = face.trackingId!;
        print("#### tracking ID : $id");
      }
      if (face != null) {
        print('#### bB: ${boundingBox}');
        if (this.cameraImage != null) await runModel(boundingBox!);
      }
    }
  }

  runModel(boxLTRB) async {
    print("#### Model Called ${this._doFaceDetection}");
    if (this.cameraImage != null) {
      Uint8List _cropped = croppingPlanes(
          this.cameraImage!.planes, boxLTRB!, this.cameraImage!.width);
      var i_width = boxLTRB.right - boxLTRB.left;
      var i_height = boxLTRB.bottom - boxLTRB.top;
      await Tflite.runModelOnFrame(
              bytesList: [_cropped],
              imageHeight: i_height.toInt(), // this.cameraImage!.height,
              imageWidth: i_width.toInt(), // this.cameraImage!.width,
              // imageMean: 127.5,
              // imageStd: 127.5,
              // rotation: 0, // Android Only
              numResults: 5,
              threshold: 0.2,
              asynch: true)
          .then((predictions) {
        print("#### preds : $predictions");
        if (predictions != null)
          predictions.forEach((element) {
            element['confidence'] > 0.5
                ? setState(() {
                    level = "Accurate Confidence";
                    output = "$level \n"
                        "top emotion : ${element['label']}"
                        "confidence : ${double.parse((element['confidence'] * 100).toStringAsFixed(2))}";
                    _value = element['confidence'].toDouble() * 100;
                    label = element['label'];
                    print("#### $label $_value");
                    this._doFaceDetection = true;
                  })
                : setState(() {
                    level = "Low Confidence";
                    output = "$level \n"
                        "top emotion : ${element['label']}\n"
                        "confidence : ${double.parse((element['confidence'] * 100).toStringAsFixed(2))}";
                    _value = element['confidence'].toDouble() * 100;
                    label = element['label'];
                    print("#### $label $_value");
                    this._doFaceDetection = true;
                  });
          });
      });
    }
  }

  loadmodel() async {
    await Tflite.loadModel(
      model: "assets/mobilenet_v2_1.0_230_quant.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    );
  }

// Widget Code
  Widget emotionChart() {
    return Column(children: <Widget>[
      SizedBox(
        height: _size,
        width: _size,
        child: SfRadialGauge(axes: <RadialAxis>[
          RadialAxis(
              showLabels: false,
              showTicks: false,
              radiusFactor: 0.8,
              axisLineStyle: const AxisLineStyle(
                thickness: 0.2,
                cornerStyle: CornerStyle.bothCurve,
                color: Color.fromARGB(30, 0, 169, 181),
                thicknessUnit: GaugeSizeUnit.factor,
              ),
              pointers: <GaugePointer>[
                RangePointer(
                    value: _value!,
                    cornerStyle: CornerStyle.bothCurve,
                    width: 0.2,
                    sizeUnit: GaugeSizeUnit.factor,
                    enableAnimation: true,
                    animationDuration: 20,
                    animationType: AnimationType.linear),
                MarkerPointer(
                  value: _value!,
                  markerType: MarkerType.circle,
                  markerHeight: 20,
                  markerWidth: 20,
                  enableAnimation: true,
                  animationDuration: 30,
                  animationType: AnimationType.linear,
                  color: const Color(0xFF87e8e8),
                )
              ],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(
                    positionFactor: 0.1,
                    angle: 90,
                    widget: Text(
                      _value!.toStringAsFixed(0) + ' / 100 \n $label',
                      style: const TextStyle(fontSize: 11),
                    ))
              ])
        ]),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    //빌드 시 faceDetector 이미지 처리 수행할 수 있도록
    return Scaffold(
      appBar: AppBar(title: Text('Live Emotion Detection App')),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.all(20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            width: MediaQuery.of(context).size.width,
            child: !cameraController!.value.isInitialized
                ? Container()
                : AspectRatio(
                    aspectRatio: 1,
                    // child: CameraPreview(cameraController!),
                    child: Column(children: [
                      SizedBox(
                        height: 400,
                        child: Transform.scale(
                            scale: 0.7,
                            child: Transform.rotate(
                                angle: -math.pi / 2.0,
                                child: _cameraPreviewWidget())),
                      ),
                      emotionChart()
                    ]),
                  ),
          ),
        ),
        Text(
          output,
          style: _value! > 70
              ? TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)
              : TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          "${boundingBox}",
          style: _value! > 70
              ? TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)
              : TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ]),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  @override
  Widget _cameraPreviewWidget() {
    // final CameraController? cameraController;
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: Stack(fit: StackFit.expand, children: <Widget>[
          CameraPreview(
            cameraController!,
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                // onScaleStart: _handleScaleStart,
                // onScaleUpdate: _handleScaleUpdate,
                // onTapDown: (TapDownDetails details) =>
                //     onViewFinderTap(details, constraints),
              );
            }),
          ),
          if (customPaint != null)
            Transform.rotate(angle: math.pi / 2.0, child: customPaint),
        ]),
      );
    }
  }

  @override
  void dispose() {
    _canProcess = false;
    // _faceDetector.close();
    cameraController!.dispose();
    super.dispose();
  }
}
