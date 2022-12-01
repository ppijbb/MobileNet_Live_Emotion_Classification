import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

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
          width: cameraImg.width,
          height: cameraImg.height))
      .toList();
  return InputImageData(
      size: _s,
      imageRotation: InputImageRotation.rotation0deg,
      // Video format: (iOS) kCVPixelFormatType_32BGRA, (Android) YUV_420_888. nv21(?)
      inputImageFormat: InputImageFormat.yuv_420_888,
      planeData: c_plane);
}

Future<List<Face>> detect_face(
  CameraImage streams,
  Size _s,
) async {
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
  List<Face> result = await _fd.processImage(_inputImg);
  _fd.close();
  return result;
}

img.Image _convertYUV420(CameraImage image) {
  var img_ = img.Image(image.width, image.height); // Create Image buffer
  Plane plane = image.planes[0];
  const int shift = (0xFF << 24);

  // Fill image buffer with plane[0] from YUV420_888
  for (int x = 0; x < image.width; x++) {
    for (int planeOffset = 0;
        planeOffset < image.height * image.width;
        planeOffset += image.width) {
      final pixelColor = plane.bytes[planeOffset + x];
      // color: 0x FF  FF  FF  FF
      //           A   B   G   R
      // Calculate pixel color
      var newVal = shift | (pixelColor << 16) | (pixelColor << 8) | pixelColor;
      img_.data[planeOffset + x] = newVal;
    }
  }
  return img_;
}

img.Image _convertBGRA8888(CameraImage image) {
  return img.Image.fromBytes(
    image.width,
    image.height,
    image.planes[0].bytes,
    format: img.Format.bgra,
  );
}

List<Uint8List> croppingPlanes(CameraImage c_image, Rect box) {
  int box_left = box.left.toInt();
  int box_top = box.top.toInt();
  int box_w = (box.size.width).toInt();
  int box_h = (box.size.height).toInt();
  List<Uint8List> croppedImage = [];
  // Uint8List cameraImage_bytes = concatenatePlanes(c_image.planes);
  // img.Image from_bytes = img.Image.fromBytes(
  //   c_image.width,
  //   c_image.height,
  //   cameraImage_bytes,
  // );
  // img.Image cropped = img.copyCrop(from_bytes, box_left, box_top, box_w, box_h);
  // img.Image resized = img.copyResize(cropped, width: 224, height: 224);
  // Uint8List bufed = resized.getBytes();
  // Image crop_Image = Image.memory(bufed);
  // return crop_Image;
  // int img_range = (bufed.length / 3).toInt();
  // for (var i = 0; i < 3; i++) {
  //   int start_idx = i * img_range;
  //   croppedImage.add(bufed.sublist(start_idx, start_idx + img_range));
  // }

  for (Plane _plane in c_image.planes) {
    Uint8List _bytes = _plane.bytes;
    img.Image from_bytes =
        img.Image.fromBytes(c_image.width, c_image.height, _bytes);
    img.Image cropped =
        img.copyCrop(from_bytes, box_left, box_top, box_w-80, box_h-80);
    img.Image resized = img.copyResize(cropped, width: 224, height: 224);
    Uint8List bufed = resized.getBytes();
    croppedImage.add(bufed);
  }

  return croppedImage;
}
