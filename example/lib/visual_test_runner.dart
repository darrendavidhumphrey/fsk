import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk_examples/picking_test_scene.dart';
import 'package:path/path.dart' as path;

// Scene imports
import 'checkerboard_scene.dart';
import 'scene_from_xml.dart';
import 'animated_checkerboard_scene.dart';
import 'cad_canvas_scene.dart';
import 'obj_model_scene.dart';
import 'pbr_model_scene.dart';
import 'pbr_with_overlay_example.dart';
import 'mtsdf_text_scene.dart';
import 'transformation_test_scene.dart';
import 'widget_nesting_scene.dart';

/// A specialized version of the example program that automatically iterates
/// through all examples and captures a screenshot of each to the 'test_outputs' directory.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logging.logInfo(">>> Visual Test Runner Starting...", source: "VisualTestRunner");
  
  // Initialize the FSK engine
  await FSK().init();

  runApp(const VisualTestApp());
}

class VisualTestApp extends StatefulWidget {
  const VisualTestApp({super.key});

  @override
  State<VisualTestApp> createState() => _VisualTestAppState();
}

class _VisualTestAppState extends State<VisualTestApp> with LoggableClass {
  final List<String> sceneNames = [
    "checkerboard_scene",
    "animated_checkerboard_scene",
    "cad_canvas_scene",
    "scene_from_xml",
    "obj_model_scene",
    "pbr_model_scene",
    "pbr_with_overlay_scene",
    "mtsdf_text_scene",
    "transformation_test_scene",
    "picking_test_scene",
    "widget_nesting_scene"
  ];

  FskSceneBase? _currentScene;
  bool _finished = false;
  String _status = "Preparing runner...";
  final List<String> _results = [];

  @override
  void initState() {
    super.initState();
    // Start tests after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTests());
  }

  Future<void> _runTests() async {
    // 1. Setup output directory in the project root
    final outDir = Directory('test_outputs');
    if (outDir.existsSync()) {
      try {
        outDir.deleteSync(recursive: true);
      } catch (e) {
        logWarning("Warning: could not clear test_outputs: $e");
      }
    }
    outDir.createSync(recursive: true);

    // 2. Iterate through each scene
    for (int i = 0; i < sceneNames.length; i++) {
      final name = sceneNames[i];
      logInfo("\n>>> [${i + 1}/${sceneNames.length}] Testing: $name");
      
      setState(() {
        _status = "Running $name...";
      });

      // Create and initialize the scene
      _currentScene = _createScene(name);
      await _currentScene!.init();

      // --- TEST SETUP ---
      _setupSceneForTest(name, _currentScene!);

      // If the scene requires background processing (like PickingTestScene),
      // we must wait for it to complete before capturing.
      if (_currentScene is PickingTestScene) {
        logInfo("    Waiting for PickingTestScene to generate map...");
        await (_currentScene as PickingTestScene).pickMapReady;
      }

      // Give it time to render several frames to ensure PBR textures and geometry are fully ready
      // and that the UI has settled.
      await Future.delayed(const Duration(milliseconds: 1500));

      // Capture the frame from the resolved GPU texture
      logInfo("    Capturing GPU frame...");
      final ui.Image gpuImage = await _currentScene!.captureFrameInternal();
      
      // Encode and save to disk
      try {
        await _saveImage(gpuImage, name);
        _results.add("✅ $name: SUCCESS");
      } catch (e) {
        logError("    ERROR saving $name: $e");
        _results.add("❌ $name: FAILED ($e)");
      } finally {
        gpuImage.dispose();
      }

      // Cleanup for next scene:
      // 1. Remove the scene from the state first
      final sceneToDispose = _currentScene!;
      _currentScene = null;
      setState(() {});

      // 2. Wait for a frame to ensure the UI has unmounted the RenderToTexture/GPURenderWidget
      // that was using this scene.
      await Future.delayed(Duration.zero);

      // 3. Now it's safe to dispose the scene
      sceneToDispose.dispose();

      // Small pause between scenes
      await Future.delayed(const Duration(milliseconds: 500));
    }

    logInfo("\n>>> Visual Tests Completed.");
    for (var r in _results) {
      logInfo("    $r");
    }

    // --- GOLDEN COMPARISON ---
    await _compareGoldens();

    setState(() {
      _finished = true;
      _status = "Visual Tests and Comparison Complete.";
    });

    // Automatically exit after a short delay so the final results are visible on screen briefly
    logInfo("\n>>> Runner exiting in 2 seconds...");
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  }

