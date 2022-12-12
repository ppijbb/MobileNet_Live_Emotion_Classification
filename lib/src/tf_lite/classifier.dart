import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart';
import 'package:collection/collection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:flutter/material.dart' as material;
import 'package:path_provider/path_provider.dart';
// import 'package:image_picker/image_picker.dart';

abstract class Classifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;

  late List<int> _inputShape;
  late List<int> _outputShape;

  late TensorImage _inputImage;
  late TensorBuffer _outputBuffer;

  late TfLiteType _inputType;
  late TfLiteType _outputType;

  late Directory _root_dir;
  final String _labelsFileName = 'assets/models/labels.txt';

  final int _labelsLength = 3;

  late var _probabilityProcessor;

  late List<String> labels;

  String get modelName;

  NormalizeOp get preProcessNormalizeOp;
  NormalizeOp get postProcessNormalizeOp;

  Classifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }
    loadModel();
    loadLabels();
  }

  Future<void> loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset(modelName, options: _interpreterOptions);
      print('#### Interpreter Created Successfully');
      _root_dir = await getTemporaryDirectory();
      _inputShape = interpreter.getInputTensor(0).shape;
      _outputShape = interpreter.getOutputTensor(0).shape;
      _inputType = interpreter.getInputTensor(0).type;
      _outputType = interpreter.getOutputTensor(0).type;
      print("#### ${_inputShape} ${_inputType} ${_outputShape}");
      _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
      _probabilityProcessor =
          TensorProcessorBuilder().add(postProcessNormalizeOp).build();
    } catch (e) {
      print(
          '#### Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

  Future<void> loadLabels() async {
    labels = await FileUtil.loadLabels(_labelsFileName);
    if (labels.length == _labelsLength) {
      print('#### Labels loaded successfully');
    } else {
      print('#### Unable to load labels');
    }
  }

  TensorImage _preProcess(material.Rect ltrb, TensorImage _image) {
    int cropheight = ((ltrb.top + ltrb.height) > _image.height)
        ? _image.height - ltrb.top.toInt()
        : ltrb.height.toInt();
    //     final IPB = ImageProcessorBuilder()
    // .add(ResizeWithCropOrPadOp(
    //     _inputImage.height, (_inputImage.width ~/ 4).toInt()))

    final IPB = ImageProcessorBuilder()
        .add(ResizeWithCropOrPadOp(
          _image.height ~/ 1,
          _image.width ~/ 1,
        )) // ltrb.left ~/ 4, ltrb.top ~/ 1))
        .add(ResizeOp(
            _inputShape[1], _inputShape[2], ResizeMethod.NEAREST_NEIGHBOUR))
        .add(preProcessNormalizeOp)
        .build();
    return IPB.process(_image);
  }

  Future<Category> predict(Image image, material.Rect ltrb) async {
    // List<int> _png_bytes = encodePng(image);
    // Image _decoded = decodePng(_png_bytes)!;
    final pres = DateTime.now().millisecondsSinceEpoch;
    _inputImage = TensorImage(_inputType);
    // var bytesData = await rootBundle.load("assets/images/test1.jpg");
    // File? img_file = await File('${_root_dir.path}/test1.jpg').writeAsBytes(
    //     bytesData.buffer
    //         .asUint8List(bytesData.offsetInBytes, bytesData.lengthInBytes));
    // var pickedFile = await ImagePicker().getImage(source:ImageSource.camera);
    // File img_file = File(pickedFile!.path);
    // Image image = decodeImage(img_file.readAsBytesSync())!;
    // TensorImage _inputImage = TensorImage();
    _inputImage.loadImage(image);
    // TensorImage? _inputImage = TensorImage.fromFile(img_file);
    // _inputImage.loadImage(image);
    // _inputImage.loadImage(_decoded);
    TensorImage? processed = _preProcess(ltrb, _inputImage);
    final pre = DateTime.now().millisecondsSinceEpoch - pres;

    // print('#### Time to load image: $pre ms');

    final runs = DateTime.now().millisecondsSinceEpoch;
    interpreter.run(processed.buffer.asUint8List(), _outputBuffer.getBuffer());
    final run = DateTime.now().millisecondsSinceEpoch - runs;

    // print('#### Time to run inference: $run ms');

    Map<String, double> labeledProb = TensorLabel.fromList(
            labels, _probabilityProcessor.process(_outputBuffer))
        .getMapWithFloatValue();
    // print("#### $labeledProb");
    final pred = getTopProbability(labeledProb);

    return Category(pred.key, pred.value);
  }

  void close() {
    interpreter.close();
  }
}

MapEntry<String, double> getTopProbability(Map<String, double> labeledProb) {
  var pq = PriorityQueue<MapEntry<String, double>>(compare);
  pq.addAll(labeledProb.entries);

  return pq.first;
}

int compare(MapEntry<String, double> e1, MapEntry<String, double> e2) {
  if (e1.value > e2.value) {
    return -1;
  } else if (e1.value == e2.value) {
    return 0;
  } else {
    return 1;
  }
}
