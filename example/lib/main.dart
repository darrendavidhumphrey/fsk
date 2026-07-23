import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fsk/fsk.dart';
import 'package:flutter/material.dart';
import 'package:fsk_examples/example_scenes.dart';
import 'package:fsk_examples/positioned_title_bar.dart';

import 'extended_example_scenes.dart';

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
  int _extendedSceneIndex = 0;
  int _basicExampleSceneCount = 0;
  ExampleScenes? _exampleScenes;
  String _titleText = "";

  Future<void> initAngle(double dpr) async {
    // Initialize FSK. This call immediately sets FSK().state to inProgress
    await FSK().initPlatformState();

    // Create the example scenes and add them to the menu
    // These example scenes all draw a single FskScene
    _exampleScenes = ExampleScenes();
    menuLabels.addAll(_exampleScenes!.menuLabels);
    menuLabels.addAll(ExtendedExampleScenes.menuLabels);

    // Track the number of basic example scenes
    _basicExampleSceneCount = _exampleScenes!.menuLabels.length;

    // Register the scene and allocate a texture
    await FSK().registerSceneAndAllocateTexture(_exampleScenes!, dpr: dpr);

    // Trigger a rebuild of the widget
    setState(() {
      _exampleScenes!.setCurrentScene(0);
      _setTitleText();
    });
  }

  final List<String> menuLabels = [];
  bool _isExtendedScene = false;

  void _setTitleText() {
    _titleText = "Example ${_pageIndex + 1}: ${menuLabels[_pageIndex]}";
  }

  // Helper method to update the active scene index safely
  void _updateScene(int newIndex) {
    // Previous and Next buttons wrap around
    if (newIndex >= menuLabels.length) {
      newIndex = 0;
    } else if (newIndex < 0) {
      newIndex = menuLabels.length - 1;
    }

    setState(() {
      _isExtendedScene = newIndex >= _basicExampleSceneCount;
      _pageIndex = newIndex;
      if (_isExtendedScene) {
        _extendedSceneIndex = _pageIndex - _basicExampleSceneCount;
      } else {
        _exampleScenes!.setCurrentScene(_pageIndex);
      }
      _setTitleText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (FSK().state == FskState.uninitialized) {
          initAngle(MediaQuery.of(context).devicePixelRatio);
        }

        if (_exampleScenes == null) {
          return const CircularProgressIndicator();
        }

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
                  IndexedStack(
                    index: _isExtendedScene ? 1 : 0,
                    children: [
                      IndexedSceneViewer(scene: _exampleScenes!),
                      ExtendedExampleScenes(
                        extendedSceneIndex: _extendedSceneIndex,
                      ),
                    ],
                  ),

                  // Title text widget
                  PositionedTitleBar(titleText: _titleText),

                  // Previous Button (Bottom Left)
                  Positioned(
                    bottom: 16.0,
                    left: 16.0,
                    child: FloatingActionButton.extended(
                      onPressed: () => _updateScene(_pageIndex - 1),
                      label: const Text('Previous'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),

                  // Next Button (Bottom Right)
                  Positioned(
                    bottom: 16.0,
                    right: 16.0,
                    child: FloatingActionButton.extended(
                      onPressed: () => _updateScene(_pageIndex + 1),
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