  Future<void> _compareGoldens() async {
    logInfo("\n>>> Starting Golden Comparison...");
    final goldenDir = Directory('golden_test_outputs');
    
    if (!goldenDir.existsSync()) {
      logWarning("    WARNING: 'golden_test_outputs' directory not found. Skipping comparison.");
      _results.add("⚠️ GOLDEN DIR MISSING");
      return;
    }

    for (final name in sceneNames) {
      final outputFile = File(path.join('test_outputs', '$name.png'));
      final goldenFile = File(path.join('golden_test_outputs', '$name.png'));

      if (!outputFile.existsSync()) {
        logError("    ❌ $name: Output image missing");
        _results.add("❌ $name: OUTPUT MISSING");
        continue;
      }

      if (!goldenFile.existsSync()) {
        logWarning("    ⚠️ $name: Golden image missing");
        _results.add("⚠️ $name: GOLDEN MISSING");
        continue;
      }

      final outBytes = await outputFile.readAsBytes();
      final goldenBytes = await goldenFile.readAsBytes();

      if (await _perceptualCompare(outBytes, goldenBytes)) {
        logInfo("    ✅ $name: PERCEPTUAL MATCH");
        _results.add("✅ $name: MATCH");
      } else {
        logError("    🔥 $name: MISMATCH");
        _results.add("🔥 $name: MISMATCH");
      }
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Performs a perceptual comparison between two images.
  /// [pixelThreshold] is the maximum allowed difference (0-255) for any single RGBA channel.
  /// [maxPercentFailing] is the maximum percentage (0.0 to 1.0) of pixels that are allowed to fail.
  Future<bool> _perceptualCompare(Uint8List outBytes, Uint8List goldenBytes,
      {int pixelThreshold = 64, double maxPercentFailing = 0.001}) async {
    final img1 = await _decodeImage(outBytes);
    final img2 = await _decodeImage(goldenBytes);

    if (img1.width != img2.width || img1.height != img2.height) {
      logError(
          "      Dimension mismatch: ${img1.width}x${img1.height} vs ${img2.width}x${img2.height}");
      img1.dispose();
      img2.dispose();
      return false;
    }

    final data1 = (await img1.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final data2 = (await img2.toByteData(format: ui.ImageByteFormat.rawRgba))!;

    img1.dispose();
    img2.dispose();

    final bytes1 = data1.buffer.asUint8List(data1.offsetInBytes, data1.lengthInBytes);
    final bytes2 = data2.buffer.asUint8List(data2.offsetInBytes, data2.lengthInBytes);

    if (bytes1.length != bytes2.length) {
      logError("      Byte length mismatch: ${bytes1.length} vs ${bytes2.length}");
      return false;
    }

    int failingPixels = 0;
    double totalSquareError = 0;
    final int totalPixels = bytes1.length ~/ 4;

    for (int i = 0; i < bytes1.length; i += 4) {
      final rDiff = (bytes1[i] - bytes2[i]).abs();
      final gDiff = (bytes1[i + 1] - bytes2[i + 1]).abs();
      final bDiff = (bytes1[i + 2] - bytes2[i + 2]).abs();
      final aDiff = (bytes1[i + 3] - bytes2[i + 3]).abs();

      // Track MSE for global quality check
      totalSquareError += (rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);

      if (rDiff > pixelThreshold ||
          gDiff > pixelThreshold ||
          bDiff > pixelThreshold ||
          aDiff > pixelThreshold) {
        failingPixels++;
      }
    }

    final double mse = totalSquareError / (totalPixels * 3);
    final double rmse = math.sqrt(mse);
    final double failRatio = failingPixels / totalPixels;

    // Calculate PSNR (higher is better, 30-50 is typical for 'good' matches)
    double psnr = 100.0;
    if (mse > 0) {
      psnr = 20 * (math.log(255.0) / math.ln10) - 10 * (math.log(mse) / math.ln10);
    }

    logInfo(
        "      Results: RMSE=${rmse.toStringAsFixed(2)}, PSNR=${psnr.toStringAsFixed(2)}dB, Failed Pixels: ${(failRatio * 100).toStringAsFixed(4)}%");

    // Fail if too many pixels are radically different OR if the global error is too high
    final bool passed = failRatio <= maxPercentFailing && rmse < 10.0;

    if (!passed) {
      logError("      Comparison FAILED criteria (Limit: ${maxPercentFailing * 100}%, Current: ${(failRatio * 100).toStringAsFixed(4)}%)");
    }

    return passed;
  }

  void _setupSceneForTest(String name, FskSceneBase scene) {
    // 1. Set deterministic time for animations (1.5 seconds)
    // At 1.5s, the animated checkerboard has a non-zero scale.
    scene.currentTime = 1.5;

    // 2. Set deterministic frame count for UI elements (like "Frames: 100")
    scene.frameCount = 100;

    // 3. Configure camera if applicable
    final delegate = scene.navigationDelegate;
    if (delegate is OrbitViewDelegate) {
      // View from 45 degree angle (Yaw 45, Pitch 45)
      delegate.setOrbitRotation(45, 45);
      
      // Zoom out 50% (Increase distance by 1.5x)
      final currentDist = delegate.distance;
      delegate.setViewDistance(currentDist * 1.5);
    }
  }

  FskSceneBase _createScene(String name) {
    switch (name) {
      case "checkerboard_scene":
        return CheckerBoardScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
      case "animated_checkerboard_scene":
        return AnimatedCheckerBoardScene(navigationDelegate: StaticViewDelegate(boxFit: FskBoxFit.bestFit));
      case "cad_canvas_scene":
        return CADCanvasScene(navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit));
      case "scene_from_xml":
        return SceneFromXml(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
      case "obj_model_scene":
        return ObjModelScene(navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit));
      case "pbr_model_scene":
        return PbrModelScene(navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit));
      case "pbr_with_overlay_scene":
        return PbrWithOverlayScene(navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit));
      case "mtsdf_text_scene":
        return MtsdfTextScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
      case "transformation_test_scene":
        return TransformationTestScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
        case "picking_test_scene":
          return PickingTestScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
      case "widget_nesting_scene":
        return WidgetNestingScene(navigationDelegate: OrthoViewDelegate(boxFit: FskBoxFit.bestFit));
      default:
        throw Exception("Unknown scene: $name");
    }
  }

