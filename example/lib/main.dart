import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fsk/fsk.dart';
import 'package:flutter/material.dart';
import 'package:fsk_examples/checkerboard_scene.dart';
import 'package:fsk_examples/frame_scene_example.dart';
import 'package:fsk_examples/orbitview_scene.dart';
import 'package:fsk_examples/positioned_title_bar.dart';
import 'animated_checkerboard_scene.dart';


void main() async {
  Logging.brevity = Brevity.detailed;
  Logging.defaultLogLevel = LogLevel.pedantic;
  if (!kDebugMode) {
    Logging.setConsoleLogFunction(null);
  }

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(TestApp());
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  TestAppState createState() => TestAppState();
}

class TestAppState extends State<TestApp> {
  int _pageIndex = 0;
  String _titleText = "";

  final List<String> menuLabels = [
    "Checkerboard (Ortho View)",
    "Animated Checkerboard (Perspective View)",
    "OrbitView (Grid Shader)",
    "Bitmap Text (Ortho View)"
  ];
  final List<FskScene> scenes = [];


  void makeExamples() {
    scenes.add(CheckerBoardScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit)));
    scenes.add(AnimatedCheckerBoardScene(navigationDelegate: StaticViewDelegate(boxFit: FskBoxFit.bestFit)));
    scenes.add(OrbitViewScene(navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit)));
    scenes.add(FrameSceneExample(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit)));
  }

  @override
  void initState() {
    super.initState();

    FSK().init().then((_) {
      makeExamples();

      setState(() {
        _pageIndex = 0;
        _setTitleText();
      });
    });
  }

  void _setTitleText() {
    _titleText = "Example ${_pageIndex + 1}: ${menuLabels[_pageIndex]}";
  }

  // Helper method to update the active scene index safely
  void _chooseExample(int newIndex) {
    // Previous and Next buttons wrap around
    if (newIndex >= menuLabels.length) {
      newIndex = 0;
    } else if (newIndex < 0) {
      newIndex = menuLabels.length - 1;
    }

    setState(() {
      _pageIndex = newIndex;
      _setTitleText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: MaterialApp(
            title: 'FSK Examples',
            //showPerformanceOverlay: true,
            home: Scaffold(
              backgroundColor: kIsWeb ? Colors.transparent : null,
              body: Stack(
                children: [
                  RenderToTexture(scene: scenes[_pageIndex],useAntiAliasing:false,),

                  // Title text widget
                  PositionedTitleBar(titleText: _titleText),

                  // Previous Button (Bottom Left)
                  Positioned(
                    bottom: 16.0,
                    left: 16.0,
                    child: FloatingActionButton.extended(
                      onPressed: () => _chooseExample(_pageIndex - 1),
                      label: const Text('Previous'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),

                  // Next Button (Bottom Right)
                  Positioned(
                    bottom: 16.0,
                    right: 16.0,
                    child: FloatingActionButton.extended(
                      onPressed: () => _chooseExample(_pageIndex + 1),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Next'),
                          SizedBox(
                            width: 8.0,
                          ), // Adds spacing between text and icon
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
