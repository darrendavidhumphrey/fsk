// TODO: Implement this
/*
import 'package:flutter/cupertino.dart';

import 'multiple_scene_example.dart';

// The example scenes are placed in an IndexedStackScene that corresponds
// with the IndexedStack flutter widget to draw only one example scene
// at a time.
class ExtendedExampleScenes extends StatefulWidget {
  final int extendedSceneIndex;
  final bool isPaused;
  const ExtendedExampleScenes({super.key, required this.extendedSceneIndex, required this.isPaused});
  @override
  ExtendedExampleScenesState createState() => ExtendedExampleScenesState();

  static List<String> menuLabels = [
    'Multiple Scenes',
        'Second Scene',
    'Third Scene',
  ];
}

class ExtendedExampleScenesState extends State<ExtendedExampleScenes> {

  bool _scenesPaused = false;

  @override
  void initState() {
    super.initState();
    // 2. Set initial pause status based on widget's active assignment
    _scenesPaused = widget.isPaused;
  }

  @override
  void didUpdateWidget(covariant ExtendedExampleScenes oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 3. Monitor if parent tracking toggles execution states
    if (oldWidget.isPaused != widget.isPaused) {
      setState(() {
        _scenesPaused = widget.isPaused;
      });
    }
  }

  bool isPaused(int index) {
    return _scenesPaused && (index != widget.extendedSceneIndex);
  }

  @override
  Widget build(BuildContext context) {

    return IndexedStack(
        index: widget.extendedSceneIndex,
        children: [
          MultipleSceneExample(isPaused: isPaused(0)),
          Center(child: Text('Second Scene')),
          Center(child: Text('Third Scene')),
        ],
    );
  }

}


 */