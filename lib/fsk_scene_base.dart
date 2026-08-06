import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// An abstract base class for a 3D scene, representing the root of a scene graph.
abstract class FskSceneBase extends ChangeNotifier with LoggableClass {
  vm.Matrix4 pMatrix = vm.Matrix4.identity();
  vm.Matrix4 mvMatrix = vm.Matrix4.identity();

  Size _viewportSize = Size.zero;
  // ignore: unnecessary_getters_setters
  Size get viewportSize => _viewportSize;
  set viewportSize(Size value) => _viewportSize = value;

  FskSceneNavigationDelegate? navigationDelegate;

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
  int get frameCount => _overrideFrameCount >= 0 ? _overrideFrameCount : _frameCount;

  int _overrideFrameCount = -1;

  /// Explicitly sets the frame count for display or logic.
  /// Used for deterministic visual tests. Set to -1 to use real frame count.
  set frameCount(int value) {
    if (_overrideFrameCount == value) return;
    _overrideFrameCount = value;
    notifyListeners();
  }

  FskSceneBase({this.navigationDelegate,this.clearColor=Colors.black}) {
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
    if (_texture == null) return;

    renderPass.setScissor(
      gpu.Scissor(x: 0, y: 0, width: _texture!.width, height: _texture!.height),
    );

    renderPass.setViewport(
      gpu.Viewport(x: 0, y: 0, width: _texture!.width, height: _texture!.height),
    );
  }

  @mustCallSuper
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients) {
    updateMatrices();
    _frameCount++;
  }

  @override
  void dispose() {
    navigationDelegate = null;
    super.dispose();
  }

  void rebuildGeometry() {}
  void clearRetainedBuffers() {}

  // --- Input Dispatchers ---
  // These methods allow the scene to intercept or transform input before
  // it reaches the navigation delegate.

  void onPointerDown(PointerDownEvent event) =>
      navigationDelegate?.onPointerDown(event);
  void onPointerMove(PointerMoveEvent event) =>
      navigationDelegate?.onPointerMove(event);
  void onPointerUp(PointerUpEvent event) =>
      navigationDelegate?.onPointerUp(event);
  void onPointerCancel(PointerCancelEvent event) =>
      navigationDelegate?.onPointerCancel(event);
  void onPointerSignal(PointerSignalEvent event) =>
      navigationDelegate?.onPointerSignal(event);
  void onScaleStart(ScaleStartDetails details) =>
      navigationDelegate?.onScaleStart(details);
  void onScaleUpdate(ScaleUpdateDetails details) =>
      navigationDelegate?.onScaleUpdate(details);
  void onScaleEnd(ScaleEndDetails details) =>
      navigationDelegate?.onScaleEnd(details);
  KeyEventResult onKeyEvent(KeyEvent event) =>
      navigationDelegate?.onKeyEvent(event) ?? KeyEventResult.ignored;
}
