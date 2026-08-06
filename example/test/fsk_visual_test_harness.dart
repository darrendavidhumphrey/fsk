import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:path/path.dart' as path;

/// A robust harness for visual testing of FSK scenes.
class FskVisualTestHarness {
  static const String outputDirName = 'test_outputs';
  static const String goldenDirName = 'test_goldens';

  static Future<void> setup() async {
    try {
      final Directory outputDir = Directory(outputDirName);
      if (outputDir.existsSync()) {
        outputDir.deleteSync(recursive: true);
      }
      outputDir.createSync(recursive: true);
    } catch (e) {
      // Ignore directory cleanup errors in tests
    }
  }

  /// Runs a single scene capture test with strict sequence.
  static Future<void> runSceneTest(WidgetTester tester, String testName, FskSceneBase Function() sceneFactory, {Size? size}) async {
    debugPrint('>>> [Harness] runSceneTest starting: $testName');
    Logging.logInfo('>>> [Harness] Starting test: $testName', source: "FskVisualTestHarness");

    try {
      // 1. Create and Init Scene
      Logging.logInfo('>>> [Harness] Creating scene object... ($testName)', source: "FskVisualTestHarness");
      final scene = sceneFactory();
      await tester.runAsync(() async => await scene.init());

      // Use a very small size for diagnostic stability
      Size targetSize = const Size(128, 128);
      tester.view.physicalSize = targetSize;
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(targetSize);

      // 4. Mount Widget Tree
      Logging.logInfo('>>> [Harness] Mounting widget tree... ($testName)', source: "FskVisualTestHarness");
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: targetSize.width,
                height: targetSize.height,
                child: GPURenderWidget(scene: scene, isAnimating: true),
              ),
            ),
          ),
        ),
      );

      // 5. Settle Frames
      Logging.logInfo('>>> [Harness] Settling frames... ($testName)', source: "FskVisualTestHarness");
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // 6. Request Capture Hook via Future
      Logging.logInfo('>>> [Harness] Requesting frame capture via hook... ($testName)', source: "FskVisualTestHarness");

      final ui.Image gpuImage = await tester.runAsync(() async {
        final future = scene.captureFrameInternal();
        await tester.pump();
        return await future;
      }) as ui.Image;

      Logging.logInfo('  Capture hook successful. ($testName)', source: "FskVisualTestHarness");

      // 7. Flatten to Software Image & Pixel Readback
      late ui.Image softwareImage;
      await tester.runAsync(() async {
        try {
          Logging.logInfo('  Flattening GPU image to software buffer... ($testName)', source: "FskVisualTestHarness");
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawImage(gpuImage, Offset.zero, Paint());
          final picture = recorder.endRecording();
          
          softwareImage = await picture.toImage(gpuImage.width, gpuImage.height);
          gpuImage.dispose();

          Logging.logInfo('  Starting toByteData(png) on software buffer... ($testName)', source: "FskVisualTestHarness");
          final stopwatch = Stopwatch()..start();
          final ByteData? byteData = await softwareImage.toByteData(format: ui.ImageByteFormat.png);
          stopwatch.stop();
print("HERE");
          if (byteData == null) {
            Logging.logError('  Failed to capture image data ($testName).', source: "FskVisualTestHarness");
          } else {
            Logging.logInfo('  Capture finished in ${stopwatch.elapsedMilliseconds}ms. Saving file... ($testName)', source: "FskVisualTestHarness");
            final File file = File(path.join(outputDirName, '$testName.png'));
            file.writeAsBytesSync(byteData.buffer.asUint8List());
            Logging.logInfo('Visual test output saved: ${file.path}', source: "FskVisualTestHarness");
          }
          softwareImage.dispose();
        } catch (e, s) {
          Logging.logError('CRITICAL EXCEPTION during pixel readback ($testName): $e\n$s', source: "FskVisualTestHarness");
        }
      });

      // 8. Clean up
      Logging.logInfo('>>> [Harness] Cleaning up... ($testName)', source: "FskVisualTestHarness");
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      scene.dispose();
      
      Logging.logInfo('>>> [Harness] Completed test: $testName', source: "FskVisualTestHarness");
    } catch (e, s) {
      Logging.logError('>>> [Harness] CRITICAL ERROR IN TEST $testName: $e\n$s', source: "FskVisualTestHarness");
      rethrow;
    }
  }

  static Future<void> compareResults() async {
    final outDir = Directory(outputDirName);
    if (!outDir.existsSync()) return;

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
      throw Exception('Visual Test Comparison Failed:\n${failures.join('\n')}');
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
