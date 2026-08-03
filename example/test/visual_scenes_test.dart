import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk_examples/scene_from_xml.dart';
import 'package:fsk_examples/obj_model_scene.dart';
import 'fsk_visual_test_harness.dart';

void main() {
  /// The global FSK context must be initialized before any scenes can be built.
  setUpAll(() async {
    // Standard Flutter test environment initialization
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize FSK engine
    await FSK().init();
    
    // Prepare the test output directories
    await FskVisualTestHarness.setup();
  });

  group('Visual Scene Capture', () {
    testWidgets('Capture: SceneFromXml', (tester) async {
      final scene = SceneFromXml(
        navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      
      await FskVisualTestHarness.runSceneTest(
        tester, 
        'scene_from_xml', 
        scene,
        initParams: (s) {
          // You can supply additional initialization parameters here if needed
          s.clearColor = Colors.blueGrey;
        },
      );
    });

    testWidgets('Capture: ObjModelScene', (tester) async {
      final scene = ObjModelScene(
        navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      
      await FskVisualTestHarness.runSceneTest(tester, 'obj_model_scene', scene);
    });
  });

  /// Pass 2: Compare results against the golden directory.
  /// This happens after all captures have been finalized.
  tearDownAll(() async {
    await FskVisualTestHarness.compareResults();
  });
}
