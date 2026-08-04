import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk_examples/cad_canvas_scene.dart';
import 'package:fsk_examples/checkerboard_scene.dart';
import 'package:fsk_examples/animated_checkerboard_scene.dart';
import 'package:fsk_examples/scene_from_xml.dart';
import 'package:fsk_examples/obj_model_scene.dart';
import 'package:fsk_examples/pbr_model_scene.dart';
import 'fsk_visual_test_harness.dart';

/// A deterministic version of the animated scene for visual testing.
class DeterministicAnimatedCheckerBoardScene extends AnimatedCheckerBoardScene {
  DeterministicAnimatedCheckerBoardScene({super.navigationDelegate});

  @override
  void rebuildGeometry() {
    if (!isReady) return;
    
    // We strictly control the uniforms here and DON'T call super.rebuildGeometry()
    // because that would invoke the time-based animation logic.
    useBoxFitLayout = false;
    final uniforms = checkerQuad!.uniforms as CheckerBoardUniforms;

    // Fixed values for visual snapshot stability
    uniforms.patternColor1 = const Color(0xFF0000FF); // Blue
    uniforms.patternColor2 = const Color(0xFFFFFF00); // Yellow
    uniforms.patternScale = 15.0;

    // Manually perform the work that FskFrameScene (the grandparent) would do:
    // rebuild geometry for all root nodes.
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
  }
}

/// A deterministic version of the XML scene for visual testing.
class DeterministicSceneFromXml extends SceneFromXml {
  DeterministicSceneFromXml({super.navigationDelegate});

  @override
  void rebuildGeometry() {
    if (!isReady) return;
    
    // Set a static frame count string
    frameCountText?.text = "Frames: STATIC";

    // Bypass the frame-based increment logic in SceneFromXml.rebuildGeometry
    // and just perform standard scene graph updates.
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
  }
}

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
    testWidgets('Capture: CheckerBoardScene', (tester) async {
      final scene = CheckerBoardScene(
        navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(tester, 'checkerboard_scene', scene);
    });

    testWidgets('Capture: AnimatedCheckerBoardScene', (tester) async {
      final scene = DeterministicAnimatedCheckerBoardScene(
        navigationDelegate: StaticViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(
        tester, 
        'animated_checkerboard_scene', 
        scene,
      );
    });

    testWidgets('Capture: OrbitViewScene', (tester) async {
      final scene = CADCanvasScene(
        navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(tester, 'orbitview_scene', scene);
    });

    testWidgets('Capture: SceneFromXml', (tester) async {
      final scene = DeterministicSceneFromXml(
        navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(
        tester, 
        'scene_from_xml', 
        scene,
      );
    });

    testWidgets('Capture: ObjModelScene', (tester) async {
      final scene = ObjModelScene(
        navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(tester, 'obj_model_scene', scene);
    });

    testWidgets('Capture: PbrModelScene', (tester) async {
      final scene = PbrModelScene(
        navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
      );
      await FskVisualTestHarness.runSceneTest(tester, 'pbr_model_scene', scene);
    });
  });

  /// Pass 2: Compare results against the golden directory.
  /// This happens after all captures have been finalized.
  tearDownAll(() async {
    await FskVisualTestHarness.compareResults();
  });
}
