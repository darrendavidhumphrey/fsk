import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/gl_context_manager.dart';
import 'package:fsg/matrix_stack.dart';
import 'package:fsg/performance_monitor.dart';
import 'gl_state_manager.dart';
import 'logging.dart';
import 'fsg_singleton.dart';
import 'scene_layer.dart';

/// An abstract base class for a 3D scene, representing the root of a scene graph.
///
/// Manages the rendering context, a model-view matrix stack, a list of [SceneLayer]
/// objects, and the main rendering loop. Subclasses must implement the [drawScene]
/// method to define the actual rendering logic.
///
/// A [Scene] must be initialized with a [RenderingContext] via the [init] method
/// before it can be used for drawing.
abstract class Scene with LoggableClass, GlContextManager {
  /// The perspective projection matrix.
  Matrix4 pMatrix = Matrix4.identity();

  /// A stack for managing the Model-View matrix, allowing for hierarchical transformations.
  final MatrixStack mvMatrixStack = MatrixStack();

  /// A convenience getter for the current Model-View matrix from the top of the stack.
  Matrix4 get mvMatrix => mvMatrixStack.current;

  /// The list of layers that compose this scene, drawn in order.
  final List<SceneLayer> layers = [];

  /// A helper for monitoring rendering performance.
  late final PerformanceMonitor performanceMonitor;

  /// A flag to indicate that the scene needs to be redrawn.
  bool _needsRepaint = true;

  /// Track how many times drawScene has been called
  int _frameCounter = 0;
  int get frameCounter => _frameCounter;

  /// The current size of the viewport.
  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;

  /// The texture that this scene will render its output to.
  FlutterAngleTexture? renderToTextureId;

  late GlStateManager gls;
  /// Creates a new scene and its associated performance monitor.
  Scene() {
    performanceMonitor = PerformanceMonitor(tag: runtimeType.toString());
  }

  /// Executes the provided [drawCommands] within a new, pushed matrix state.
  ///
  /// This is the safest way to apply hierarchical transformations, as it guarantees
  /// that the matrix state is restored even if an error occurs.
  void withPushedMatrix(void Function() drawCommands) {
    mvMatrixStack.withPushed(drawCommands);
  }

  /// The width of the render-to-texture target.
  int get textureWidth => FSG.renderToTextureSize.toInt();

  /// The height of the render-to-texture target.
  int get textureHeight => FSG.renderToTextureSize.toInt();

  /// Initializes the scene with the WebGL [RenderingContext].
  /// This must be called before any drawing operations can occur.
  void init(RenderingContext gl) {
    initializeGl(gl); // Initialize the GlContextManager mixin
    gls = FSG().glStateManager;

    FSG().initContext(gl);
    mvMatrixStack.current = Matrix4.identity();
    gl.clearColor(0, 1, 0, 1);
  }

  /// Signals that the scene needs to be redrawn on the next frame.
  ///
  /// Animated scenes should call this in their [drawScene] method to ensure
  /// continuous rendering.
  void requestRepaint() {
    _needsRepaint = true;
  }

  /// Sets the viewport size for the scene and all its layers.
  void setViewportSize(Size size) {
    //logPedantic("setViewportSize: ${size.toString()}");
    _viewportSize = size;
    for (var layer in layers) {
      layer.setViewportSize(size);
    }
  }

  /// The core drawing logic to be implemented by subclasses.
  /// This method is called within the rendering loop when a repaint is needed.
  @mustCallSuper
void drawScene() {
    FSG().glStateManager.startFrame();
    _frameCounter++;
  }

  /// Releases resources held by the scene and its layers.
  void dispose() {
    for (var layer in layers) {
      layer.dispose();
    }
    layers.clear();

  }

  /// Adds a [SceneLayer] to this scene.
  void addLayer(SceneLayer layer) {
    layers.add(layer);
  }

  /// Triggers a rebuild for all layers in the scene.
  void rebuildLayers(DateTime now) {
    for (SceneLayer layer in layers) {
      layer.rebuild(now);
    }
  }

  /// Draws all layers in the scene.
  void drawLayers() {
    for (SceneLayer layer in layers) {
      layer.draw(pMatrix, mvMatrix);
    }
  }

  /// Checks if any layer in the scene needs to be rebuilt.
  bool needsRebuild() {
    for (SceneLayer layer in layers) {
      if (layer.needsRebuild) {
        return true;
      }
    }
    return false;
  }

  /// The main entry point for the rendering loop.
  ///
  /// Renders the scene to the configured texture if a repaint has been requested
  /// or if any layer needs to be rebuilt.
  ///

  bool frameProcessing = false;

  Future<void> renderSceneToTexture() async  {

    if (frameProcessing) return;
    frameProcessing = true;

    try {

      if (renderToTextureId == null) {
        frameProcessing = false;
        return;
      }

      if (_needsRepaint || needsRebuild()) {
        // Set [_needsRepaint] to false at the start of the loop.
        // The [drawScene] implementation is expected to call [requestRepaint] if it
        // needs to continue animating.
        _needsRepaint = false;

        performanceMonitor.beginFrame();
        renderToTextureId!.activate();

        if (!isInitialized) {
          FSG().initScene(this);
        }

       drawScene();

        await renderToTextureId!.signalNewFrameAvailable();

        if (!kIsWeb) {
          if (Platform.isWindows) {
            gl.finish();
          }
        }

        performanceMonitor.endFrame();
      }
    } finally {
      frameProcessing = false;
    }
  }
}
