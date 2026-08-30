import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk_singleton.dart';
import 'package:fsk/geometry/reference_box.dart';
import 'package:fsk/geometry/mesh_hit_tester.dart';
import 'package:fsk/gpu/fsk_texture_manager.dart';
import 'package:fsk/scene_graph/fsk_scene_base.dart';
import 'package:fsk/scene_graph/fsk_scene.dart';
import 'package:fsk/scene_graph/fsk_widget_portal.dart';
import 'package:fsk/scene_graph/fsk_quad.dart';

/// A scene object that displays a Flutter widget as a texture on a quad.
class FskWidgetObject extends FskQuad {
  final GlobalKey _repaintKey = GlobalKey();
  final Widget widget;
  final Size widgetSize;

  /// Whether the mouse is currently hovering over this 3D object.
  final ValueNotifier<bool> isHovered = ValueNotifier<bool>(false);

  FskTextureInfo? _widgetTexture;
  bool _isUpdating = false;
  final vm.Vector3 _lastLocalHitPoint = vm.Vector3.zero();
  ByteData? _pendingByteData;

  FskWidgetObject(
    String id,
    FskSceneBase parentScene,
    ReferenceBox refBox, {
    required this.widget,
    required this.widgetSize,
  }) : super(id, parentScene, refBox, const Rect.fromLTWH(0, 0, 1, 1)) {
    _initWidget();
  }

  void _initWidget() {
    // Check FSK state before attempting GPU operations
    if (FSK().state != FskState.initialized) {
      logError("FskWidgetObject($id): Cannot initialize. FSK is not initialized or GPU is disabled.");
      return;
    }

    // Defer texture allocation to avoid throwing in the constructor.
    Future.microtask(() {
      try {
        _initTexture();
        _registerPortal();
      } catch (e, s) {
        logError("FskWidgetObject($id): Failed to initialize widget/texture. Ensure --enable-flutter-gpu is used: $e\n$s");
      }
    });
  }

  void _initTexture() {
    final double pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final int width = (widgetSize.width * pixelRatio).toInt();
    final int height = (widgetSize.height * pixelRatio).toInt();

    // Initial texture allocation
    final gpu.Texture texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
    );

    _widgetTexture = FskTextureInfo(
      "widget_${id}_$hashCode",
      "generated",
      gpu.SamplerOptions(
        minFilter: gpu.MinMagFilter.linear,
        magFilter: gpu.MinMagFilter.linear,
      ),
      texture: texture,
    );
    _widgetTexture!.isLoaded = true;

    // Initialize with transparent black to avoid garbage on first frame
    final Uint8List transparentPixels = Uint8List(width * height * 4);
    texture.overwrite(ByteData.sublistView(transparentPixels));

