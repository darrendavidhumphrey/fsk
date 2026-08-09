import 'dart:typed_data';
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
  Float32List serializeFragmentData() {
    final fragmentData = Float32List(20);
    final Vector3 lp = this[kLightPosKey] as Vector3;
    fragmentData[0] = lp.x; fragmentData[1] = lp.y; fragmentData[2] = lp.z; fragmentData[3] = 1.0;
    final Vector3 bcf = this[kBaseColorFactorKey] as Vector3;
    fragmentData[4] = bcf.x; fragmentData[5] = bcf.y; fragmentData[6] = bcf.z; fragmentData[7] = 1.0;
    fragmentData[8] = (this[kRoughnessFactorKey] as num).toDouble();
    fragmentData[9] = (this[kMetallicFactorKey] as num).toDouble();
    fragmentData[10] = (this[kDebugModeKey] as num).toDouble();
    return fragmentData;
  }
}
