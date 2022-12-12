import 'package:flutter_live_emotion/src/tf_lite/classifier.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class ClassifierQuant extends Classifier {
  ClassifierQuant({int numThreads: 1}) : super(numThreads: numThreads);

  @override
  String get modelName => 'models/mobilenet_v2_1.0_230_quant.tflite';

  @override
  NormalizeOp get preProcessNormalizeOp => NormalizeOp(0, 1);

  @override
  NormalizeOp get postProcessNormalizeOp => NormalizeOp(0, 255);
}