    renderer.setTexture(_widgetTexture);
  }

  void _registerPortal() {
    // Register the portal with the scene so it can be rendered by GPURenderWidget
    if (parentScene is FskScene) {
      (parentScene as FskScene).addWidgetPortal(FskWidgetPortal(
        repaintKey: _repaintKey,
        widget: _RepaintNotifier(
          onPaint: _updateTexture,
          child: buildPortalWidget(),
        ),
        size: widgetSize,
        onRepaint: _updateTexture,
      ));
    }
  }

  /// Returns the widget to be rendered in the off-screen portal.
  /// Subclasses can override this to provide a widget that reacts to [isHovered].
  Widget buildPortalWidget() => buildPortalWidgetOverride?.call() ?? widget;

  /// Optional override for the portal widget builder.
  Widget Function()? buildPortalWidgetOverride;

  Future<void> _updateTexture() async {
    if (_isUpdating || _widgetTexture?.texture == null) return;
    _isUpdating = true;

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final double pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData != null) {
        _pendingByteData = byteData;
        setNeedsRebuild();
        parentScene.setNeedsUpdate();
      }
      image.dispose();
    } catch (e) {
      logError("Error updating widget texture: $e");
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void doRebuild() {
    super.doRebuild();
    if (_pendingByteData != null && _widgetTexture?.texture != null) {
      _widgetTexture!.texture!.overwrite(_pendingByteData!);
      _pendingByteData = null;
    }
  }

  @override
  void draw(gpu.RenderPass renderPass, gpu.HostBuffer transients,
      vm.Matrix4 pMatrix, vm.Matrix4 mvMatrix, Size viewportSize) {
    if (!visible) return;

    // Apply this leaf node's local transformation relative to the parent context (mvMatrix).
    final vm.Matrix4 finalMvMatrix = mvMatrix.clone();
    if (transformable.isTransformed()) {
      finalMvMatrix.multiply(transformable.getTransform());
    }

    // Instead of drawing immediately, register with the parent FskScene for the final widget pass.
    if (parentScene is FskScene) {
      (parentScene as FskScene).registerWidgetDraw(this, renderer, pMatrix, finalMvMatrix, viewportSize);
    } else {
      // Fallback if not in a standard FskScene (unlikely)
      renderer.draw(renderPass, transients, pMatrix, finalMvMatrix, viewportSize);
    }
  }

  @override
  bool onPointerDown(PointerDownEvent event, FskHitDetails hit) {
    _forwardPointerEvent(event, hit);
    return true;
  }

  @override
  bool onPointerMove(PointerMoveEvent event, FskHitDetails hit) {
    _forwardPointerEvent(event, hit);
    return true;
  }

  @override
  bool onPointerUp(PointerUpEvent event, FskHitDetails hit) {
    _forwardPointerEvent(event, hit);
    return true;
  }

  @override
  bool onPointerHover(PointerHoverEvent event, FskHitDetails hit) {
    _forwardPointerEvent(event, hit);
    return true;
  }

  @override
  void onPointerEnter(PointerEvent event, [FskHitDetails? hit]) {
    isHovered.value = true;
    _forwardPointerEvent(event, hit ?? FskHitDetails(hitObject: this, hitPoint: vm.Vector3.zero(), localHitPoint: _lastLocalHitPoint, distance: 0, normal: vm.Vector3.zero(), hitData: null));
  }

  @override
  void onPointerExit(PointerEvent event, [FskHitDetails? hit]) {
    isHovered.value = false;
    _forwardPointerEvent(event, hit ?? FskHitDetails(hitObject: this, hitPoint: vm.Vector3.zero(), localHitPoint: _lastLocalHitPoint, distance: 0, normal: vm.Vector3.zero(), hitData: null));
  }

  void _forwardPointerEvent(PointerEvent event, FskHitDetails hit) {
    // 1. Map to widget pixel coordinates using the local hit point.
    // hit.localHitPoint is relative to the ReferenceBox origin and axes.
    final vm.Vector3 localPos = hit.localHitPoint;

    // 2. Convert to normalized UV (0.0 to 1.0)
    final double u = localPos.x / refBox.xVector.length;
    final double v = 1.0 - (localPos.y / refBox.yVector.length); // Y-up to Y-down

    // 3. Map to widget pixel coordinates
    final Offset localOffset =
        Offset(u * widgetSize.width, v * widgetSize.height);

    // 4. Inject into the widget tree
    final RenderBox? renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null) {
      final Offset globalOffset = renderBox.localToGlobal(localOffset);

      // Targeted hit test bypasses parent clipping and coordinate bounds checks.
      final BoxHitTestResult result = BoxHitTestResult();
      renderBox.hitTest(result, position: localOffset);

      final transformedEvent = event.copyWith(
        position: globalOffset,
      );

      GestureBinding.instance.dispatchEvent(transformedEvent, result);
    }
  }
}

class _RepaintNotifier extends SingleChildRenderObjectWidget {
  final VoidCallback onPaint;

  const _RepaintNotifier({required this.onPaint, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderRepaintNotifier(onPaint);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderRepaintNotifier renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderRepaintNotifier extends RenderProxyBox {
  VoidCallback onPaint;
  _RenderRepaintNotifier(this.onPaint);

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // Notify that a repaint happened, so we should update the texture
    WidgetsBinding.instance.addPostFrameCallback((_) => onPaint());
  }
}

/// A specialized implementation for editable text within the scene graph.
class FskEditableTextObject extends FskWidgetObject {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;

  FskEditableTextObject(
    super.id,
    super.parentScene,
    super.refBox, {
    required this.controller,
    required this.focusNode,
    this.style = const TextStyle(fontSize: 40, color: Colors.white),
    super.widgetSize = const Size(512, 128),
  }) : super(
          widget: const SizedBox.shrink(), // Will be replaced by buildPortalWidget
        );

  @override
  bool onPointerDown(PointerDownEvent event, FskHitDetails hit) {
    logInfo("FskEditableTextObject($id): Requesting focus for TextField");
    focusNode.requestFocus();
    return super.onPointerDown(event, hit);
  }

  @override
  Widget buildPortalWidget() {
    return buildPortalWidgetOverride?.call() ??
        _EditableTextWidget(
          controller: controller,
          focusNode: focusNode,
          style: style,
          size: widgetSize,
          isHoveredNotifier: isHovered,
        );
  }
}

class _EditableTextWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Size size;
  final ValueNotifier<bool>? isHoveredNotifier;

  const _EditableTextWidget({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.size,
    this.isHoveredNotifier,
  });

  @override
  State<_EditableTextWidget> createState() => _EditableTextWidgetState();
}

class _EditableTextWidgetState extends State<_EditableTextWidget> {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
    widget.isHoveredNotifier?.addListener(_onHoverChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    widget.isHoveredNotifier?.removeListener(_onHoverChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onHoverChanged() {
    if (mounted) setState(() => _isHovered = widget.isHoveredNotifier!.value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.size.width,
        height: widget.size.height,
        decoration: BoxDecoration(
          color: _isHovered 
              ? Colors.black.withValues(alpha: 0.7) 
              : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: widget.focusNode.hasFocus 
                ? Colors.cyanAccent 
                : (_isHovered ? Colors.white : Colors.white70),
            width: widget.focusNode.hasFocus ? 4 : (_isHovered ? 3 : 2),
          ),
        ),
        child: Center(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
