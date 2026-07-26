import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:fsk/gpu/gpu_pipeline_key.dart';
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

  FskSceneNavigationDelegate? navigationDelegate;

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
  void set clearColor(Color color) {
    _clearColor = color;
    requestRepaint();
  }

  /// Creates a new scene and its associated performance monitor.
  FskScene({this.navigationDelegate}) {
    navigationDelegate?.setScene(this);
    mvMatrixStack.current = Matrix4.identity();
  }

  bool _needsUpdate = false;
  bool get needsUpdate => _needsUpdate;

  void requestRepaint() {
    _needsUpdate = true;
  }

  void dispose() {
    navigationDelegate?.dispose();
  }

  // Dynamic resize function called safely when the parent layout triggers bounds changes
  void updateRenderTargetSize(int width, int height) {
    if (width <= 0 || height <= 0) return;
    if (viewportSize.width == width &&
        viewportSize.height == height &&
        _renderTarget != null)
      return;

    _viewportSize = Size(width.toDouble(), height.toDouble());

    // Allocate a brand new texture sized to match the physical container exactly
    _texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      width,
      height,
    );

    if (_texture != null) {
      Vector4 clearValue = Vector4(
        _clearColor.r,
        _clearColor.g,
        _clearColor.b,
        _clearColor.a,
      );
      _renderTarget = gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: _texture!, clearValue: clearValue),
      );
    }

    navigationDelegate?.updateSceneMatrices(force: true);
  }

  /// Executes the provided [drawCommands] within a new, pushed matrix state.
  ///
  /// This is the safest way to apply hierarchical transformations, as it guarantees
  /// that the matrix state is restored even if an error occurs.
  void withPushedMatrix(void Function() drawCommands) {
    mvMatrixStack.withPushed(drawCommands);
  }

  /// The core drawing logic to be implemented by subclasses.
  /// This method is called within the rendering loop when a repaint is needed
  @mustCallSuper
  void drawScene(gpu.RenderPass renderPass, Size viewportSize) async {
    navigationDelegate?.updateSceneMatrices();
  }

  void setupScissor(gpu.RenderPass renderPass, Size viewportSize) {
    // 1. Set up the Scissor box
    renderPass.setScissor(
      gpu.Scissor(
        x: 0,
        y: 0,
        width: viewportSize.width.toInt(),
        height: viewportSize.height.toInt(),
      ),
    );

    // 2. Set up the Viewport box
    renderPass.setViewport(
      gpu.Viewport(
        x: 0,
        y: 0,
        width: viewportSize.width.toInt(),
        height: viewportSize.height.toInt(),
      ),
    );
  }
}
