import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../gpu/gpu_shader.dart';

class BitmapTextShader extends GpuShader {
  static String uTextColor = "uTextColor";

  final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();


  BitmapTextShader()
    : super(
        vertexKey: "BitmapTextVertex",
        fragmentKey: "BitmapTextFragment",
        extraUniforms: [UniformDefinition(uTextColor,UniformType.uniformBlock )]
      );

  void setTextColor(Color color) {
  // TODO: build a block here ...
  }


}
