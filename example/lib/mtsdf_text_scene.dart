import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

class MtsdfTextScene extends FskScene {
  MtsdfTextScene({super.navigationDelegate}) : super(clearColor: const Color(0xFF202040)) {
    skinSize = const Size(1000, 1000);
  }

  @override
  Future<void> onInit() async {
    await super.onInit();
    
    logInfo("MtsdfTextScene.onInit: Loading font...");

    // 1. Load the MTSDF font
    await FontManager().createFontFromFile(
      "isocpeur-mtsdf",
      "Isocpeur-mtsdf.xml",
      "Isocpeur-mtsdf.png",
      generateMipmaps: true,
    );

    final font = FontManager().getFont("isocpeur-mtsdf");
    if (font == null) {
      logError("MtsdfTextScene.onInit: Failed to load isocpeur-mtsdf font");
      return;
    }
    
    logInfo("MtsdfTextScene.onInit: Font loaded. texture isInitialized: ${font.isInitialized}");

    // 2. Add some random text objects
    final random = math.Random(12345); // Deterministic random
    final words = ["FLUTTER", "GPU", "MTSDF", "FSK", "ENGINE", "TEXT", "GLOW", "SHARP"];

    for (int i = 0; i < 10; i++) {
      final textStr = List.generate(3, (_) => words[random.nextInt(words.length)]).join(" ");
      final x = 0.0;
      final y = 400.0 - i * 80.0;
      final color = Color.fromARGB(
        255,
        150 + random.nextInt(105),
        150 + random.nextInt(105),
        150 + random.nextInt(105),
      );

      final text = FskMtsdfText(
        "text_$i",
        this,
        ReferenceBox.fromCenterSize(vm.Vector3(x, y, 0), const Size(800, 100)),
        font: font,
        text: textStr,
        textColor: color,
        glowColor: Colors.blue.withValues(alpha: 0.5),
        glowSize: 0.05,
        horizontalJustification: TextHorizontalJustification.center,
        verticalJustification: TextVerticalJustification.center,
      );
      addNode(text);
      text.rebuildGeometry();
      logInfo("Added text node: text_$i ('$textStr') at ($x, $y)");
    }
    
    setNeedsUpdate();
  }
}
