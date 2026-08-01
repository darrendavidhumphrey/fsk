import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../gpu/fsk_shader_material.dart';
import '../shaders/base_uniforms.dart';

abstract class FskRendererBase {
  FskRendererBase();

  /// Optional custom material configuration
  FskShaderMaterial? customMaterial;
  BaseUniforms? uniforms;
  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
      );

  // All renderers must support a pipeline rebuild
  void rebuildPipeline();
}
