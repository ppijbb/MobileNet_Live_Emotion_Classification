import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:survey_kit/survey_kit.dart';
import 'package:survey_kit/src/steps/step.dart' as surveystep;

// class CustomResult extends QuestionResult<String> {
//     final String? customData;
//     final String? valueIdentifier;
//     final Identifier? identifier;
//     final DateTime startDate = DateTime.now();
//     final DateTime endDate  =  DateTime.now();
//     final String value; //Custom value

//     CustomResult({
//       bool isOptional = false,
//       this.startDate = startDate,
//       this.endDate = endDate,
//     }) : super(isOptional, startDate, endDate);

// }

// class CustomStep extends surveystep.Step {
//   final String title;
//   final String text;

//   CustomStep({
//     @required StepIdentifier id,
//     bool isOptional = false,
//     String buttonText = 'Next',
//     this.title,
//     this.text,
//   }) : super(isOptional, id, buttonText);

//   @override
//   Widget createView({@required QuestionResult questionResult}) {
//       return StepView(
//             step: widget.questionStep,
//             result: () => CustomResult(
//                 id: id,
//                 startDate: DateTime.now(),
//                 endDate: DateTime.now(),
//                 valueIdentifier: 'custom'//Identification for NavigableTask,
//                 result: 'custom_result',
//             ),
//             title: Text('Title'),
//             child: Container(), //Add your view here
//         );
//   }
// }