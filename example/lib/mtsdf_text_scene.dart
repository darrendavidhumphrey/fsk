import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

class MtsdfTextScene extends FskScene {
  MtsdfTextScene({super.navigationDelegate}) : super(clearColor: const Color(0xFF0A0A1A)) {
    // Use the full 1080p target resolution
    skinSize = const Size(1920, 1080);
  }

  @override
  Future<void> onInit() async {
    await super.onInit();
    
    logInfo("MtsdfTextScene.onInit: Loading font...");

    // 1. Load the MTSDF font
    // NOTE: generateMipmaps is disabled to prevent distance field corruption on small scales.
    await FontManager().createFontFromFile(
      "isocpeur-mtsdf",
      "Isocpeur-mtsdf.xml",
      "Isocpeur-mtsdf.png",
      generateMipmaps: false,
    );

    final font = FontManager().getFont("isocpeur-mtsdf");
    if (font == null) {
      logError("MtsdfTextScene.onInit: Failed to load isocpeur-mtsdf font");
      return;
    }
    
    logInfo("MtsdfTextScene.onInit: Font loaded. texture isInitialized: ${font.isInitialized}");

    // 2. Add text objects in a grid to fill the 1920x1080 space
    const int cols = 4;
    const int rows = 5;
    const double margin = 150.0;
    final double colSpacing = (skinSize.width - 2 * margin) / (cols - 1);
    final double rowSpacing = (skinSize.height - 2 * margin) / (rows - 1);

    final random = math.Random(54321); // Deterministic random
    final words = ["FLUTTER", "GPU", "MTSDF", "FSK", "ENGINE", "TEXT", "GLOW", "SHARP"];

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final int index = i * cols + j;
        final double x = margin + j * colSpacing;
        final double y = margin + i * rowSpacing;

        final textStr = words[random.nextInt(words.length)];
        final color = Colors.primaries[index % Colors.primaries.length];
        
        // Vary rotation to exercise different parameters
        final double rotation = (random.nextDouble() - 0.5) * 0.4;
        final double scale = 0.8 + random.nextDouble() * 0.6;

        final textNode = FskFlutterText(
          "text_$index",
          this,
          ReferenceBox.fromCenterSize(vm.Vector3(x, y, 0), const Size(400, 100)),
          text: textStr,
          textColor: color,
          style: const TextStyle(
            fontFamily: 'isocpeur',
            fontSize: 60,
            fontWeight: FontWeight.bold,
          ),
          horizontalJustification: TextHorizontalJustification.center,
          verticalJustification: TextVerticalJustification.center,
        );
        
        textNode.transformable.rotation = vm.Vector3(0, 0, rotation);
        textNode.transformable.scale = vm.Vector3(scale, scale, 1.0);
        
        addNode(textNode);
      }
    }
    
    setNeedsUpdate();
  }
}
