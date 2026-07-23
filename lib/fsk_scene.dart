import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk/performance_monitor.dart';

/// An abstract base class for a 3D scene, representing the root of a scene graph.
///
/// Manages the rendering context, a model-view matrix stack, a list of [FskSceneLayer]
/// objects, and the main rendering loop. Subclasses must implement the [drawScene]
/// method to define the actual rendering logic.
///
/// A [FskScene] must be initialized with a [RenderingContext] via the [init] method
/// before it can be used for drawing.
abstract class FskScene with LoggableClass, GlContextManager {
  /// The perspective projection matrix.
  Matrix4 pMatrix = Matrix4.identity();

  /// A stack for managing the Model-View matrix, allowing for hierarchical transformations.
  final MatrixStack mvMatrixStack = MatrixStack();

  /// A convenience getter for the current Model-View matrix from the top of the stack.
  Matrix4 get mvMatrix => mvMatrixStack.current;

  /// The list of layers that compose this scene, drawn in order.
  final List<FskSceneLayer> layers = [];

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

  FskSceneNavigationDelegate? navigationDelegate;

  bool _isPaused = false;
  bool get isPaused => _isPaused;
  set isPaused(bool value) {
    _isPaused = value;
  }

  /// Creates a new scene and its associated performance monitor.
  FskScene({this.navigationDelegate}) {
    performanceMonitor = PerformanceMonitor(tag: runtimeType.toString());
    navigationDelegate?.setScene(this);
  }

  /// Executes the provided [drawCommands] within a new, pushed matrix state.
  ///
  /// This is the safest way to apply hierarchical transformations, as it guarantees
  /// that the matrix state is restored even if an error occurs.
  void withPushedMatrix(void Function() drawCommands) {
    mvMatrixStack.withPushed(drawCommands);
  }

  /// The width of the render-to-texture target.
  int get textureWidth {
    if (renderToTextureId != null) {
      return renderToTextureId!.options.width;
    }
    return 2048;
  }

  /// The height of the render-to-texture target.
  int get textureHeight {
    if (renderToTextureId != null) {
      return renderToTextureId!.options.height;
    }
    return 2048;
  }

  /// The physical width of the render-to-texture target (logical width * dpr).
  int get physicalTextureWidth {
    if (renderToTextureId != null) {
      return (renderToTextureId!.options.width * renderToTextureId!.options.dpr).toInt();
    }
    return (FSK.renderToTextureSize * FSK.devicePixelRatio).toInt();
  }

  /// The physical height of the render-to-texture target (logical height * dpr).
  int get physicalTextureHeight {
    if (renderToTextureId != null) {
      return (renderToTextureId!.options.height * renderToTextureId!.options.dpr).toInt();
    }
    return (FSK.renderToTextureSize * FSK.devicePixelRatio).toInt();
  }

  /// Initializes the scene with the WebGL [RenderingContext].
  /// This must be called before any drawing operations can occur.
  void init(RenderingContext gl) {
    initializeGl(gl); // Initialize the GlContextManager mixin
    FSK().initContext(gl);
    gls = FSK().glStateManager;
    mvMatrixStack.current = Matrix4.identity();
    gl.clearColor(0, 1, 0, 1);

    // Initialize any layers that were added before the scene was ready.
    for (var layer in layers) {
      layer.init(this);
    }
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
  /// This method is called within the rendering loop when a repaint is needed
  @mustCallSuper
  void drawScene() {
    gls.startFrame();
    // Force the viewport to full texture size at the start of the frame.
    // This prevents state leaks from layers with custom viewports (overlays).
    gls.setViewport(0, 0, physicalTextureWidth, physicalTextureHeight, force: true);

    // Disable scissor test by default for the main scene draw
    gls.scissorEnabled(false, force: true);

    // Set the winding order to CW. Since we have a Y-flip in projection to match Flutter,
    // the standard CCW winding of our models is reversed to CW at the culling stage.
    if (FSK.isYFlipped) {
      gls.frontFace(WebGL.CW);
    } else {
      gls.frontFace(WebGL.CCW);
    }
    _frameCounter++;
  }

  /// Releases resources held by the scene and its layers.
  void dispose() {
    for (var layer in layers) {
      layer.dispose();
    }
    layers.clear();
  }

  /// Adds a [FskSceneLayer] to this scene.
  void addLayer(FskSceneLayer layer) {
    if (!layers.contains(layer)) {
      layers.add(layer);
      if (isInitialized) {
        layer.init(this);
      }
    }
  }

  /// Triggers a rebuild for all layers in the scene.
  void rebuildLayers(DateTime now) {
    for (FskSceneLayer layer in layers) {
      layer.rebuild(now);
    }
  }

  /// Draws all layers in the scene.
  void drawLayers() {
    for (FskSceneLayer layer in layers) {
      layer.draw(pMatrix, mvMatrix);
    }
  }

  /// Checks if any layer in the scene needs to be rebuilt.
  bool needsRebuild() {
    for (FskSceneLayer layer in layers) {
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

  Future<void> renderSceneToTexture() async {
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
          FSK().initScene(this);
        }

        drawScene();

        if (!kIsWeb) {
          if (Platform.isWindows) {
            gl.finish();
          }
        }
        renderToTextureId!.signalNewFrameAvailable();
        performanceMonitor.endFrame();

      }
    } finally {
      frameProcessing = false;
    }
  }
}