  Future<void> _saveImage(ui.Image image, String name) async {
    // We flatten the potentially GPU-backed image to a software canvas 
    // to ensure reliable pixel readback for encoding.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final softwareImage = await picture.toImage(image.width, image.height);

    final ByteData? byteData = await softwareImage.toByteData(format: ui.ImageByteFormat.png);
    softwareImage.dispose();

    if (byteData == null) {
      throw Exception("Failed to encode $name as PNG byte data");
    }

    final File file = File(path.join('test_outputs', '$name.png'));
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    logInfo("    Saved to: ${file.path} (${byteData.lengthInBytes} bytes)");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      builder: (context, child) {
        // Force a consistent 1.0 pixel ratio for deterministic screenshots
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(devicePixelRatio: 1.0),
          child: child!,
        );
      },
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "FSK Visual Test Harness",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 10),
                  Container(
                      width: 400,
                      height: 2,
                      color: Colors.blueAccent.withValues(alpha: 0.3)),
                  const SizedBox(height: 30),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  // Display the current scene being tested
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border.all(
                          color: Colors.blueAccent.withValues(alpha:0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            spreadRadius: 2),
                      ],
                    ),
                    // We use a 16:9 container for the preview (640x360 is exactly 1/3rd of 1080p)
                    width: 640,
                    height: 360,
                    clipBehavior: Clip.hardEdge,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1920,
                        height: 1080,
                        child: Stack(
                          children: [
                            if (_currentScene != null)
                              RenderToTexture(scene: _currentScene!)
                            else if (!_finished)
                              const Center(
                                  child: CircularProgressIndicator())
                            else
                              Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 128, color: Colors.green),
                                    const SizedBox(height: 32),
                                    const Text("Done",
                                        style: TextStyle(
                                            fontSize: 64,
                                            color: Colors.green)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_finished) ...[
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      onPressed: () => exit(0),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text("Close Runner",
                          style: TextStyle(fontSize: 18)),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
