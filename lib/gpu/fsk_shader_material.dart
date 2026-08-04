import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk.dart';

typedef UniformsFactory = BaseUniforms Function(gpu.Shader vert, gpu.Shader frag);

/// Encapsulates the configuration for a specific shader effect.
class FskShaderMaterial {
  final String vertShaderName;
  final String fragShaderName;
  final gpu.VertexLayout layout;
  final UniformsFactory uniformsFactory;

  FskShaderMaterial({
    required this.vertShaderName,
    required this.fragShaderName,
    required this.layout,
    required this.uniformsFactory,
  });

  // --- Built-in Material Presets ---

  static final FskShaderMaterial simpleTexture = FskShaderMaterial(
    vertShaderName: "SimpleTextureVertex",
    fragShaderName: "SimpleTextureFragment",
    layout: textVertexLayout,
    uniformsFactory: (v, f) => SimpleTextureUniforms(vertexShader: v, fragmentShader: f),
  );

  static final FskShaderMaterial flat = FskShaderMaterial(
    vertShaderName: "FlatVertex",
    fragShaderName: "FlatFragment",
    layout: v3t2n3c4Layout,
    uniformsFactory: (v, f) => FlatUniforms(vertexShader: v, fragmentShader: f),
  );

  static final FskShaderMaterial grid = FskShaderMaterial(
    vertShaderName: "GridVertex",
    fragShaderName: "GridFragment",
    layout: v3t2Layout,
    uniformsFactory: (v, f) => GridUniforms(vertexShader: v, fragmentShader: f),
  );

  static final FskShaderMaterial lighting = FskShaderMaterial(
    vertShaderName: "LightingVertex",
    fragShaderName: "LightingFragment",
    layout: v3t2n3Layout,
    uniformsFactory: (v, f) => LightingUniforms(vertexShader: v, fragmentShader: f),
  );
  
  static final FskShaderMaterial oneLight = FskShaderMaterial(
    vertShaderName: "OneLightVertex",
    fragShaderName: "OneLightFragment",
    layout: v3t2n3Layout,
    uniformsFactory: (v, f) => OneLightUniforms(vertexShader: v, fragmentShader: f),
  );

  static final FskShaderMaterial checkerboard = FskShaderMaterial(
    vertShaderName: "CheckerBoardVertex",
    fragShaderName: "CheckerBoardFragment",
    layout: v3t2Layout,
    uniformsFactory: (v, f) => CheckerBoardUniforms(vertexShader: v, fragmentShader: f),
  );

  static final FskShaderMaterial pbr = FskShaderMaterial(
    vertShaderName: "PbrVertex",
    fragShaderName: "PbrFragment",
    layout: v3t2n3Layout,
    uniformsFactory: (v, f) => PbrUniforms(vertexShader: v, fragmentShader: f),
  );
}
