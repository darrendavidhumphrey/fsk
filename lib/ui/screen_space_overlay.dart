import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import '../fsk_singleton.dart';
import '../logging.dart';
import '../fsk_scene_layer.dart';

/// An abstract base class for a [FskSceneLayer] that is rendered in 2D screen space
/// rather than 3D world space.
///
/// This class manages the positioning and scissoring required to create a 2D
/// overlay on top of the main 3D scene. The position is defined by anchoring
/// the overlay to one vertical edge (top or bottom) and one horizontal edge
/// (left or right) of the parent viewport.
abstract class ScreenSpaceOverlay extends FskSceneLayer with LoggableClass {
  /// The total size of the render-to-texture target. This is used to convert
  /// screen pixels to texture pixels for GL operations like `scissor` and `viewport`.
  final double textureSize;

  /// The distance in screen pixels from the top edge of the parent viewport.
  /// Must be provided if [bottom] is null.
  final double? top;

  /// The distance in screen pixels from the left edge of the parent viewport.
  /// Must be provided if [right] is null.
  final double? left;

  /// The distance in screen pixels from the right edge of the parent viewport.
  /// Must be provided if [left] is null.
  final double? right;

  /// The distance in screen pixels from the bottom edge of the parent viewport.
  /// Must be provided if [top] is null.
  final double? bottom;

  /// The size of the overlay in screen-space pixels.
  final Size screenSpaceSize;

  late GlStateManager gls;

  /// Creates a screen-space overlay.
  ///
  /// An overlay must be anchored by providing either [top] or [bottom], and
  /// either [left] or [right], but not both in the same axis.
  ScreenSpaceOverlay({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.screenSpaceSize,
    required this.textureSize,
  }) {
    // Use XOR to assert that exactly one horizontal and one vertical anchor is set.
    assert((left == null) != (right == null),
        'Must provide either left or right, but not both.');
    assert((top == null) != (bottom == null),
        'Must provide either top or bottom, but not both.');
    gls = FSK().glStateManager;
  }

  /// Calculates the top-left corner of this overlay within the parent viewport.
  Offset get _topLeftInViewport {
    final double x = left ?? (viewportSize.width - screenSpaceSize.width - right!);
    final double y = top ?? (viewportSize.height - screenSpaceSize.height - bottom!);
    return Offset(x, y);
  }

  /// Converts a global screen coordinate into a local coordinate within this overlay.
  Offset screenToViewport(Offset screen) {
    final origin = _topLeftInViewport;
    return screen - origin;
  }

  /// Checks if a global screen coordinate is within the bounds of this overlay.
  bool isPointInViewport(Offset point) {
    final viewportRelative = screenToViewport(point);
    // Check against the overlay's own size, not the parent's viewportSize.
    return viewportRelative.dx >= 0 &&
        viewportRelative.dx <= screenSpaceSize.width &&
        viewportRelative.dy >= 0 &&
        viewportRelative.dy <= screenSpaceSize.height;
  }

  /// Converts a horizontal value from screen space to texture space.
  double textureToScreenX(double x) {
    return (x / viewportSize.width.toDouble()) * textureSize;
  }

  /// Converts a vertical value from screen space to texture space.
  double textureToScreenY(double y) {
    return (y / viewportSize.height.toDouble()) * textureSize;
  }

  /// Enables scissoring and sets the GL viewport to the bounds of this overlay.
  ///
  /// This is called before drawing the overlay to ensure it only renders within
  /// its designated rectangular area, clipping any content that would draw
  /// outside of it.
  void enableScissor() {
    final origin = _topLeftInViewport;
    final startX = textureToScreenX(origin.dx);
    final startY = textureToScreenY(origin.dy);
    final windowWidth = textureToScreenX(screenSpaceSize.width);
    final windowHeight = textureToScreenY(screenSpaceSize.height);

    gls.scissorEnabled(true);

    gl.scissor(
      startX.toInt(),
      startY.toInt(),
      windowWidth.toInt(),
      windowHeight.toInt(),
    );
    gls.setViewport(
      startX.toInt(),
      startY.toInt(),
      windowWidth.toInt(),
      windowHeight.toInt(),
    );
  }
}
