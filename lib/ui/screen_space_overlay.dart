import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' hide Colors;

/// An abstract base class for a [FskSceneLayer] that is rendered in 2D screen space
/// rather than 3D world space.
///
/// This class manages the positioning and scissoring required to create a 2D
/// overlay on top of the main 3D scene. The position is defined by anchoring
/// the overlay to one vertical edge (top or bottom) and one horizontal edge
/// (left or right) of the parent viewport.
abstract class ScreenSpaceOverlay extends FskScene {
  /// The unique identifier for this overlay.
  final String id;

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

  /// Internal node used to draw the background clear color
  FskQuad? _backgroundNode;

  /// Tracks the parent viewport size from the last draw call for scissoring.
  Size _lastParentSize = Size.zero;

  /// Creates a screen-space overlay.
  ///
  /// An overlay must be anchored by providing either [top] or [bottom], and
  /// either [left] or [right], but not both in the same axis.
  ScreenSpaceOverlay({
    required this.id,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.screenSpaceSize,
    super.navigationDelegate,
    super.clearColor = const Color(0x40FFFFFF), // 25% white background
  }) {
    autoClear = false;
    navigationDelegate?.setViewRect(
        Rect.fromLTWH(0, 0, screenSpaceSize.width, screenSpaceSize.height));

    // Use XOR to assert that exactly one horizontal and one vertical anchor is set.
    assert((left == null) != (right == null),
        'Must provide either left or right, but not both.');
    assert((top == null) != (bottom == null),
        'Must provide either top or bottom, but not both.');
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients) {
    if (!isReady) return;

    _lastParentSize = viewportSize;
    final double physicalDpr = FSK.devicePixelRatio;

    // Use local size (converted to physical) for matrix calculations within the overlay
    viewportSize = Size(screenSpaceSize.width * physicalDpr,
        screenSpaceSize.height * physicalDpr);

    // Lazily create the background node if a clear color is specified
    if (clearColor.a > 0.0 && _backgroundNode == null) {
      _backgroundNode = FskQuad.centered(
        '${id}_bg',
        this,
        screenSpaceSize,
        modulateColor: clearColor,
        textureId: FSK().textureManager.solidTextureId,
      );
      _backgroundNode!.premultiplyAlpha = false;
      // Disable depth for background to ensure it always draws and doesn't write depth
      _backgroundNode!.setDepthState(
        depthTestEnabled: false,
        depthWriteEnabled: false,
        depthCompareOperation: gpu.CompareFunction.always,
      );
      _backgroundNode!.rebuildGeometry();
    } else if (clearColor.a == 0.0 && _backgroundNode != null) {
      _backgroundNode = null;
    }

    final origin = _calculateTopLeft(_lastParentSize);
    final double physicalWidth = screenSpaceSize.width * physicalDpr;
    final double physicalHeight = screenSpaceSize.height * physicalDpr;

    // 1. Clear depth and draw background if it exists
    if (_backgroundNode != null) {
      final Matrix4 bgP = Matrix4.identity();
      // Simple ortho mapping [-w/2, w/2] to [-1, 1]
      // Impeller NDC Y is -1 at top, 1 at bottom. World Y goes up.
      bgP.setEntry(0, 0, 2.0 / screenSpaceSize.width);
      bgP.setEntry(1, 1, 2.0 / screenSpaceSize.height); 
      bgP.setEntry(2, 2, 0.001); 
      bgP.setEntry(3, 3, 1.0);

      _drawNode(
        commandBuffer,
        renderTarget.loadColorClearDepthTarget, 
        transients,
        _backgroundNode!,
        origin.dx,
        origin.dy,
        physicalWidth,
        physicalHeight,
        bgP,
        Matrix4.identity(),
        screenSpaceSize,
      );
    } else {
        // Even if no background, we must clear depth before drawing overlay content
        // to ensure it draws on top of the main scene.
        final renderPass = commandBuffer.createRenderPass(renderTarget.loadColorClearDepthTarget);
        // Scissor to the overlay area anyway to be safe, though clearing depth is global
        renderPass.setScissor(gpu.Scissor(
            x: origin.dx.toInt(),
            y: origin.dy.toInt(),
            width: physicalWidth.toInt(),
            height: physicalHeight.toInt(),
        ));
    }

    // 2. Draw all child nodes via super (uses navigationDelegate matrices)
    // Note: FskScene.drawScene will iterate rootNodes and create RenderPasses with loadTarget.
    // Since we cleared the depth buffer in step 1, the teapot will now "win" against the helmet.
    super.drawScene(commandBuffer, renderTarget, transients);

    // Restore parent size for the next layer or main scene logic
    viewportSize = _lastParentSize;
  }

