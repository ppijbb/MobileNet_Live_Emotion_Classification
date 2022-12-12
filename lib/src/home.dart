import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_emotion/main.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:tflite/tflite.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_live_emotion/src/detections.dart';
import 'package:flutter_live_emotion/painters/face_detector_painter.dart';
import 'package:flutter_live_emotion/src/tf_lite/quant.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// import 'package:syncfusion_flutter_gauges/gauges.dart';

class Home extends StatefulWidget {
  Home({
    Key? key,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _doFaceDetection = false;
  bool _canProcess = true;
  List<Face>? faces = null;
  Image? CropImage = null;
  String output = 'Output label here';
  String label = "";
  int _isFrontCamera = 0;
  double? _size = 150; // 모델 이미지 input 사이즈는 224
  double? _value = 0;
  String level = "";
  int _pointers = 0;
  CameraImage? cameraImage;
  Rect? boundingBox;
  InputImageData? _inputImageData;
  Uint8List? cameraImage_bytes;
  CustomPaint? customPaint;
  late CameraController? cameraController;
  late ClassifierQuant _classifier;

  @override
  void initState() {
    super.initState();
    setState(() => _classifier = ClassifierQuant(numThreads: 1));
    // loadmodel();
    loadCamera();
  }

  Future<Object> _predict(img.Image imageInput, Rect ltrb) async {
    return _classifier.predict(imageInput, ltrb);
  }

  void loadCamera() {
    cameraController = CameraController(
        cameras![_isFrontCamera], ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
    cameraController!.initialize().then((value) async {
      if (!mounted) {
        print("#### CAMERA MOUNT ERROR");
        return;
      } else {
        await cameraController!
            .startImageStream((CameraImage imageStream) async {
          await loop(imageStream);
        });
      }
    });
  }

  Future<void> _dfd_state({bool val = false}) async {
    try {
      setState(() => this._doFaceDetection = val);
    } catch (e) {
      setState(() => this._doFaceDetection = false);
    }
  }

  Future<void> loop(CameraImage i_stream) async {
    if (this._doFaceDetection) {
      await detect_func(i_stream);
      await this._dfd_state(val: false);
    } else {
      await Future.delayed(Duration(seconds: 5), () async {
        setState(() => this._doFaceDetection = false);
        await Future.delayed(
            Duration(seconds: 3), () async => await this._dfd_state(val: true));
      });
    }
  }

  Future<void> detect_func(CameraImage imageStream) async {
    Size _size_ =
        Size(imageStream.width.toDouble(), imageStream.height.toDouble());
    await detect_face(imageStream, _size_).then((List<Face> result) async {
      if (result.length > 0) {
        FaceDetectorPainter fd_painter = FaceDetectorPainter(
            result, _size_, InputImageRotation.rotation0deg);
        Face face = result[0];
        setState(() {
          this.customPaint = CustomPaint(painter: fd_painter, size: _size_);
          this.boundingBox = face.boundingBox;
        });
        if (face.smilingProbability != null)
          print("#### ${face.smilingProbability!}");
        (face != null || imageStream != null)
            ? await runModel(face.boundingBox, imageStream)
            : setState(() {
                _value = 0;
                label = "None";
                level = "Faces Not detected";
                output = "class : -\n"
                    "top emotion : -\n"
                    "confidence : -";
              });
      } else {
        setState(() {
          this.customPaint = null;
          this.boundingBox = null;
        });
      }
    });
  }

  Future<void> runModel(Rect boxLTRB, CameraImage image_stream) async {
    // var _bytes = image_stream.planes.map((plane) {
    //   return plane.bytes;
    // }).toList();
    // List<Uint8List> _bytes = await croppingPlanes(image_stream, boxLTRB);
    // List<Uint8List> _bytes = processing_Planes(image_stream);
    img.Image imageInput = convertYUV420ToImage(image_stream);
    // img.Image imageInput = await convertYUV420toImageColor_(image_stream);
    await _predict(imageInput, boxLTRB).then((result) => setState(() {
          print("#### ${result}");
          _value = (0.5 * 100).toDouble();
          label = result.toString();
          level = "Low Confidence";
          output = "class : ${level}\n"
              "top emotion : ${label}\n"
              "confidence : ${_value!.toStringAsFixed(2)}";
        }));

    // var imageBytes = (await rootBundle.load("assets/image/test11.jpg")).buffer;
    // img.Image oriImage = img.decodeJpg(imageBytes.asUint8List())!;
    // img.Image resizedImage = img.copyResize(oriImage, height: 224, width: 224);

    //   await Tflite.runModelOnFrame(
    //           bytesList: _bytes!,
    //           imageHeight: image_stream.height.toInt(),
    //           imageWidth: image_stream.width.toInt(),
    //           imageMean: 127.5,
    //           imageStd: 127.5,
    //           rotation: 90, // Android Only
    //           numResults: 3,
    //           threshold: 0.1,
    //           asynch: true)
    //       .then((predictions) {
    //     if (predictions != null) {
    //       print("#### predictions ${predictions}");
    //       var element = predictions[0];
    //       element['confidence'] > 0.7
    //           ? setState(() {
    //               _value = (element['confidence'] * 100).toDouble();
    //               label = element['label'];
    //               level = "Accurate Confidence";
    //               output = "class : ${level}\n"
    //                   "top emotion : ${label}\n"
    //                   "confidence : ${_value!.toStringAsFixed(2)}";
    //             })
    //           : setState(() {
    //               _value = (element['confidence'] * 100).toDouble();
    //               label = element['label'];
    //               level = "Low Confidence";
    //               output = "class : ${level}\n"
    //                   "top emotion : ${label}\n"
    //                   "confidence : ${_value!.toStringAsFixed(2)}";
    //             });
    //     }
    //   });
    // }

    // Future<void> loadmodel() async {
    //   await Tflite.loadModel(
    //     model: "assets/models/mobilenet_v2_1.0_230_quant.tflite",
    //     labels: "assets/models/labels.txt",
    //     numThreads: 1,
    //     isAsset: true,
    //     useGpuDelegate: false,
    //   );
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
              radiusFactor: 0.7,
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
                    child: Column(children: [
                      SizedBox(
                        height: 400,
                        child: Transform.scale(
                            scale: 0.8,
                            child: Transform.rotate(
                                angle: 0 * math.pi / 2.0,
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
                  fontWeight: FontWeight.bold, fontSize: 8, color: Colors.red)
              : TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
        ),
        Text(
          "${boundingBox}",
          style: _value! > 70
              ? TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 8, color: Colors.red)
              : TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
        ),
      ]),
    );
  }

  // Display the preview from the camera (or a message if the preview is not available).
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
          (customPaint != null)
              ? Transform.rotate(angle: 0 * math.pi / 1, child: customPaint)
              : SizedBox()
        ]),
      );
    }
  }

  @override
  void dispose() {
    _canProcess = false;
    _classifier.close();
    // Tflite.close();
    cameraController!.dispose();
    super.dispose();
  }
}
