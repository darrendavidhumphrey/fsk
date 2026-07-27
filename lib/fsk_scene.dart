import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector4;

/// An abstract base class for a 3D scene, representing the root of a scene graph.
///
/// Manages the rendering context, a model-view matrix stack, a list of [FskSceneLayer]
/// objects, and the main rendering loop. Subclasses must implement the [drawScene]
/// method to define the actual rendering logic.
///
/// A [FskScene] must be initialized with a [RenderingContext] via the [init] method
/// before it can be used for drawing.
abstract class FskScene with LoggableClass {
  /// The perspective projection matrix.
  Matrix4 pMatrix = Matrix4.identity();

  /// A stack for managing the Model-View matrix, allowing for hierarchical transformations.
  final MatrixStack mvMatrixStack = MatrixStack();

  /// A convenience getter for the current Model-View matrix from the top of the stack.
  Matrix4 get mvMatrix => mvMatrixStack.current;

  /// The current size of the viewport.
  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;
  set viewportSize(Size value) {
    _viewportSize = value;
  }

  FskSceneNavigationDelegate? navigationDelegate;

  // --- Physical Resolution Getters ---
  /// The actual width of the allocated GPU texture in physical pixels.
  int get physicalTextureWidth => _texture?.width ?? 0;

  /// The actual height of the allocated GPU texture in physical pixels.
  int get physicalTextureHeight => _texture?.height ?? 0;

  // Cache of rendering pipelines for this scene
  final PipelineCache pipelineCache = PipelineCache();

  // Render to texture for this scene
  gpu.Texture? _texture;
  gpu.Texture? get texture => _texture;

  // Render target for this scene
  gpu.RenderTarget? _renderTarget;
  gpu.RenderTarget? get renderTarget => _renderTarget;

  Color _clearColor = Color(0xFF000000);
  Color get clearColor => _clearColor;
  set clearColor(Color color) {
    _clearColor = color;
  }

  bool _isReady = true;
  bool get isReady => _isReady;

  set isReady(bool value) {
    _isReady = value;
  }

  // TODO: Test for fixing race condition glitches
  final List<gpu.DeviceBuffer> retainedOldBuffers = [];
  void clearRetainedBuffers() {
    if (retainedOldBuffers.isNotEmpty) {
      print("Disposing of ${retainedOldBuffers.length} retained buffers");
    }
    retainedOldBuffers.clear();
  }

  /// Creates a new scene and its associated performance monitor.
  FskScene({this.navigationDelegate}) {
    navigationDelegate?.setScene(this);
    mvMatrixStack.current = Matrix4.identity();
  }

  void dispose() {
    navigationDelegate?.dispose();
  }

  // Dynamic resize function called safely when the parent layout triggers bounds changes
  void updateRenderTargetSize(int width, int height) {
    if (width <= 0 || height <= 0) return;
    if (viewportSize.width == width &&
        viewportSize.height == height &&
        _renderTarget != null) {
      return;
    }

    _viewportSize = Size(width.toDouble(), height.toDouble());
  }
  void allocateRenderTarget() {
    // 🟢 THE FIX: Allocate the texture using PHYSICAL pixels (logical * devicePixelRatio)
    final int physicalWidth = (_viewportSize.width * FSK.devicePixelRatio).toInt();
    final int physicalHeight = (_viewportSize.height * FSK.devicePixelRatio).toInt();

    if (physicalWidth <= 0 || physicalHeight <= 0) return;

    _texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      physicalWidth,
      physicalHeight,
    );

    final depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient, // Optimized for ephemeral depth data
      physicalWidth,
      physicalHeight,
      format: gpu.gpuContext.defaultDepthStencilFormat,
    );

    if (_texture != null) {
      Vector4 clearValue = Vector4(
        _clearColor.r,
        _clearColor.g,
        _clearColor.b,
        _clearColor.a,
      );
      _renderTarget = gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
          texture: _texture!,
          clearValue: clearValue,
          loadAction: gpu.LoadAction.clear,
        ),
        depthStencilAttachment: gpu.DepthStencilAttachment(
          texture: depthTexture,
          depthClearValue: 1.0, // Clear to furthest depth distance
          stencilLoadAction: gpu.LoadAction.clear,
          stencilStoreAction: gpu.StoreAction.dontCare,
        ),
      );
    }

    navigationDelegate?.updateSceneMatrices(force: true);
  }

  /// The core drawing logic to be implemented by subclasses.
  /// This method is called within the rendering loop when a repaint is needed
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients);

  // Optionally override this to rebuild geometry before rendering
  void rebuildGeometry() {}

  void setupScissor(gpu.RenderPass renderPass) {
    navigationDelegate?.updateSceneMatrices();

    if (_texture == null) return;

    // 🟢 THE FIX: Use PHYSICAL dimensions for Scissor and Viewport
    final int physicalWidth = _texture!.width;
    final int physicalHeight = _texture!.height;

    // 1. Set up the Scissor box
    renderPass.setScissor(
      gpu.Scissor(
        x: 0,
        y: 0,
        width: physicalWidth,
        height: physicalHeight,
      ),
    );

    // 2. Set up the Viewport box
    renderPass.setViewport(
      gpu.Viewport(
        x: 0,
        y: 0,
        width: physicalWidth,
        height: physicalHeight,
      ),
    );
  }
}
