import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:flutter_gpu_shaders/build.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {

    final result = await buildShaderBundleJson(
      buildInput: config,
      buildOutput: output,
      manifestFileName: 'shaders/fsk.shaderbundle.json',
      assetMode: ShaderBundleAssetMode.dataAssetsIfAvailable,
    );
    // This will print the EXACT key you need to pass into fromAsset()
    stderr.writeln('==================================================');
    stderr.writeln('YOUR DYNAMIC SHADER KEY IS: ${result.flutterAssetKey}');
    stderr.writeln('==================================================');
  });
}