  @override
  void rebuildGeometry() {
    super.rebuildGeometry();
    _backgroundNode?.rebuildGeometry();
  }

  @override
  void setupScissor(gpu.RenderPass renderPass) {
    final origin = _calculateTopLeft(_lastParentSize);
    final double physicalDpr = FSK.devicePixelRatio;

    final double width = screenSpaceSize.width * physicalDpr;
    final double height = screenSpaceSize.height * physicalDpr;

    // Set up the Scissor box
    renderPass.setScissor(gpu.Scissor(
      x: origin.dx.toInt(),
      y: origin.dy.toInt(),
      width: width.toInt(),
      height: height.toInt(),
    ));

    // Set up the Viewport box
    renderPass.setViewport(gpu.Viewport(
      x: origin.dx.toInt(),
      y: origin.dy.toInt(),
      width: width.toInt(),
      height: height.toInt(),
    ));
  }

  /// Helper to draw a single node with correct scissor and viewport settings
  void _drawNode(
    gpu.CommandBuffer commandBuffer,
    gpu.RenderTarget target,
    gpu.HostBuffer transients,
    FskRenderableObject node,
    double x,
    double y,
    double width,
    double height,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
    Size logicalSize,
  ) {
    final renderPass = commandBuffer.createRenderPass(target);

    // Set up the Scissor box
    renderPass.setScissor(gpu.Scissor(
      x: x.toInt(),
      y: y.toInt(),
      width: width.toInt(),
      height: height.toInt(),
    ));

    // Set up the Viewport box
    renderPass.setViewport(gpu.Viewport(
      x: x.toInt(),
      y: y.toInt(),
      width: width.toInt(),
      height: height.toInt(),
    ));

    node.draw(
      renderPass,
      transients,
      pMatrix,
      mvMatrix,
      logicalSize,
    );
  }

  Offset _calculateTopLeft(Size parentViewportSize) {
    final double dpr = FSK.devicePixelRatio;
    final double x = left != null
        ? left! * dpr
        : (parentViewportSize.width - (screenSpaceSize.width + right!) * dpr);
    final double y = top != null
        ? top! * dpr
        : (parentViewportSize.height - (screenSpaceSize.height + bottom!) * dpr);
    return Offset(x, y);
  }

  /// Converts a global screen coordinate into a local coordinate within this overlay.
  /// Both [screen] and the returned [Offset] are in logical pixels.
  Offset screenToViewport(Offset screen, Size parentViewportSizeLogical) {
    final double x = left ?? (parentViewportSizeLogical.width - screenSpaceSize.width - right!);
    final double y = top ?? (parentViewportSizeLogical.height - screenSpaceSize.height - bottom!);
    return screen - Offset(x, y);
  }

  /// Checks if a global screen coordinate is within the bounds of this overlay.
  /// [point] is in logical pixels.
  bool isPointInViewport(Offset point, Size parentViewportSizeLogical) {
    final viewportRelative = screenToViewport(point, parentViewportSizeLogical);
    return viewportRelative.dx >= 0 &&
        viewportRelative.dx <= screenSpaceSize.width &&
        viewportRelative.dy >= 0 &&
        viewportRelative.dy <= screenSpaceSize.height;
  }
}
