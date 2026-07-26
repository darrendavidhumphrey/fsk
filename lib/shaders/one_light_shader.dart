import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'base_uniforms.dart';

class OneLightUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String kLightPosKey = 'uLightPos';
  static const String kAmbientLightKey = 'uAmbientLight';
  static const String kDiffuseLightKey = 'uDiffuseLight';
  static const String kSpecularLightKey = 'uSpecularLight';
  static const String kMaterialAmbientKey = 'uMaterialAmbient';
  static const String kMaterialDiffuseKey = 'uMaterialDiffuse';
  static const String kMaterialSpecularKey = 'uMaterialSpecular';
  static const String kMaterialShininessKey = 'uMaterialShininess';
  static const String kOutlineEnabledKey = 'uOutlineEnabled';
  static const String kDrawFillKey = 'uDrawFill';
  static const String kOutlineColorKey = 'uOutlineColor';
  static const String kOutlineWidthKey = 'uOutlineWidth';

  // --- Default Layout Value Constants ---
  static final Vector3 _kDefaultLightPos = Vector3(0.0, 0.0, 0.0);
  static const Color _kDefaultLightColor = Color(0xFFFFFFFF);
  static const double _kDefaultShininess = 32.0;
  static const bool _kDefaultOutlineEnabled = false;
  static const bool _kDefaultDrawFill = true;
  static const double _kDefaultOutlineWidth = 1.0;

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 36;

  OneLightUniforms({super.vertexShader, super.fragmentShader}) {
    this[kLightPosKey] = _kDefaultLightPos;
    this[kAmbientLightKey] = _kDefaultLightColor;
    this[kDiffuseLightKey] = _kDefaultLightColor;
    this[kSpecularLightKey] = _kDefaultLightColor;
    this[kMaterialAmbientKey] = _kDefaultLightColor;
    this[kMaterialDiffuseKey] = _kDefaultLightColor;
    this[kMaterialSpecularKey] = _kDefaultLightColor;
    this[kMaterialShininessKey] = _kDefaultShininess;
    this[kOutlineEnabledKey] = _kDefaultOutlineEnabled;
    this[kDrawFillKey] = _kDefaultDrawFill;
    this[kOutlineColorKey] = _kDefaultLightColor;
    this[kOutlineWidthKey] = _kDefaultOutlineWidth;
  }

  // --- Type-Safe Public Setters ---
  set lightPos(Vector3 val) => this[kLightPosKey] = val;
  set ambientLight(Color val) => this[kAmbientLightKey] = val;
  set diffuseLight(Color val) => this[kDiffuseLightKey] = val;
  set specularLight(Color val) => this[kSpecularLightKey] = val;
  set materialAmbient(Color val) => this[kMaterialAmbientKey] = val;
  set materialDiffuse(Color val) => this[kMaterialDiffuseKey] = val;
  set materialSpecular(Color val) => this[kMaterialSpecularKey] = val;
  set materialShininess(double val) => this[kMaterialShininessKey] = val;
  set outlineEnabled(bool val) => this[kOutlineEnabledKey] = val;
  set drawFill(bool val) => this[kDrawFillKey] = val;
  set outlineColor(Color val) => this[kOutlineColorKey] = val;
  set outlineWidth(double val) => this[kOutlineWidthKey] = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // 0-3: uLightPos (vec4)
    final Vector3 lp = this[kLightPosKey] as Vector3;
    fragmentData[0] = lp.x;
    fragmentData[1] = lp.y;
    fragmentData[2] = lp.z;
    fragmentData[3] = 1.0;

    // 4-7: uAmbientLight (vec4)
    packColor(fragmentData, 4, this[kAmbientLightKey] as Color);
    // 8-11: uDiffuseLight (vec4)
    packColor(fragmentData, 8, this[kDiffuseLightKey] as Color);
    // 12-15: uSpecularLight (vec4)
    packColor(fragmentData, 12, this[kSpecularLightKey] as Color);
    // 16-19: uMaterialAmbient (vec4)
    packColor(fragmentData, 16, this[kMaterialAmbientKey] as Color);
    // 20-23: uMaterialDiffuse (vec4)
    packColor(fragmentData, 20, this[kMaterialDiffuseKey] as Color);
    // 24-27: uMaterialSpecular (vec4)
    packColor(fragmentData, 24, this[kMaterialSpecularKey] as Color);
    // 28-31: uOutlineColor (vec4)
    packColor(fragmentData, 28, this[kOutlineColorKey] as Color);

    // 32-35: uConfig (vec4)
    fragmentData[32] = (this[kMaterialShininessKey] as num).toDouble();
    fragmentData[33] = (this[kOutlineEnabledKey] as bool) ? 1.0 : 0.0;
    fragmentData[34] = (this[kDrawFillKey] as bool) ? 1.0 : 0.0;
    fragmentData[35] = (this[kOutlineWidthKey] as num).toDouble();

    return fragmentData;
  }
}
