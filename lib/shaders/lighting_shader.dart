import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'base_uniforms.dart';

class LightingUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String _kKdKey = 'Kd';
  static const String _kLdKey = 'Ld';
  static const String _kLightPosKey = 'lightPos';

  // --- Default Layout Value Constants ---
  static final Vector3 _kDefaultKd = Vector3(1.0, 1.0, 1.0);
  static final Vector3 _kDefaultLd = Vector3(1.0, 1.0, 1.0);
  static final Vector3 _kDefaultLightPos = Vector3(0.0, 0.0, 0.0);

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 12;

  LightingUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kKdKey] = _kDefaultKd;
    this[_kLdKey] = _kDefaultLd;
    this[_kLightPosKey] = _kDefaultLightPos;
  }

  @override
  bool get hasSampler => true;
  @override
  String get samplerUniformName => 'uSampler';

  // --- Type-Safe Public Setters ---
  set kd(Vector3 val) => this[_kKdKey] = val;
  set ld(Vector3 val) => this[_kLdKey] = val;
  set lightPos(Vector3 val) => this[_kLightPosKey] = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // Std140 alignment rules:
    // uKd starts at 0, occupies 0-11. Next vec3 starts at 16.
    final Vector3 kdVal = this[_kKdKey] as Vector3;
    fragmentData[0] = kdVal.x;
    fragmentData[1] = kdVal.y;
    fragmentData[2] = kdVal.z;
    fragmentData[3] = 0.0; // Padding

    // uLd starts at offset 16 (index 4). Next vec4 starts at 32.
    final Vector3 ldVal = this[_kLdKey] as Vector3;
    fragmentData[4] = ldVal.x;
    fragmentData[5] = ldVal.y;
    fragmentData[6] = ldVal.z;
    fragmentData[7] = 0.0; // Padding

    // uLightPos starts at offset 32 (index 8). Occupies 32-47.
    final Vector3 lpVal = this[_kLightPosKey] as Vector3;
    fragmentData[8] = lpVal.x;
    fragmentData[9] = lpVal.y;
    fragmentData[10] = lpVal.z;
    fragmentData[11] = 1.0; // w component for vec4 position

    return fragmentData;
  }
}
