import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk_singleton.dart';
import 'base_uniforms.dart';

class PbrUniforms extends BaseUniforms {
  static const String kLightPosKey = 'uLightPos';
  static const String kBaseColorFactorKey = 'uBaseColorFactor';
  static const String kRoughnessFactorKey = 'uRoughnessFactor';
  static const String kMetallicFactorKey = 'uMetallicFactor';
  static const String kDebugModeKey = 'uDebugMode';

  @override
  String get vertexBlockName => 'PbrVertexUniforms';
  @override
  String get fragmentBlockName => 'PbrFragmentUniforms';

  gpu.Texture? normalMap;
  gpu.Texture? metallicRoughnessMap;

  PbrUniforms({super.vertexShader, super.fragmentShader}) {
    this[kLightPosKey] = Vector3(100.0, 100.0, 200.0);
    this[kBaseColorFactorKey] = Vector3(1.0, 1.0, 1.0);
    this[kRoughnessFactorKey] = 1.0;
    this[kMetallicFactorKey] = 1.0;
    this[kDebugModeKey] = 0.0;
  }

  @override
  bool get hasSampler => true;
  @override
  String get samplerUniformName => 'uBaseColorMap';

  set lightPos(Vector3 val) => this[kLightPosKey] = val;
  set baseColorFactor(Vector3 val) => this[kBaseColorFactorKey] = val;
  set roughnessFactor(double val) => this[kRoughnessFactorKey] = val;
  set metallicFactor(double val) => this[kMetallicFactorKey] = val;
  set debugMode(double val) => this[kDebugModeKey] = val;

  @override
  void copyFrom(BaseUniforms other) {
    super.copyFrom(other);
    if (other is PbrUniforms) {
      normalMap = other.normalMap;
      metallicRoughnessMap = other.metallicRoughnessMap;
    }
  }

  @override
  void bindAdditionalTextures(gpu.RenderPass renderPass) {
    if (fragmentShader == null) return;
    final dummy = FSK().textureManager.transparentTexture!;
    renderPass.bindTexture(fragmentShader!.getUniformSlot('uNormalMap'), normalMap ?? dummy, sampler: samplerOptions);
    renderPass.bindTexture(fragmentShader!.getUniformSlot('uMetallicRoughnessMap'), metallicRoughnessMap ?? dummy, sampler: samplerOptions);
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packVector3(valuesMap[kLightPosKey]);
    fragmentData.packVector3(valuesMap[kBaseColorFactorKey]);
    fragmentData.packDouble(valuesMap[kRoughnessFactorKey]);
    fragmentData.packDouble(valuesMap[kMetallicFactorKey]);
    fragmentData.packDouble(valuesMap[kDebugModeKey]);
  }
}
