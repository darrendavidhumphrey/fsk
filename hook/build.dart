import 'package:hooks/hooks.dart';
import 'package:flutter_gpu_shaders/build.dart';

void main(List<String> args) async {
  // The 'build' function handles processing CLI arguments and orchestrates inputs/outputs
  await build(args, (BuildInput input, BuildOutputBuilder output) async {

    // Call the updated buildShaderBundleJson with the structured types
    await buildShaderBundleJson(
      buildInput: input,
      buildOutput: output,
      manifestFileName: 'fsk.shaderbundle.json',
      // Optional defaults included implicitly:
      // includeDirectories: const [],
      // assetMode: ShaderBundleAssetMode.legacyOnly,
    );
  });
}
