import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../fsk_singleton.dart';
import '../gpu/fsk_render_target.dart';
import '../scene_graph/fsk_scene.dart';
import '../scene_graph/fsk_scene_object.dart';
import '../scene_graph/fsk_quad.dart';

/// An abstract base class for a [FskScene] that is rendered in 2D screen space
/// rather than 3D world space.
abstract class ScreenSpaceOverlay extends FskScene {
  final String id;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Size screenSpaceSize;

  @override
  final bool interceptInput;

  FskQuad? _backgroundNode;
  Size _lastParentSize = Size.zero;

  ScreenSpaceOverlay({
    required this.id,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.screenSpaceSize,
    this.interceptInput = false,
    super.navigationDelegate,
    super.clearColor = const Color(0x40FFFFFF), // 25% white background
  }) {
    autoClear = false;
    navigationDelegate?.setViewRect(
        Rect.fromLTWH(0, 0, screenSpaceSize.width, screenSpaceSize.height));

    assert((left == null) != (right == null), 'Must provide either left or right.');
    assert((top == null) != (bottom == null), 'Must provide either top or bottom.');
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients, [gpu.RenderPass? parentRenderPass, bool isLast = true]) {
    if (!isReady) return;

    final parentPhysicalSize =
        Size(renderTarget.width.toDouble(), renderTarget.height.toDouble());
    _lastParentSize = parentPhysicalSize;

    final double physicalDpr = FSK.devicePixelRatio;
    viewportSize = Size(screenSpaceSize.width * physicalDpr,
        screenSpaceSize.height * physicalDpr);

    updateMatrices();

    // Lazily create the background node
    if (clearColor.a > 0.0 && _backgroundNode == null) {
      _backgroundNode = FskQuad.centered(
        '${id}_bg',
        this,
        screenSpaceSize,
        modulateColor: clearColor,
        textureId: FSK().textureManager.solidTextureId,
      );
      _backgroundNode!.premultiplyAlpha = false;
      _backgroundNode!.setDepthState(
        depthTestEnabled: false,
        depthWriteEnabled: false,
        depthCompareOperation: gpu.CompareFunction.always,
      );
      _backgroundNode!.rebuildGeometry();
    }

    final origin = _calculateTopLeft(_lastParentSize);
    final double physicalWidth = screenSpaceSize.width * physicalDpr;
    final double physicalHeight = screenSpaceSize.height * physicalDpr;

    // Architecture: Single-Pass MSAA Compatibility
    // To clear depth for an overlay, we MUST start a new pass.
    // We use loadClearDepthTarget which keeps color but clears depth.
    final renderPass = commandBuffer.createRenderPass(renderTarget.loadClearDepthTarget);
    hardResetPipelineState(renderPass);

    renderPass.setScissor(gpu.Scissor(
      x: origin.dx.toInt(), y: origin.dy.toInt(),
      width: physicalWidth.toInt(), height: physicalHeight.toInt(),
    ));

    renderPass.setViewport(gpu.Viewport(
      x: origin.dx.toInt(), y: origin.dy.toInt(),
      width: physicalWidth.toInt(), height: physicalHeight.toInt(),
    ));

    if (_backgroundNode != null) {
      final vm.Matrix4 bgP = vm.Matrix4.identity();
      bgP.setEntry(0, 0, 2.0 / screenSpaceSize.width);
      bgP.setEntry(1, 1, 2.0 / screenSpaceSize.height);
      bgP.setEntry(2, 2, 0.001);
      bgP.setEntry(3, 3, 1.0);

      _backgroundNode!.draw(
        renderPass,
        transients,
        bgP,
        vm.Matrix4.identity(),
        screenSpaceSize,
      );
    }

    // Draw all child nodes into the new pass.
    for (final node in rootNodes) {
      if (node is FskRenderableObject && node.visible) {
        node.draw(
          renderPass,
          transients,
          pMatrix,
          mvMatrix, 
          screenSpaceSize,
        );
      }
    }

    // Draw sub-layers into the new pass
    for (int i = 0; i < layers.length; i++) {
      layers[i].drawScene(commandBuffer, renderTarget, transients, renderPass, isLast);
    }
  }

  @override
  void rebuildGeometry() {
    super.rebuildGeometry();
    _backgroundNode?.rebuildGeometry();
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

  @override
  Offset screenToViewport(Offset screen, Size parentViewportSizeLogical) {
    final double x = left ?? (parentViewportSizeLogical.width - screenSpaceSize.width - right!);
    final double y = top ?? (parentViewportSizeLogical.height - screenSpaceSize.height - bottom!);
    return screen - Offset(x, y);
  }

  @override
  bool isPointInViewport(Offset point, Size parentViewportSizeLogical) {
    final viewportRelative = screenToViewport(point, parentViewportSizeLogical);
    return viewportRelative.dx >= 0 &&
        viewportRelative.dx <= screenSpaceSize.width &&
        viewportRelative.dy >= 0 &&
        viewportRelative.dy <= screenSpaceSize.height;
  }
}
