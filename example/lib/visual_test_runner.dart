import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:path/path.dart' as path;

// Scene imports
import 'checkerboard_scene.dart';
import 'scene_from_xml.dart';
import 'animated_checkerboard_scene.dart';
import 'cad_canvas_scene.dart';
import 'obj_model_scene.dart';
import 'pbr_model_scene.dart';

/// A specialized version of the example program that automatically iterates
/// through all examples and captures a screenshot of each to the 'test_outputs' directory.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print(">>> Visual Test Runner Starting...");
  
  // Initialize the FSK engine
  await FSK().init();

  runApp(const VisualTestApp());
}

class VisualTestApp extends StatefulWidget {
  const VisualTestApp({super.key});

  @override
  State<VisualTestApp> createState() => _VisualTestAppState();
}

class _VisualTestAppState extends State<VisualTestApp> {
  final List<String> sceneNames = [
    "checkerboard_scene",
    "animated_checkerboard_scene",
    "cad_canvas_scene",
    "scene_from_xml",
    "obj_model_scene",
    "pbr_model_scene"
  ];

  int _currentIndex = -1;
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
        print("Warning: could not clear test_outputs: $e");
      }
    }
    outDir.createSync(recursive: true);

    // 2. Iterate through each scene
    for (int i = 0; i < sceneNames.length; i++) {
      final name = sceneNames[i];
      print("\n>>> [${i + 1}/${sceneNames.length}] Testing: $name");
      
      setState(() {
        _currentIndex = i;
        _status = "Running $name...";
      });

      // Create and initialize the scene
      _currentScene = _createScene(name);
      await _currentScene!.init();

      // --- TEST SETUP ---
      _setupSceneForTest(name, _currentScene!);

      // Give it time to render several frames to ensure PBR textures and geometry are fully ready
      // and that the UI has settled.
      await Future.delayed(const Duration(milliseconds: 1500));

      // Capture the frame from the resolved GPU texture
      print("    Capturing GPU frame...");
      final ui.Image gpuImage = await _currentScene!.captureFrameInternal();
      
      // Encode and save to disk
      try {
        await _saveImage(gpuImage, name);
        _results.add("✅ $name: SUCCESS");
      } catch (e) {
        print("    ERROR saving $name: $e");
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

    print("\n>>> Visual Tests Completed.");
    for (var r in _results) {
      print("    $r");
    }

    // --- GOLDEN COMPARISON ---
    await _compareGoldens();

    setState(() {
      _finished = true;
      _status = "Visual Tests and Comparison Complete.";
    });

    // Automatically exit after a short delay so the final results are visible on screen briefly
    print("\n>>> Runner exiting in 2 seconds...");
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  }

  Future<void> _compareGoldens() async {
    print("\n>>> Starting Golden Comparison...");
    final goldenDir = Directory('golden_test_outputs');
    
    if (!goldenDir.existsSync()) {
      print("    WARNING: 'golden_test_outputs' directory not found. Skipping comparison.");
      _results.add("⚠️ GOLDEN DIR MISSING");
      return;
    }

    for (final name in sceneNames) {
      final outputFile = File(path.join('test_outputs', '$name.png'));
      final goldenFile = File(path.join('golden_test_outputs', '$name.png'));

      if (!outputFile.existsSync()) {
        print("    ❌ $name: Output image missing");
        _results.add("❌ $name: OUTPUT MISSING");
        continue;
      }

      if (!goldenFile.existsSync()) {
        print("    ⚠️ $name: Golden image missing");
        _results.add("⚠️ $name: GOLDEN MISSING");
        continue;
      }

      final outBytes = await outputFile.readAsBytes();
      final goldenBytes = await goldenFile.readAsBytes();

      if (_compareBytes(outBytes, goldenBytes)) {
        print("    ✅ $name: MATCH");
        _results.add("✅ $name: MATCH");
      } else {
        print("    🔥 $name: MISMATCH");
        _results.add("🔥 $name: MISMATCH");
      }
    }
  }

  bool _compareBytes(Uint8List b1, Uint8List b2) {
    if (b1.length != b2.length) return false;
    for (int i = 0; i < b1.length; i++) {
      if (b1[i] != b2[i]) return false;
    }
    return true;
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
    await file.writeAsBytes(byteData.buffer.asUint8List());
    print("    Saved to: ${file.path} (${byteData.lengthInBytes} bytes)");
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
                      color: Colors.blueAccent.withOpacity(0.3)),
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
                          color: Colors.blueAccent.withOpacity(0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            spreadRadius: 2),
                      ],
                    ),
                    // We use a fixed-size SizedBox to force the 1920x1080 resolution
                    // regardless of the window size. We wrap it in scrollers so it doesn't
                    // clip in a way that breaks the layout builder.
                    width: 512,
                    height: 512,
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        physics: const NeverScrollableScrollPhysics(),
                        child: UnconstrainedBox(
                          alignment: Alignment.topLeft,
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
                                            size: 64, color: Colors.green),
                                        const SizedBox(height: 16),
                                        const Text("Done",
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.green)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
