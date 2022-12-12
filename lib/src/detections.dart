import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      inputImageFormat: InputImageFormat.yuv420,
      planeData: c_plane);
}

Future<List<Face>> detect_face(CameraImage streams, Size _s) async {
  FaceDetector _fd = FaceDetector(
      options: FaceDetectorOptions(
          minFaceSize: 0.1,
          enableContours: false,
          enableClassification: true,
          enableTracking: true,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.fast));
  Uint8List cameraImage_bytes = concatenatePlanes(streams.planes);
  InputImageData _inputImageData = get_preprocessing(streams, _s);
  InputImage _inputImg = InputImage.fromBytes(
      bytes: cameraImage_bytes, inputImageData: _inputImageData);
  _fd.close();
  return await _fd.processImage(_inputImg);
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
    format: img.Format.rgba,
  );
}

img.Image convertYUV420ToImage(CameraImage cameraImage) {
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image = img.Image(imageWidth, imageHeight);

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      // Y plane should have positive values belonging to [0...255]
      final int y = yBuffer[yIndex];

      // U/V Values are subsampled i.e. each pixel in U/V chanel in a
      // YUV_420 image act as chroma value for 4 neighbouring pixels
      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
      // [0, 255] range they are scaled up and centered to 128.
      // Operation below brings U/V values to [-128, 127].
      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      // Compute RGB values per formula above.
      int r = (y + v * 1436 / 1024 - 179).round();
      int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (y + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      // Use 255 for alpha value, no transparency. ARGB values are
      // positioned in each byte of a single 4 byte integer
      // [AAAAAAAARRRRRRRRGGGGGGGGBBBBBBBB]
      final int argbIndex = h * imageWidth + w;

      image.data[argbIndex] = 0xff000000 |
          ((b << 16) & 0xff0000) |
          ((g << 8) & 0xff00) |
          (r & 0xff);
    }
  }

  return image;
}

List<Uint8List> processing_Planes(CameraImage c_image) {
  List<Uint8List> result = [];
  for (Plane _plane in c_image.planes) {
    result.add(_plane.bytes);
  }
  return result;
}

Future<img.Image> convertYUV420toImageColor_(CameraImage image) async {
  const int shift = (0xFF << 24);
  try {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    print("uvRowStride: " + uvRowStride.toString());
    print("uvPixelStride: " + uvPixelStride.toString());

    // imgLib -> Image package from https://pub.dartlang.org/packages/image
    var img_ = img.Image(width, height); // Create Image buffer

    // Fill image buffer with plane[0] from YUV420_888
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        img_.data[index] = shift | (b << 16) | (g << 8) | r;
      }
    }

    img.PngEncoder pngEncoder = new img.PngEncoder(level: 0, filter: 0);
    List<int> png = pngEncoder.encodeImage(img_);
    return img.Image.fromBytes(image.width, image.height, png,
        format: img.Format.rgb);
  } catch (e) {
    print(">>>>>>>>>>>> ERROR:" + e.toString());
  }
  return img.Image.fromBytes(
      image.width, image.height, List<int>.from(image.planes[0].bytes));
}

Future<List<Uint8List>> croppingPlanes(CameraImage c_image, Rect box) async {
  // Offset box_c = (box.center.dx.toInt(), box.center.dy.toInt());
  int box_w = box.size.width * 1.5 ~/ 4;
  int box_h = box.size.height * 1.5 ~/ 1;
  int box_left = box.left * 0.5 ~/ 4;
  int box_top = box.top * 0.5 ~/ 1;
  List<Uint8List> croppedImage = [];
  // Uint8List cameraImage_bytes = concatenatePlanes(c_image.planes);
  // img.Image from_bytes = img.Image.fromBytes(
  //   c_image.width ~/ 4,
  //   c_image.height,
  //   cameraImage_bytes,
  // );
  // Image from_bytes = convertYUV420ToImage(c_image);
  // List<int> _png_encoded = img.encodePng(from_bytes);
  img.Image _png_encoded = await convertYUV420toImageColor_(c_image);
  img.Image cropped =
      img.copyCrop(_png_encoded!, box_left, box_top, box_w, box_h);
  img.Image resized = img.copyResize(cropped, width: 224, height: 224);
  Uint8List bufed = resized.getBytes();
  int img_range = bufed.length ~/ 3;
  // print("#### ${img_range}");
  for (var i = 0; i < 3; i++) {
    int start_idx = i * img_range;
    croppedImage.add(bufed.sublist(start_idx, start_idx + img_range));
  }

  return croppedImage;
}

Future<img.Image> imgImage(CameraImage c_image) async {
  // Uint8List _image =
  //     (await rootBundle.load("assets/images/test1.jpg")).buffer.asUint8List();
  // return img.Image.fromBytes(943, 1115, _image);
  return img.Image.fromBytes(c_image.planes[0].bytesPerRow, c_image.height,
      concatenatePlanes(c_image.planes),
      format: img.Format.rgb);
}

Uint8List imageToByteListUint8(img.Image image, int inputSize) {
  var convertedBytes = Uint8List(1 * inputSize * inputSize * 3);
  var buffer = Uint8List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = img.getRed(pixel);
      buffer[pixelIndex++] = img.getGreen(pixel);
      buffer[pixelIndex++] = img.getBlue(pixel);
    }
  }
  return convertedBytes.buffer.asUint8List();
}

Uint8List imageToByteListFloat32(
    img.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
    }
  }
  return convertedBytes.buffer.asUint8List();
}
