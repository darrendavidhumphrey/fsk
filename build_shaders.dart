import 'dart:io';
import 'package:flutter_gpu_shaders/build.dart';

/// A manual script to force a rebuild of the shader bundle.
/// Run this with: dart build_shaders.dart
void main() async {
  print('Building shader bundle...');
  
  final manifestFile = File('shaders/fsk.shaderbundle.json');
  if (!manifestFile.existsSync()) {
    print('Error: shaders/fsk.shaderbundle.json not found.');
    return;
  }

  // We'll use a temporary output directory
  final tempDir = Directory.systemTemp.createTempSync('fsk_shaders');
  
  try {
    // This is a lower-level internal function of flutter_gpu_shaders, 
    // but since we don't have the BuildInput/Output objects from the hook system,
    // we have to be creative or use the hook-less entry points.
    
    // Actually, flutter_gpu_shaders provides a way to build without the full hook environment
    // if we can find the right helper.
    
    // If not, we can just spawn the compiler directly or use a known working pattern.
    
    // Let's try to just run the build hook's main with mock arguments?
    // No, that's too complex.
    
    // Better way: use the 'impellerc' binary that comes with the Flutter SDK.
    final flutterRoot = ProcessAt.runSync(['flutter', 'sdk-path']).stdout.trim();
    final impellerc = '$flutterRoot/bin/cache/artifacts/engine/windows-x64/impellerc.exe';
    
    if (!File(impellerc).existsSync()) {
      print('Error: impellerc not found at $impellerc');
      return;
    }

    print('Using impellerc: $impellerc');
    
    // We'll read the json and compile each shader.
    // However, the bundle format is internal to Impeller.
    
    // SUCCESS PATH: Trigger the hook system properly by running 'flutter build bundle'
    print('Triggering build via flutter build bundle...');
    final result = Process.runSync('flutter', ['build', 'bundle'], workingDirectory: 'example');
    
    print(result.stdout);
    print(result.stderr);
    
    if (result.exitCode == 0) {
      print('Build successful.');
    } else {
      print('Build failed with exit code ${result.exitCode}');
    }

  } catch (e) {
    print('Exception: $e');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

extension ProcessAt on Process {
  static ProcessResult runSync(List<String> cmd) {
    return Process.runSync(cmd[0], cmd.sublist(1));
  }
}
