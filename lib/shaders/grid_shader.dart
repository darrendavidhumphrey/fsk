import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';

class GridUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String _kMajorLineColorKey = 'majorLineColor';
  static const String _kMinorLineColorKey = 'minorLineColor';
  static const String _kMmLineColorKey = 'mmLineColor';
  static const String _kResolutionWidthKey = 'resolutionWidth';
  static const String _kResolutionHeightKey = 'resolutionHeight';
  static const String _kScaleKey = 'scale';
  static const String _kMajorLineSpacingMMKey = 'majorLineSpacingMM';
  static const String _kMinorLineSpacingMMKey = 'minorLineSpacingMM';
  static const String _kMajorLineThicknessKey = 'majorLineThickness';
  static const String _kMinorLineThicknessKey = 'minorLineThickness';
  static const String _kMmLineThicknessKey = 'mmLineThickness';

  // --- Default Layout Value Constants ---
  static const Color _kDefaultMajorLineColor = Color(0xFFFFFFFF);
  static const Color _kDefaultMinorLineColor = Color(0xFFB0B0B0);
  static const Color _kDefaultMmLineColor = Color(0xFF606060);
  static const double _kDefaultResolutionWidth = 1000.0;
  static const double _kDefaultResolutionHeight = 1000.0;
  static const double _kDefaultScale = 1.0;
  static const double _kDefaultMajorLineSpacingMM = 10.0;
  static const double _kDefaultMinorLineSpacingMM = 5.0;
  static const double _kDefaultMajorLineThickness = 1.5;
  static const double _kDefaultMinorLineThickness = 1.0;
  static const double _kDefaultMmLineThickness = 0.5;

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 22;
  static const double _kPaddingValue = 0.0;

  GridUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kMajorLineColorKey] = _kDefaultMajorLineColor;
    this[_kMinorLineColorKey] = _kDefaultMinorLineColor;
    this[_kMmLineColorKey] = _kDefaultMmLineColor;
    this[_kResolutionWidthKey] = _kDefaultResolutionWidth;
    this[_kResolutionHeightKey] = _kDefaultResolutionHeight;
    this[_kScaleKey] = _kDefaultScale;
    this[_kMajorLineSpacingMMKey] = _kDefaultMajorLineSpacingMM;
    this[_kMinorLineSpacingMMKey] = _kDefaultMinorLineSpacingMM;
    this[_kMajorLineThicknessKey] = _kDefaultMajorLineThickness;
    this[_kMinorLineThicknessKey] = _kDefaultMinorLineThickness;
    this[_kMmLineThicknessKey] = _kDefaultMmLineThickness;
  }

  // --- Fragment Visual Setters ---
  set majorLineColor(Color val) => this[_kMajorLineColorKey] = val;
  set minorLineColor(Color val) => this[_kMinorLineColorKey] = val;
  set mmLineColor(Color val) => this[_kMmLineColorKey] = val;

  /// Sets the viewport resolution components into the string registry.
  void setResolution(double width, double height) {
    this[_kResolutionWidthKey] = width;
    this[_kResolutionHeightKey] = height;
  }

  // --- Grid Sizing and Thickness Setters ---
  set scale(double val) => this[_kScaleKey] = val;
  set majorLineSpacingMM(double val) => this[_kMajorLineSpacingMMKey] = val;
  set minorLineSpacingMM(double value) => this[_kMinorLineSpacingMMKey] = value;
  set majorLineThickness(double val) => this[_kMajorLineThicknessKey] = val;
  set minorLineThickness(double val) => this[_kMinorLineThicknessKey] = val;
  set mmLineThickness(double val) => this[_kMmLineThicknessKey] = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);
    int offset = 0;

    offset = packColor(fragmentData, offset, this[_kMajorLineColorKey] as Color);
    offset = packColor(fragmentData, offset, this[_kMinorLineColorKey] as Color);
    offset = packColor(fragmentData, offset, this[_kMmLineColorKey] as Color);

    fragmentData[offset++] = (this[_kResolutionWidthKey] as num).toDouble();
    fragmentData[offset++] = (this[_kResolutionHeightKey] as num).toDouble();
    fragmentData[offset++] = (this[_kScaleKey] as num).toDouble();
    fragmentData[offset++] = (this[_kMajorLineSpacingMMKey] as num).toDouble();
    fragmentData[offset++] = (this[_kMinorLineSpacingMMKey] as num).toDouble();
    fragmentData[offset++] = (this[_kMajorLineThicknessKey] as num).toDouble();
    fragmentData[offset++] = (this[_kMinorLineThicknessKey] as num).toDouble();
    fragmentData[offset++] = (this[_kMmLineThicknessKey] as num).toDouble();

    fragmentData[offset++] = _kPaddingValue; // Padding
    fragmentData[offset++] = _kPaddingValue; // Padding

    return fragmentData;
  }
}
