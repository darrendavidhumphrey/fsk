import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

class TransformationTestScene extends FskScene {
  TransformationTestScene({super.navigationDelegate}) : super(clearColor: const Color(0xFF050505));

  @override
  Future<void> onInit() async {
    await super.onInit();
    // Use the full 1080p target resolution used by the Visual Test Runner
    skinSize = const Size(1920, 1080);

    const int cols = 8;
    const int rows = 6;
    
    // Calculate spacing to fill the 1920x1080 space with margins
    const double margin = 100.0;
    final double colSpacing = (skinSize.width - 2 * margin) / (cols - 1);
    final double rowSpacing = (skinSize.height - 2 * margin) / (rows - 1);
    
    // Skin coordinates: (0,0) is bottom-left, (1920, 1080) is top-right
    const double startX = margin;
    const double startY = margin;

    final font = FontManager().defaultFont;

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final int index = i * cols + j;
        final double x = startX + j * colSpacing;
        final double y = startY + i * rowSpacing; // Y-up grid
        final vm.Vector3 basePos = vm.Vector3(x, y, 0);

        _addConfiguredCase(index, basePos, font);
      }
    }
  }

  void _addConfiguredCase(int index, vm.Vector3 basePos, TextureFont? font) {
    final String id = "case_$index";
    final Color color = Colors.primaries[index % Colors.primaries.length];
    
    switch (index) {
      // --- Row 0: Fundamentals ---
      case 0: // Pure Translate
        _addQuad(id, color).position = basePos;
        break;
      case 1: // Pure Rotate (45 deg)
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(0, 0, math.pi / 4);
        break;
      case 2: // Pure Scale (Stretch X)
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(2.0, 0.5, 1.0);
        break;
      case 3: // Pure Scale (Stretch Y)
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(0.5, 2.0, 1.0);
        break;
      case 4: // Translate + Rotate
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(0, 0, math.pi / 6);
        break;
      case 5: // Translate + Scale
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(1.5, 1.5, 1.0);
        break;
      case 6: // Scale + Rotate
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(1.2, 1.2, 1.0)..rotation = vm.Vector3(0, 0, math.pi / 8);
        break;
      case 7: // Negative Scale (Flip X)
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(-1.0, 1.0, 1.0);
        break;

      // --- Row 1: TRS & Anchor ---
      case 8: // Full TRS
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(0, 0, -math.pi / 4)..scale = vm.Vector3(0.8, 0.8, 1.0);
        break;
      case 9: // Anchor (Top-Right) + Rotate
        _addQuad(id, color)..position = basePos..anchor = vm.Vector3(-30, -30, 0)..rotation = vm.Vector3(0, 0, math.pi / 4);
        break;
      case 10: // Anchor (Bottom-Left) + Scale
        _addQuad(id, color)..position = basePos..anchor = vm.Vector3(30, 30, 0)..scale = vm.Vector3(2.0, 0.5, 1.0);
        break;
      case 11: // Anchor + Translate + Rotate
        _addQuad(id, color)..position = basePos + vm.Vector3(40, 0, 0)..anchor = vm.Vector3(0, 30, 0)..rotation = vm.Vector3(0, 0, math.pi / 2);
        break;
      case 12: // Extreme Scale + Rotate
        _addQuad(id, color)..position = basePos..scale = vm.Vector3(0.1, 4.0, 1.0)..rotation = vm.Vector3(0, 0, math.pi / 3);
        break;
      case 13: // 3D Rotation (X-axis)
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(math.pi / 3, 0, 0);
        break;
      case 14: // 3D Rotation (Y-axis)
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(0, math.pi / 3, 0);
        break;
      case 15: // Complex 3D Rotation
        _addQuad(id, color)..position = basePos..rotation = vm.Vector3(0.5, 0.5, 0.5);
        break;

      // --- Row 2: Simple Nesting ---
      case 16: // Group T -> Child R
        final g = _addGroup(id, basePos);
        g.addNode(_createQuad("${id}_c", color)..rotation = vm.Vector3(0, 0, math.pi / 4));
        break;
      case 17: // Group R -> Child T
        final g = _addGroup(id, basePos)..rotation = vm.Vector3(0, 0, math.pi / 4);
        g.addNode(_createQuad("${id}_c", color)..position = vm.Vector3(40, 0, 0));
        break;
      case 18: // Group S -> Child T
        final g = _addGroup(id, basePos)..scale = vm.Vector3(0.5, 2.0, 1.0);
        g.addNode(_createQuad("${id}_c", color)..position = vm.Vector3(30, 0, 0));
        break;
      case 19: // Group T -> Child S
        final g = _addGroup(id, basePos);
        g.addNode(_createQuad("${id}_c", color)..scale = vm.Vector3(2.0, 0.5, 1.0));
        break;
      case 20: // Group R -> Child S
        final g = _addGroup(id, basePos)..rotation = vm.Vector3(0, 0, math.pi / 8);
        g.addNode(_createQuad("${id}_c", color)..scale = vm.Vector3(1.5, 1.5, 1.0));
        break;
      case 21: // Group S -> Child R
        final g = _addGroup(id, basePos)..scale = vm.Vector3(2.0, 0.5, 1.0);
        g.addNode(_createQuad("${id}_c", color)..rotation = vm.Vector3(0, 0, math.pi / 4));
        break;
      case 22: // Nested Flip: Group X-Flip -> Child Rotate
        final g = _addGroup(id, basePos)..scale = vm.Vector3(-1.0, 1.0, 1.0);
        g.addNode(_createQuad("${id}_c", color)..rotation = vm.Vector3(0, 0, 0.5));
        break;
      case 23: // Nested Flip: Group Y-Flip -> Child Scale
        final g = _addGroup(id, basePos)..scale = vm.Vector3(1.0, -1.0, 1.0);
        g.addNode(_createQuad("${id}_c", color)..scale = vm.Vector3(0.5, 2.0, 1.0));
        break;

      // --- Row 3: Complex Nesting & Orbits ---
      case 24: // Group TRS -> Child TRS
        final g = _addGroup(id, basePos)..rotation = vm.Vector3(0, 0, math.pi/6)..scale = vm.Vector3(0.7, 0.7, 1.0);
        g.addNode(_createQuad("${id}_c", color)..position = vm.Vector3(30, 30, 0)..rotation = vm.Vector3(0, 0, math.pi/4)..scale = vm.Vector3(1.5, 1.5, 1.0));
        break;
      case 25: // Multi-child Group (Square Orbit)
        final g = _addGroup(id, basePos)..rotation = vm.Vector3(0, 0, math.pi / 8);
        for (int k = 0; k < 4; k++) {
          g.addNode(_createQuad("${id}_$k", color.withValues(alpha: 0.7))
            ..position = vm.Vector3(math.cos(k * math.pi / 2) * 50, math.sin(k * math.pi / 2) * 50, 0)
            ..scale = vm.Vector3(0.5, 0.5, 1.0));
        }
        break;
      case 26: // Group Anchor (Pivot Rotate)
        final g = _addGroup(id, basePos)..anchor = vm.Vector3(60, 0, 0)..rotation = vm.Vector3(0, 0, math.pi / 2);
        g.addNode(_createQuad("${id}_c", color));
        break;
      case 27: // Skew Attempt (Scale X -> Rotate 45 -> Scale back)
        final g1 = _addGroup(id, basePos)..scale = vm.Vector3(2.0, 1.0, 1.0);
        final g2 = FskGroup("${id}_g2", this)..rotation = vm.Vector3(0, 0, math.pi / 4);
        g2.addNode(_createQuad("${id}_c", color)..scale = vm.Vector3(0.5, 1.0, 1.0));
        g1.addNode(g2);
        break;
      case 28: // Deep Fractal-like Chain (6 levels)
        FskGroup parent = _addGroup(id, basePos);
        for(int k=0; k<5; k++) {
           final childG = FskGroup("${id}_g$k", this)..position = vm.Vector3(25, 10, 0)..rotation = vm.Vector3(0, 0, 0.2)..scale = vm.Vector3(0.85, 0.85, 1.0);
           parent.addNode(childG);
           parent = childG;
        }
        parent.addNode(_createQuad("${id}_leaf", color));
        break;
      case 29: // Spiral Nesting
        FskGroup parent = _addGroup(id, basePos);
        for(int k=0; k<12; k++) {
           final childG = FskGroup("${id}_g$k", this)..position = vm.Vector3(10, 0, 0)..rotation = vm.Vector3(0, 0, 0.4);
           final q = _createQuad("${id}_q$k", color.withValues(alpha: 1.0 - k/15))..scale = vm.Vector3(0.2, 0.2, 1.0);
           childG.addNode(q);
           parent.addNode(childG);
           parent = childG;
        }
        break;
      case 30: // Double Group Scaling
        final p = _addGroup(id, basePos)..scale = vm.Vector3(0.5, 0.5, 1.0);
        final c = FskGroup("${id}_c", this)..scale = vm.Vector3(0.5, 0.5, 1.0);
        c.addNode(_createQuad("${id}_l", color)..scale = vm.Vector3(0.5, 0.5, 1.0));
        p.addNode(c);
        break;
      case 31: // Multi-anchor stack
        final g = _addGroup(id, basePos)..anchor = vm.Vector3(30, 0, 0)..rotation = vm.Vector3(0, 0, 0.5);
        final g2 = FskGroup("${id}_g2", this)..anchor = vm.Vector3(0, 30, 0)..rotation = vm.Vector3(0, 0, 0.5);
        g2.addNode(_createQuad("${id}_c", color));
        g.addNode(g2);
        break;

      // --- Row 4: Hierarchy Edge Cases ---
      case 32: // Zero Scale Parent -> Child Translate
        final g = _addGroup(id, basePos)..scale = vm.Vector3.zero();
        g.addNode(_createQuad("${id}_c", color)..position = vm.Vector3(100, 0, 0));
        break;
      case 33: // Parent Translate -> Child Scale-to-Fit (Implicitly testing logic)
        final g = _addGroup(id, basePos);
        g.addNode(_createQuad("${id}_c", color)..scale = vm.Vector3(5.0, 0.1, 1.0));
        break;
      case 34: // Floating Leaf (Deep parent offset)
        final g = _addGroup(id, basePos + vm.Vector3(500, 0, 0)); // Moves it way off, testing clipping/bounds
        g.addNode(_createQuad("${id}_c", color)..position = vm.Vector3(-500, 0, 0)); // Moves it back
        break;
      case 35: // Rotating Parent -> Offset Pivot Child
        final g = _addGroup(id, basePos)..rotation = vm.Vector3(0, 0, math.pi);
        g.addNode(_createQuad("${id}_c", color)..anchor = vm.Vector3(50, 50, 0)..rotation = vm.Vector3(0, 0, math.pi/4));
        break;

      // --- Row 5: Text & Mixed ---
      default:
        if (font != null) {
          final t = _addText(id, basePos, font, "CASE $index", color);
          if (index % 3 == 0) t.rotation = vm.Vector3(0, 0, 0.2);
          if (index % 4 == 0) t.scale = vm.Vector3(0.8, 1.2, 1.0);
        } else {
           _addQuad(id, color).position = basePos;
        }
        break;
    }
  }

  FskQuad _createQuad(String id, Color color) {
    return FskQuad(
      id,
      this,
      ReferenceBox.fromCenterSize(vm.Vector3.zero(), const Size(60, 60)),
      const Rect.fromLTWH(0, 0, 1, 1),
      modulateColor: color,
      textureId: FSK().textureManager.solidTextureId,
    );
  }

  FskQuad _addQuad(String id, Color color) {
    final q = _createQuad(id, color);
    addNode(q);
    return q;
  }

  FskGroup _addGroup(String id, vm.Vector3 pos) {
    final g = FskGroup(id, this);
    g.position = pos;
    addNode(g);
    return g;
  }

  FskFlutterText _addText(String id, vm.Vector3 pos, TextureFont font, String text, Color color) {
    final t = FskFlutterText(
      id,
      this,
      ReferenceBox.fromCenterSize(pos, const Size(180, 50)),
      text: text,
      textColor: color,
      style: const TextStyle(
        fontFamily: 'isocpeur',
        fontSize: 40,
        fontWeight: FontWeight.bold,
      ),
      horizontalJustification: TextHorizontalJustification.center,
      verticalJustification: TextVerticalJustification.center,
    );
    addNode(t);
    return t;
  }
}
