import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk_examples/checkerboard_scene.dart';
import 'package:fsk_examples/cad_canvas_scene.dart';
import 'fsk_visual_test_harness.dart';

void main() async {
  print('>>> main() start');
  TestWidgetsFlutterBinding.ensureInitialized();
  await FSK().init();
  print('>>> main() FSK init done');

  setUpAll(() async {
    print('>>> setUpAll() start');
    await FskVisualTestHarness.setup();
    print('>>> setUpAll() done');
  });

  group('Visual Scene Capture', () {
    testWidgets('Capture: CheckerBoardScene', (tester) async {
      await FskVisualTestHarness.runSceneTest(
        tester, 
        'checkerboard_scene', 
        () => CheckerBoardScene(
          navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit),
        ),
      );
    });

    testWidgets('Capture: CADCanvasScene', (tester) async {
      await FskVisualTestHarness.runSceneTest(
        tester,
        'cad_canvas_scene',
        () => CADCanvasScene(
          navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
        ),
      );
    });
  });
}
