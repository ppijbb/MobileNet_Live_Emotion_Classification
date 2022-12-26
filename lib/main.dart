import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live_emotion/src/home.dart';
import 'package:flutter_live_emotion/src/cbcl.dart';
import 'package:flutter_live_emotion/src/webview.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription>? cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.microphone.request();
  cameras = await availableCameras();
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primaryColor: Colors.deepPurple),
      debugShowCheckedModeBanner: false,
      home: HomeRouter(),
    );
  }
}

class HomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Google ML Kit Demo App'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ExpansionTile(
                    title: const Text('개발 중'),
                    children: [
                      CustomCard('문진테스트', CBCL()),
                      CustomCard('Face Detection', Home()),
                      CustomCard('WebView Test', InAppWebViewPage()),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  ExpansionTile(
                    title: const Text('임시 리스트'),
                    children: [
                      CustomCard('임시1', Home()),
                      CustomCard('임시2', Home()),
                      CustomCard('임시3', Home()),
                      CustomCard('임시4', Home()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final String _label;
  final Widget _viewPage;
  final bool featureCompleted;

  const CustomCard(this._label, this._viewPage, {this.featureCompleted = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).primaryColor,
        title: Text(
          _label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('This feature has not been implemented yet')));
          } else {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => _viewPage));
          }
        },
      ),
    );
  }
}
