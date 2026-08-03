import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:path/path.dart' as path;

/// A visual test harness for FSK scenes.
///
/// This class handles scene construction, asset loading waits,
/// PNG capture, and comparison against golden images.
class FskVisualTestHarness with LoggableClass {
  static const String outputDirName = 'test_outputs';
  static const String goldenDirName = 'golden_test_outputs';

  /// Ensures the output directory is clean before running tests.
  static Future<void> setup() async {
    final out = Directory(outputDirName);
    Logging.logInfo('Setting up visual test output directory at: ${out.absolute.path}', source: "FskVisualTestHarness");

    if (out.existsSync()) {
      try {
        out.deleteSync(recursive: true);
      } catch (e) {
        Logging.logWarning('Could not clear test_outputs: $e', source: "FskVisualTestHarness");
      }
    }
    out.createSync(recursive: true);

    final gold = Directory(goldenDirName);
    if (!gold.existsSync()) {
      Logging.logInfo('Creating golden test output directory at: ${gold.absolute.path}', source: "FskVisualTestHarness");
      gold.createSync(recursive: true);
    }

    // Ensure a clean slate for each test run by clearing shared caches
    FSK().textureManager.clear();
    BitmapFontManager().clear();
  }

  /// Constructs, initializes, and captures a scene as a PNG.
  ///
  /// The [initParams] callback allows supplying initialization parameters
  /// to the scene before it is pumped.
  static Future<void> runSceneTest(
    WidgetTester tester,
    String testName,
    FskScene scene, {
    Size? size,
    void Function(FskScene)? initParams,
  }) async {
    // 1. Supply initialization parameters if provided
    if (initParams != null) {
      initParams(scene);
    }

    // Default size if not provided or determined later
    Size targetSize = size ?? const Size(1920, 1080);

    // Force the test environment to our target resolution with 1:1 pixel mapping
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = targetSize;
    FSK.devicePixelRatio = 1.0;

    // 2. Initial pump to start loading
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: targetSize.width,
              height: targetSize.height,
              child: GPURenderWidget(scene: scene),
            ),
          ),
        ),
      ),
    );

    // 3. Wait until all scene assets are loaded (scene.isReady) AND at least several frames have drawn
    int attempts = 0;
    const int maxAttempts = 200; // Increased timeout to 10 seconds
    while ((!scene.isReady || FSK().isBusy) && attempts < maxAttempts) {
      if (attempts % 20 == 0) {
        Logging.logInfo('Waiting for scene to become ready... (Attempt $attempts, isReady=${scene.isReady}, isBusy=${FSK().isBusy})', source: "FskVisualTestHarness");
      }
      // Allow real-time tasks (like image decoding) to proceed in the background
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      // Pump a frame in simulated time to trigger the GPURenderWidget
      await tester.pump();
      attempts++;
    }

    if (!scene.isReady) {
      Logging.logError('Scene TIMEOUT: isReady=${scene.isReady}, frameCount=${scene.frameCount}', source: "FskVisualTestHarness");
      throw Exception('Scene failed to become ready within timeout.');
    }

    // 4. Determine final size from XML if it's an FskFrameScene
    bool sizeChanged = false;
    if (scene is FskFrameScene) {
      if (scene.frameSize.width > 0 && scene.frameSize.height > 0) {
        if (targetSize != scene.frameSize) {
          targetSize = scene.frameSize;
          sizeChanged = true;
          Logging.logInfo('Resizing test viewport to match XML frame size: ${targetSize.width}x${targetSize.height}', source: "FskVisualTestHarness");
        }
      }
    }

    // 5. If size changed, re-pump with the correct dimensions
    if (sizeChanged) {
      tester.view.physicalSize = targetSize;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: targetSize.width,
                height: targetSize.height,
                child: GPURenderWidget(scene: scene),
              ),
            ),
          ),
        ),
      );
    }

    // 6. Wait for the rendering pipeline to settle at the final resolution
    await tester.runAsync(() async {
      int settlementFrames = 0;
      int startFrame = scene.frameCount;
      while (settlementFrames < 10) {
        await Future.delayed(const Duration(milliseconds: 16));
        await tester.pump();
        if (scene.frameCount > startFrame) {
          settlementFrames++;
        }
      }
    });

    // 7. Capture the rendered content from the scene's output texture
    if (scene.texture == null) {
      throw Exception('Scene output texture is null after rendering.');
    }

    await tester.runAsync(() async {
      Logging.logInfo('Capturing rendered content ($testName) from GPU texture...', source: "FskVisualTestHarness");

      final ui.Image image = scene.texture!.asImage();
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode rendered texture to PNG.');
      }

      // 8. Store in the test_outputs folder
      final File file = File(path.join(outputDirName, '$testName.png'));
      file.writeAsBytesSync(byteData.buffer.asUint8List());

      Logging.logInfo('Visual test output saved: ${file.path}', source: "FskVisualTestHarness");
    });
  }

  /// Compares all generated test outputs against the golden directory.
  static Future<void> compareResults() async {
    final outDir = Directory(outputDirName);
    if (!outDir.existsSync()) {
      Logging.logWarning('Test output directory "$outputDirName" does not exist. Skipping comparison.', source: "FskVisualTestHarness");
      return;
    }

    final List<FileSystemEntity> outputEntities = outDir.listSync();
    final List<String> failures = [];

    for (var entity in outputEntities) {
      if (entity is! File || !entity.path.endsWith('.png')) continue;

      final String fileName = path.basename(entity.path);
      final File goldenFile = File(path.join(goldenDirName, fileName));

      if (!goldenFile.existsSync()) {
        failures.add('FAIL: Golden file missing for "$fileName".');
        continue;
      }

      final Uint8List outputBytes = entity.readAsBytesSync();
      final Uint8List goldenBytes = goldenFile.readAsBytesSync();

      if (!_compareBytes(outputBytes, goldenBytes)) {
        failures.add('FAIL: Visual mismatch detected for "$fileName".');
      } else {
        Logging.logInfo('PASS: Visual match for "$fileName".', source: "FskVisualTestHarness");
      }
    }

    if (failures.isNotEmpty) {
      final String report = failures.join('\n');
      throw Exception('Visual Test Comparison Failed:\n$report');
    }
  }

  static bool _compareBytes(Uint8List b1, Uint8List b2) {
    if (b1.length != b2.length) return false;
    for (int i = 0; i < b1.length; i++) {
      if (b1[i] != b2[i]) return false;
    }
    return true;
  }
}
