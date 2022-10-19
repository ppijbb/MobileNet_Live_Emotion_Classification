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

Uint8List concatenatePlanes(List<Plane> planes) {
  final WriteBuffer allBytes = WriteBuffer();
  for (Plane plane in planes) {
    allBytes.putUint8List(plane.bytes);
  }
  return allBytes.done().buffer.asUint8List();
}

InputImageData get_preprocessing(CameraImage cameraImg, Size _s) {
  List<InputImagePlaneMetadata> c_plane = cameraImg.planes
      .map((Plane plane) => InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          width: _s.width.toInt(),
          height: _s.height.toInt()))
      .toList();
  return InputImageData(
      size: _s,
      imageRotation: InputImageRotation.rotation0deg,
      // Video format: (iOS) kCVPixelFormatType_32BGRA, (Android) YUV_420_888.
      inputImageFormat: InputImageFormat.bgra8888,
      planeData: c_plane);
}

Future<List<Face>> detect_face(
  CameraImage streams,
  Size _s,
) async {
  // Uint8List.fromList(
  //   //cameraImage!.plane[0].bytes,
  //   cameraImage!.planes.fold(
  //       <int>[],
  //       (List<int> previousValue, element) =>
  //           previousValue..addAll(element.bytes)),
  // );
  FaceDetector _fd = FaceDetector(
      options: FaceDetectorOptions(
          minFaceSize: 0.1,
          enableContours: false,
          enableClassification: false,
          enableTracking: true,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.fast));
  Uint8List cameraImage_bytes = concatenatePlanes(streams.planes);
  InputImageData _inputImageData = get_preprocessing(streams, _s);
  InputImage _inputImg = InputImage.fromBytes(
      bytes: cameraImage_bytes, //cameraImage!.planes[0].bytes,
      inputImageData: _inputImageData);
  // sleep(Duration(seconds: 3));
  return await _fd.processImage(_inputImg);
}

Uint8List croppingPlanes(List<Plane> planes, box, width) {
  WriteBuffer allBytes = WriteBuffer();
  int divider = 1;
  for (Plane plane in planes) {
    for (int i = box!.top.round() ~/ divider;
        i < box!.bottom.round() ~/ divider;
        i++) {
      for (int j = box!.left.round() ~/ divider;
          j < box!.right.round() ~/ divider;
          j++) {
        allBytes.putUint8(plane.bytes[j + i * width ~/ divider]);
      }
    }
    divider = 2;
    // allBytes.putUint8List(plane.bytes);
  }
  return allBytes.done().buffer.asUint8List();
}

 // Future(plane, box) async {
 //   return await img.copyCrop(plane.bytes, box!.top.ond(), box!.bottom.round(),
 //       box!.left.round(), box!.right.round());
 // }
