import 'package:flutter/services.dart';
import 'package:fsg/fsg.dart';
import 'package:flutter/material.dart';
import 'package:fsg_examples/indexed_scene.dart';

void main() async {
  Logging.brevity = Brevity.detailed;
  Logging.defaultLogLevel = LogLevel.pedantic;
  Logging.setConsoleLogFunction((String message) {
    print(message);
  });

  WidgetsFlutterBinding.ensureInitialized();
  FSG().initPlatformState();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(TestApp());
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  TestAppState createState() => TestAppState();
}

class TestAppState extends State<TestApp> {
  int _pageIndex = 0;
  late IndexedScene scene;

  @override
  void initState() {
    super.initState();
    scene = IndexedScene();
    FSG().registerSceneAndAllocateTexture(scene);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FSG Examples',
     // showPerformanceOverlay: true,
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  InteractiveRenderToTexture(scene: scene.currentScene(), navigationDelegate: scene.currentDelegate(),automaticallyPause: false,),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: const EdgeInsets.only(top:8.0,left:8.0,right:8.0),
                        child: DropdownMenu<int>(
                          width: constraints.maxWidth,
                          initialSelection: _pageIndex,
                          label: const Text('Select Example'),
                          // onSelected is called when the user picks an item
                          onSelected: (int? value) {
                            setState(() {
                              _pageIndex = value!;
                              scene.setSceneIndex(_pageIndex);
                            });
                          },
                          // Define the entries in the menu
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(
                              value: 0,
                              label: 'Example 1: Hello World',
                            ),
                            DropdownMenuEntry(value: 1, label: 'Example 2: Animated Shader Uniforms'),
                            DropdownMenuEntry(value: 2, label: 'Example 3: Navigation Delegate (Orbit View)'),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
