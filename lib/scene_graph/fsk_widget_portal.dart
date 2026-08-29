import 'package:flutter/material.dart';

/// A class representing a Flutter widget that needs to be rendered offscreen
/// for use as a texture in a 3D scene.
class FskWidgetPortal {
  final GlobalKey repaintKey;
  final Widget widget;
  final Size size;
  final VoidCallback onRepaint;

  FskWidgetPortal({
    required this.repaintKey,
    required this.widget,
    required this.size,
    required this.onRepaint,
  });
}
