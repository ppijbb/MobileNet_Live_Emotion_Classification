import 'dart:math' as math;
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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  // CustomPaint? customPaint;
  bool _canProcess = true;
  bool _doFaceDetection = false;
  CameraImage? cameraImage;
  late CameraController? cameraController;
  CustomPaint? customPaint;
  String output = 'Output label here';
  String label = '';
  int _isFrontCamera = 0;
  double? _size = 150;
  double? _value = 0;
  String level = "";
  int _pointers = 0;
  InputImageData? _inputImageData;
  Uint8List? cameraImage_bytes;

  @override
  void initState() {
    super.initState();
    loadmodel();
    loadCamera();
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  loadCamera() {
    cameraController =
        CameraController(cameras![_isFrontCamera], ResolutionPreset.high);
    cameraController!.initialize().then((value) {
      if (!mounted) {
        return;
      } else {
        setState(() {
          cameraController!.startImageStream((imageStream) async {
            cameraImage = imageStream;
            // print("####카메라 Stream");
            // 모델 이미지 input 사이즈는 224
            Size _size = Size(
                cameraImage!.width.toDouble(), cameraImage!.height.toDouble());
            // print("####Stream Size");
            cameraImage_bytes = concatenatePlanes(cameraImage!.planes);
            // Uint8List.fromList(
            //   //cameraImage!.plane[0].bytes,
            //   cameraImage!.planes.fold(
            //       <int>[],
            //       (List<int> previousValue, element) =>
            //           previousValue..addAll(element.bytes)),
            // );
            _inputImageData = InputImageData(
                size: _size,
                imageRotation: InputImageRotation.rotation0deg,
                // Video format: (iOS) kCVPixelFormatType_32BGRA, (Android) YUV_420_888.
                inputImageFormat: InputImageFormat.bgra8888,
                planeData: cameraImage!.planes.map((Plane plane) {
                  return InputImagePlaneMetadata(
                      bytesPerRow: plane.bytesPerRow,
                      width: plane.width, //_size.width.toInt(),
                      height: plane.height //_size.height.toInt()
                      );
                }).toList());
            List<Face> faces =
                await _faceDetector.processImage(InputImage.fromBytes(
                    bytes: cameraImage_bytes!, //cameraImage!.planes[0].bytes,
                    inputImageData: _inputImageData!));
            // print("####Stream 얼굴 인식");
            if (faces != null) {
              final fd_painter = await FaceDetectorPainter(
                  faces, _size, InputImageRotation.rotation0deg);
              // print("####얼굴 인식 페인터");
              customPaint = CustomPaint(painter: fd_painter, size: _size);

              for (Face face in faces) {
                final Rect boundingBox = face.boundingBox;
                final double? rotX = face
                    .headEulerAngleX; // Head is tilted up and down rotX degrees
                final double? rotY = face
                    .headEulerAngleY; // Head is rotated to the right rotY degrees
                final double? rotZ = face
                    .headEulerAngleZ; // Head is tilted sideways rotZ degrees

                if (face.smilingProbability != null) {
                  final double smileProb = face.smilingProbability!;
                  print("#### SmileProb : $smileProb");
                }
                if (face.trackingId != null) {
                  final int id = face.trackingId!;
                  print("#### tracking ID : $id");
                }
                if (faces != null) {
                  print('#### ${boundingBox}');
                  print("#### ${_doFaceDetection}");
                  if (true || !_doFaceDetection) {
                    print("#### Model Called");
                    //await Future.delayed(Duration(seconds: 5), () async {
                    _doFaceDetection = true;
                    runModel(boundingBox);
                  }
                }
              }
            }
          });
        });
      }
    });
  }

  Uint8List croppingPlanes(List<Plane> planes, box, width) {
    final WriteBuffer allBytes = WriteBuffer();
    int divider = 1;
    for (Plane plane in planes) {
      for (int i = box!.top.round() ~/ divider; i < box!.bottom.round() ~/ divider; i++) {
        for (int j = box!.left.round() ~/ divider; j < box!.right.round() ~/ divider; j++) {
          allBytes.putUint8(plane.bytes[j + i * width ~/ divider]);
        }
      }
      divider = 2; 
      // allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future(plane, box) async {
    return await img.copyCrop(plane.bytes, box!.top.ond(), box!.bottom.round(),
        box!.left.round(), box!.right.round());
  }

  runModel(boxLTRB) async {
    print("#### Model Called");
    if (cameraImage != null || _doFaceDetection) {
      var predictions = await Tflite.runModelOnBinary(
          binary: croppingPlanes(cameraImage!.planes, boxLTRB!, cameraImage!.width),
          // imageHeight: cameraImage!.height,
          // imageWidth: cameraImage!.width,
          // imageMean: 127.5,
          // imageStd: 127.5,
          // rotation: 0, // Android Only
          numResults: 3,
          threshold: 0.05,
          asynch: true);
      print("#### $predictions");
      if (predictions != null)
        predictions.forEach((element) {
          element['confidence'] > 0.5
              ? setState(() {
                  level = "Accurate Confidence";
                  output =
                      "$level \n top emotion : ${element['label']} confidence : ${double.parse((element['confidence'] * 100).toStringAsFixed(2))}";
                  _value = element['confidence'].toDouble() * 100;
                  label = element['label'];
                  print("#### $label $_value");
                })
              : setState(() {
                  level = "Low Confidence";
                  output =
                      "$level \n top emotion : ${element['label']} \n confidence : ${double.parse((element['confidence'] * 100).toStringAsFixed(2))}";
                  _value = element['confidence'].toDouble() * 100;
                  label = element['label'];
                  print("#### $label $_value");
                });
        });
      _doFaceDetection = false;
      // await Future.delayed(Duration(seconds: 5), () {
      //   _doFaceDetection = false;
      // });
    }
  }

  loadmodel() async {
    await Tflite.loadModel(
      model: "assets/mobilenet_v2_1.0_228_quant.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
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
    _faceDetector.close();
    cameraController!.dispose();
    super.dispose();
  }
}
