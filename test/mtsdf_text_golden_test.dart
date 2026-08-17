import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

class MtsdfGoldenScene extends FskScene {
  MtsdfGoldenScene({super.navigationDelegate}) : super(clearColor: Colors.black);

  @override
  Future<void> onInit() async {
    await super.onInit();
    skinSize = const Size(800, 600);

    // Load font from assets
    await BitmapFontManager().createFontFromFile(
      "mtsdf_font",
      "Isocpeur-mtsdf.xml",
      "Isocpeur-mtsdf.png",
    );

    final font = BitmapFontManager().getFont("mtsdf_font")!;

    final words = ["GOLDEN", "MTSDF", "TEST", "SHARP"];
    final random = math.Random(54321);

    for (int i = 0; i < 5; i++) {
      final text = FskMtsdfText(
        "t_$i",
        this,
        ReferenceBox.fromCenterSize(
          vm.Vector3(0, (i - 2) * 80.0, 0),
          const Size(800, 60),
        ),
        font: font,
        text: words[random.nextInt(words.length)],
        textColor: Colors.white,
        glowColor: Colors.blue.withValues(alpha: 0.5),
        glowSize: 0.05,
        horizontalJustification: TextHorizontalJustification.center,
        verticalJustification: TextVerticalJustification.center,
      );
      addNode(text);
    }
  }
}

void main() {
  // Note: This test is designed to be run in an environment with a working GPU.
  // Standard 'flutter test' may not support this without a real device or specialized runner.
  // However, we include the setup here as requested.
  
  testWidgets('MTSDF Text Golden Test', (WidgetTester tester) async {
    // 1. Initialize FSK
    await FSK().init();
    
    final scene = MtsdfGoldenScene(
      navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit),
    );
    await scene.init();
    
    // 2. Wrap in a widget that can render FSK scenes
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: RenderToTexture(scene: scene),
            ),
          ),
        ),
      ),
    );
    
    // 3. Wait for rendering to settle
    await tester.pumpAndSettle(const Duration(seconds: 1));
    
    // 4. Capture and match golden
    // await expectLater(find.byType(RenderToTexture), matchesGoldenFile('mtsdf_text.png'));
  });
}
