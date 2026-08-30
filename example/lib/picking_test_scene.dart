import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'transformation_test_scene.dart';

class PickingTestScene extends TransformationTestScene {
  PickingTestScene({super.navigationDelegate}) : super();

  bool fastPickTest = true;
  bool _isGeneratingPickMap = false;
  ui.Image? _pickMapImage;
  
  final Completer<void> _pickMapCompleter = Completer<void>();
  
  /// A future that completes when the pick map generation is finished and 
  /// the display quad has been added to the scene.
  Future<void> get pickMapReady => _pickMapCompleter.future;

  @override
  Future<void> onInit() async {
    // 1. Build the scene from the base TransformationTestScene
    await super.onInit();
    
    // We want to generate the pick map after the first frame has rendered
    // to ensure viewportSize and matrices are fully initialized by the widget/delegate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generatePickMap();
    });
  }

  Future<void> _generatePickMap() async {
    if (_isGeneratingPickMap || _pickMapImage != null) return;
    _isGeneratingPickMap = true;

    // Ensure we have a valid viewport size before starting.
    // In the visual test runner, this should eventually be 1920x1080.
    while (viewportSize.width < 10) {
      logInfo("    PickingTestScene: Viewport not ready yet (${viewportSize.width}x${viewportSize.height}). Waiting...");
      await Future.delayed(const Duration(milliseconds: 100));
    }

    logInfo("Generating high-resolution pick map (${viewportSize.width.toInt()}x${viewportSize.height.toInt()})...");
    final stopwatch = Stopwatch()..start();

    final int width = viewportSize.width.toInt();
    final int height = viewportSize.height.toInt();
    
    final Uint8List pixels = Uint8List(width * height * 4);
    
    // Initialize to opaque black [0, 0, 0, 255]. 
    // Untested pixels will remain in this state.
    for (int i = 3; i < pixels.length; i += 4) {
      pixels[i] = 255;
    }

    // 1. Calculate the layout matrix used during drawScene.
    vm.Matrix4 layoutMatrix = vm.Matrix4.identity();
    if (useBoxFitLayout) {
      vm.Matrix4? boxFitMatrix = navigationDelegate?.createBoxFitMatrix(skinSize);
      if (boxFitMatrix != null) {
        layoutMatrix = boxFitMatrix * layoutMatrix;
      }
      layoutMatrix.translateByVector3(vm.Vector3(-skinSize.width / 2, -skinSize.height / 2, 0));
    }

    // 2. The combined view matrix used for picking
    final int step = fastPickTest ? 2 : 1;
    int pixelsTested = 0;

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        pixelsTested++;
        final offset = Offset(x.toDouble(), y.toDouble());
        
        // Generate ray using the camera view matrix. 
        // The scene's hitTest() will automatically apply the layout matrix.
        final vm.Ray ray = computePickRay(
          offset,
          viewportSize,
          pMatrix,
          mvMatrix,
          ndcNear: 0.0,
          ndcFar: 1.0,
        );

        // Perform hit test against the scene graph
        final hits = hitTest(ray, mode: FskHitTestMode.first);
        
        final int pixelIndex = (y * width + x) * 4;
        if (hits.isNotEmpty) {
          // Hit: Green
          pixels[pixelIndex + 0] = 0;   // R
          pixels[pixelIndex + 1] = 255; // G
          pixels[pixelIndex + 2] = 0;   // B
          pixels[pixelIndex + 3] = 255; // A
        } else {
          // Miss: Red
          pixels[pixelIndex + 0] = 255; // R
          pixels[pixelIndex + 1] = 0;   // G
          pixels[pixelIndex + 2] = 0;   // B
          pixels[pixelIndex + 3] = 255; // A
        }
      }
      
      // Yield periodically to keep the UI responsive
      if (y % 100 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    stopwatch.stop();
    final double avgTimeUs = stopwatch.elapsedMicroseconds / pixelsTested;
    logInfo("Pick map generation complete:");
    logInfo("  - Pixels tested: $pixelsTested");
    logInfo("  - Total time: ${stopwatch.elapsedMilliseconds}ms");
    logInfo("  - Avg time per pixel: ${avgTimeUs.toStringAsFixed(3)}us");

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        completer.complete(img);
      },
    );

    _pickMapImage = await completer.future;

    // Replace the entire scene content with a single quad displaying the pick map
    clearNodes();
    
    // Switch to identity layout so the result quad matches the viewport exactly
    useBoxFitLayout = false;
    
    // Manually reset matrices for identity rendering of the result
    mvMatrix.setIdentity();
    pMatrix.setIdentity();
    // Projection for 1:1 pixel mapping in NDC [-1, 1]
    pMatrix.setEntry(0, 0, 2.0 / width);
    pMatrix.setEntry(1, 1, 2.0 / height);
    pMatrix.setEntry(2, 2, 1.0);
    pMatrix.setEntry(3, 3, 1.0);

    // Create a texture manually from the generated image
    final gpu.Texture gpuTexture = await _uploadImageToGpu(_pickMapImage!);
    final textureInfo = FskTextureInfo(
      "pick_map_result",
      "generated",
      gpu.SamplerOptions(
        minFilter: gpu.MinMagFilter.nearest,
        magFilter: gpu.MinMagFilter.nearest,
      ),
      texture: gpuTexture,
    );
    textureInfo.isLoaded = true;
    FSK().textureManager.registerTexture(textureInfo);

    // Center the quad in the newly-identity coordinate system
    final resultQuad = FskQuad(
      "pick_map_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3.zero(), viewportSize),
      const Rect.fromLTWH(0, 0, 1, 1),
    );
    resultQuad.renderer.setTexture(textureInfo);
    addNode(resultQuad);

    _isGeneratingPickMap = false;
    _pickMapCompleter.complete();
    setNeedsUpdate();
  }

  Future<gpu.Texture> _uploadImageToGpu(ui.Image image) async {
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      image.width,
      image.height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
    );
    texture.overwrite(data!);
    return texture;
  }

  @override
  void dispose() {
    _pickMapImage?.dispose();
    super.dispose();
  }
}
