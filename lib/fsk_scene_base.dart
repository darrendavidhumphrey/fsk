import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' show Matrix4;

/// An abstract base class for a 3D scene, representing the root of a scene graph.
abstract class FskSceneBase extends ChangeNotifier with LoggableClass {
  Matrix4 pMatrix = Matrix4.identity();
  Matrix4 mvMatrix = Matrix4.identity();

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

  int _frameCount = 0;
  int get frameCount => _frameCount;

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
}
