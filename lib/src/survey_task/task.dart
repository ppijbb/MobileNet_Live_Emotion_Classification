import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:survey_kit/survey_kit.dart';
import 'package:survey_kit/src/steps/step.dart' as surveystep;

Future<Task> getSampleTask() {
  var task = NavigableTask(
    id: TaskIdentifier(),
    steps: mindScale([
      InstructionStep(
        title: 'Welcome to the\nQuickBird Studios\nHealth Survey',
        text: 'Get ready for a bunch of super random questions!',
        buttonText: 'Let\'s go!',
      ),
      QuestionStep(
        title: 'How old are you?',
        answerFormat: IntegerAnswerFormat(
          defaultValue: 25,
          hint: 'Please enter your age',
        ),
        isOptional: true,
      ),
      QuestionStep(
        title: 'Medication?',
        text: 'Are you using any medication',
        answerFormat: BooleanAnswerFormat(
          positiveAnswer: 'Yes',
          negativeAnswer: 'No',
          result: BooleanResult.POSITIVE,
        ),
      ),
      QuestionStep(
        title: 'Tell us about you',
        text: 'Tell us about yourself and why you want to improve your health.',
        answerFormat: TextAnswerFormat(
          maxLines: 5,
          validationRegEx: "^(?!\s*\$).+",
        ),
      ),
      QuestionStep(
        title: 'Select your body type',
        answerFormat: ScaleAnswerFormat(
          step: 1,
          minimumValue: 1,
          maximumValue: 5,
          defaultValue: 3,
          minimumValueDescription: '1',
          maximumValueDescription: '5',
        ),
      ),
      QuestionStep(
        title: 'Known allergies',
        text: 'Do you have any allergies that we should be aware of?',
        isOptional: false,
        answerFormat: MultipleChoiceAnswerFormat(
          textChoices: [
            TextChoice(text: 'Penicillin', value: 'Penicillin'),
            TextChoice(text: 'Latex', value: 'Latex'),
            TextChoice(text: 'Pet', value: 'Pet'),
            TextChoice(text: 'Pollen', value: 'Pollen'),
          ],
        ),
      ),
      QuestionStep(
        title: 'Done?',
        text: 'We are done, do you mind to tell us more about yourself?',
        isOptional: true,
        answerFormat: SingleChoiceAnswerFormat(
          textChoices: [
            TextChoice(text: 'Yes', value: 'Yes'),
            TextChoice(text: 'No', value: 'No'),
          ],
          defaultSelection: TextChoice(text: 'No', value: 'No'),
        ),
      ),
      QuestionStep(
        title: 'When did you wake up?',
        answerFormat: TimeAnswerFormat(
          defaultValue: TimeOfDay(
            hour: 12,
            minute: 0,
          ),
        ),
      ),
      QuestionStep(
        title: 'When was your last holiday?',
        answerFormat: DateAnswerFormat(
          minDate: DateTime.utc(1970),
          defaultDate: DateTime.now(),
          maxDate: DateTime.now(),
        ),
      ),
      // CompletionStep(
      //   stepIdentifier: StepIdentifier(id: '321'),
      //   text: 'Thanks for taking the survey, we will contact you soon!',
      //   title: 'Done!',
      //   buttonText: 'Submit survey',
      // ),
    ]),
  );
  task.addNavigationRule(
    forTriggerStepIdentifier: task.steps[6].stepIdentifier,
    navigationRule: ConditionalNavigationRule(
      resultToStepIdentifierMapper: (input) {
        switch (input) {
          case "Yes":
            return task.steps[0].stepIdentifier;
          case "No":
            return task.steps[7].stepIdentifier;
          default:
            return null;
        }
      },
    ),
  );
  return Future.value(task);
}

Future<Task> getJsonTask() async {
  final taskJson = await rootBundle.loadString('assets/example_json.json');
  final taskMap = json.decode(taskJson);

  return Task.fromJson(taskMap);
}

final SurveyController surveyController =
    SurveyController(onNextStep: ((context, resultFunction) {
  FocusScope.of(context).unfocus();
  BlocProvider.of<SurveyPresenter>(context).add(
    NextStep(resultFunction.call()),
  );
}));




mindScale(result) {
  // final List result = List.empty(growable: true);
  List<int> test = [1, 2, 3];
  test.forEach((item) {
    result.add(QuestionStep(
      title: '$item Known allergies',
      text: '$item Do you have any allergies that we should be aware of?',
      isOptional: false,
      answerFormat: MultipleChoiceAnswerFormat(
        textChoices: [
          TextChoice(text: '$item Penicillin', value: 'Penicillin'),
          TextChoice(text: '$item Latex', value: 'Latex'),
          TextChoice(text: '$item Pet', value: 'Pet'),
          TextChoice(text: '$item Pollen', value: 'Pollen'),
        ],
      ),
    ));
  });
  result.add(
    CompletionStep(
      stepIdentifier: StepIdentifier(id: '322'),
      text: '설문 완료!',
      title: '테스트 종료!',
      buttonText: 'Submit survey',
    ),
  );
  return result;
}
