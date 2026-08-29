import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk_singleton.dart';
import 'package:fsk/fsk_input_handler.dart';
import 'package:fsk/logging.dart';
import 'package:fsk/gpu/fsk_render_target.dart';
import 'package:fsk/geometry/mesh_hit_tester.dart';
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';

/// An abstract base class for a 3D scene, representing the root of a scene graph.
abstract class FskSceneBase extends ChangeNotifier
    with LoggableClass, FskSceneInputDispatcherMixin
    implements FskInputHandler {
  vm.Matrix4 pMatrix = vm.Matrix4.identity();
  vm.Matrix4 mvMatrix = vm.Matrix4.identity();

  Size _viewportSize = Size.zero;
  // ignore: unnecessary_getters_setters
  Size get viewportSize => _viewportSize;
  set viewportSize(Size value) => _viewportSize = value;

  /// Returns the layout matrix used to scale/position the scene content.
  vm.Matrix4 getLayoutMatrix() => vm.Matrix4.identity();

  @override
  FskSceneNavigationDelegate? navigationDelegate;

  /// The distance from the camera to the primary point of interest.
  /// Used by sub-layers for constant-screen-size scaling (highlights, handles).
  double cameraDistance = 300.0;

  final ValueNotifier<MouseCursor> cursorNotifier =
      ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  void setCursor(MouseCursor cursor) {
    if (cursorNotifier.value != cursor) {
      cursorNotifier.value = cursor;
    }
  }

  /// Internal test hook for visual captures
  bool captureRequested = false;

  Completer<ui.Image>? _captureCompleter;

  Future<ui.Image> captureFrameInternal() {
    _captureCompleter = Completer<ui.Image>();
    captureRequested = true;
    notifyListeners();
    return _captureCompleter!.future;
  }

  void onFrameCaptured(ui.Image image) {
    _captureCompleter?.complete(image);
    _captureCompleter = null;
    captureRequested = false;
  }

  gpu.Texture? _texture;
  // ignore: unnecessary_getters_setters
  gpu.Texture? get texture => _texture;
  set texture(gpu.Texture? value) => _texture = value;

  Color clearColor;

  bool isReady = false;

  /// The timestamp when initialization started.
  late DateTime _startTime;

  /// The current logical time in seconds for the scene.
  /// If set to 0.0 (default), it returns the elapsed time since [init()] was called.
  /// Used for deterministic animations in visual tests.
  double _currentTime = 0.0;
  double get currentTime {
    if (_currentTime > 0) return _currentTime;
    return DateTime.now().difference(_startTime).inMilliseconds / 1000.0;
  }

  set currentTime(double value) {
    if (_currentTime == value) return;
    _currentTime = value;
    notifyListeners();
  }

  int _frameCount = 0;
  int get frameCount =>
      _overrideFrameCount >= 0 ? _overrideFrameCount : _frameCount;

  int _overrideFrameCount = -1;

  /// Explicitly sets the frame count for display or logic.
  /// Used for deterministic visual tests. Set to -1 to use real frame count.
  set frameCount(int value) {
    if (_overrideFrameCount == value) return;
    _overrideFrameCount = value;
    notifyListeners();
  }

  FskSceneBase({this.navigationDelegate, this.clearColor = Colors.black}) {
    navigationDelegate?.setScene(this);
  }

  Future<void>? _initFuture;
  bool get initStarted => _initFuture != null;

  /// Public entry point for initialization. Guaranteed to run only once.
  Future<void> init() {
    return _initFuture ??= _runInit();
  }

  Future<void> _runInit() async {
    _startTime = DateTime.now();
    await onInit();
    isReady = true;
    notifyListeners();
  }

  /// Override this to perform asynchronous initialization (loading assets, etc.)
  @mustCallSuper
  Future<void> onInit() async {}

  void setNeedsUpdate() {
    notifyListeners();
  }

  /// Updates the projection and view matrices via the navigation delegate.
  void updateMatrices() {
    navigationDelegate?.updateSceneMatrices();
  }

  void updateRenderTargetSize(int width, int height) {
    // Communication in PHYSICAL pixels for the GPU surface
    _viewportSize = Size(width.toDouble(), height.toDouble());

    // Communication in LOGICAL pixels for the Navigation Logic and Projections
    navigationDelegate?.setViewRect(
      Rect.fromLTWH(0, 0, width / FSK.devicePixelRatio,
          height / FSK.devicePixelRatio),
    );

    // Ensure matrices are updated immediately for the new size
    updateMatrices();
  }

  void setupScissor(gpu.RenderPass renderPass) {
    final double width = _texture?.width.toDouble() ?? _viewportSize.width;
    final double height = _texture?.height.toDouble() ?? _viewportSize.height;

    if (width <= 0 || height <= 0) return;

    renderPass.setScissor(
      gpu.Scissor(x: 0, y: 0, width: width.toInt(), height: height.toInt()),
    );
  }

  /// Performs a hard reset of common pipeline states to known defaults.
  /// This helps prevent state leakage between layers or passes.
  void hardResetPipelineState(gpu.RenderPass renderPass) {
    renderPass.setCullMode(gpu.CullMode.none);
    renderPass.setWindingOrder(gpu.WindingOrder.counterClockwise);
    renderPass.setDepthWriteEnable(true);
    renderPass.setDepthCompareOperation(gpu.CompareFunction.lessEqual);
    renderPass.setStencilReference(0);
    renderPass.setColorBlendEnable(true);
    renderPass.setColorBlendEquation(gpu.ColorBlendEquation(
      colorBlendOperation: gpu.BlendOperation.add,
      sourceColorBlendFactor: gpu.BlendFactor.one,
      destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      alphaBlendOperation: gpu.BlendOperation.add,
      sourceAlphaBlendFactor: gpu.BlendFactor.one,
      destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
    ));

    setupScissor(renderPass);
  }

  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients, [gpu.RenderPass? parentRenderPass, bool isLast = true]) {
    updateMatrices();
    _frameCount++;
  }

  /// Updates any active animations in the scene.
  @mustCallSuper
  void updateAnimations(DateTime now) {}

  @override
  void dispose() {
    navigationDelegate = null;
    super.dispose();
  }

  void rebuildGeometry() {}
  void clearRetainedBuffers() {}

  /// Hit Testing
  List<FskHitDetails> hitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest});

  // --- Layer Interaction Interface ---
  // These are used by the dispatcher mixin to interact with layers (overlays)
  // without creating a circular dependency on the ScreenSpaceOverlay class.

  bool get interceptInput => false;

  bool isPointInViewport(Offset point, Size parentViewportSizeLogical) => false;

  Offset screenToViewport(Offset screen, Size parentViewportSizeLogical) =>
      screen;
}
