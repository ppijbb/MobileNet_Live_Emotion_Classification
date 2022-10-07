import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:survey_kit/survey_kit.dart';
import 'package:survey_kit/src/answer_format/text_choice.dart';

import 'package:flutter_live_emotion/main.dart';
import 'package:flutter_live_emotion/src/survey_task/task.dart';

class CBCL extends StatefulWidget {
  CBCL({
    Key? key,
  }) : super(key: key);

  @override
  _CBCLState createState() => _CBCLState();
}

class _CBCLState extends State<CBCL> {
  // CustomPaint? customPaint;
  bool _canProcess = true;
  bool _doFaceDetection = false;
  CameraImage? cameraImage;

  CustomPaint? customPaint;
  String output = 'In Progress';
  String label = '';
  int _isFrontCamera = 0;
  double? _size = 150;
  double? _value = 0;
  String level = "";
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //빌드 시 faceDetector 이미지 처리 수행할 수 있도록
    return //Column(children: [
        //Padding(
        // padding: EdgeInsets.all(20),
        //child:
        Container(
      height: MediaQuery.of(context).size.height * 0.7,
      width: MediaQuery.of(context).size.width,
      child: Container(
        child: AspectRatio(
          aspectRatio: 1,
          child: _cbclWidget(),
        ),
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  @override
  Widget _cbclWidget() {
    return Container(
        color: Colors.white,
        child: Align(
          alignment: Alignment.center,
          child: FutureBuilder<Task>(
            future: getJsonTask(),//getSampleTask(),
            builder: (context, snapshot) {
              print("#### SURVEY STARTED");
              print("#### ${snapshot.connectionState}");
              print("#### ${snapshot.hasData}");
              print("#### ${snapshot.data}");
              if ((snapshot.connectionState == ConnectionState.done ||
                      snapshot.connectionState == ConnectionState.waiting) &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                final task = snapshot.data!;
                return SurveyKit(
                  onResult: (SurveyResult result) {
                    print("#### Done with : ${result.finishReason}");
                    result.results.forEach((element) {
                      print(element.results.length);
                      // TextChoice 인 경우 
                      if (element.results[0].result is TextChoice) {
                        print("${element.results[0].result.text} : ${element.results[0].result.value}");
                      }
                      // TextChoice 인데 List<TextChoice>인 경우
                      else if(element.results[0].result is List<TextChoice>){
                        element.results[0].result.forEach((item) {
                          print("${item.text} : ${item.value}");
                        });
                      } else // 나머지
                        print("${element.results[0].result}");
                      print("${element.id!.id}");
                    });

                    Navigator.pushNamed(context, '/');
                  },
                  task: task,
                  showProgress: true,
                  localizations: {
                    'cancel': 'Cancel',
                    'next': 'Next',
                  },
                  themeData: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSwatch(
                      primarySwatch: Colors.cyan,
                    ).copyWith(
                      onPrimary: Colors.white,
                    ),
                    primaryColor: Colors.cyan,
                    backgroundColor: Colors.white,
                    appBarTheme: const AppBarTheme(
                      color: Colors.amber,
                      iconTheme: IconThemeData(
                        color: Colors.cyan,
                      ),
                      titleTextStyle: TextStyle(
                        color: Colors.cyan,
                      ),
                    ),
                    iconTheme: const IconThemeData(
                      color: Colors.cyan,
                    ),
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: Colors.cyan,
                      selectionColor: Colors.cyan,
                      selectionHandleColor: Colors.cyan,
                    ),
                    cupertinoOverrideTheme: CupertinoThemeData(
                      primaryColor: Colors.cyan,
                    ),
                    outlinedButtonTheme: OutlinedButtonThemeData(
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all(
                          Size(150.0, 60.0),
                        ),
                        side: MaterialStateProperty.resolveWith(
                          (Set<MaterialState> state) {
                            if (state.contains(MaterialState.disabled)) {
                              return BorderSide(
                                color: Colors.grey,
                              );
                            }
                            return BorderSide(
                              color: Colors.cyan,
                            );
                          },
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        textStyle: MaterialStateProperty.resolveWith(
                          (Set<MaterialState> state) {
                            if (state.contains(MaterialState.disabled)) {
                              return Theme.of(context)
                                  .textTheme
                                  .button
                                  ?.copyWith(
                                    color: Colors.grey,
                                  );
                            }
                            return Theme.of(context).textTheme.button?.copyWith(
                                  color: Colors.cyan,
                                );
                          },
                        ),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: ButtonStyle(
                        textStyle: MaterialStateProperty.all(
                          Theme.of(context).textTheme.button?.copyWith(
                                color: Colors.cyan,
                              ),
                        ),
                      ),
                    ),
                    textTheme: TextTheme(
                      headline2: TextStyle(
                        fontSize: 28.0,
                        color: Colors.black,
                      ),
                      headline5: TextStyle(
                        fontSize: 24.0,
                        color: Colors.black,
                      ),
                      bodyText2: TextStyle(
                        fontSize: 18.0,
                        color: Colors.black,
                      ),
                      subtitle1: TextStyle(
                        fontSize: 18.0,
                        color: Colors.black,
                      ),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      labelStyle: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  surveyProgressbarConfiguration: SurveyProgressConfiguration(
                    backgroundColor: Colors.white,
                  ),
                  surveyController: surveyController,
                );
              }
              return CircularProgressIndicator.adaptive();
            },
          ),
        ));
  }

  @override
  void dispose() {
    _canProcess = false;
    super.dispose();
  }
}
