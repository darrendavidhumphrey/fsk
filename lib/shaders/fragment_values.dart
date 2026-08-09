import 'dart:typed_data';
import 'dart:ui';

import 'package:vector_math/vector_math.dart';

/// Encapsulates a reusable buffer for packing fragment shader uniform data.
class FragmentValues {
  final Float32List buffer;
  int _offset = 0;

  int get offset => _offset;

  FragmentValues(int size) : buffer = Float32List(size);

  /// Resets the packing offset to the beginning of the buffer.
  void clear() {
    _offset = 0;
  }

  /// Utility method to pack a color safely.
  /// Handles Color and Vector4 types. Ensures normalized 0.0-1.0 range.
  void packColor(dynamic colorVal) {
    if (colorVal is Color) {
      buffer[_offset++] = colorVal.r;
      buffer[_offset++] = colorVal.g;
      buffer[_offset++] = colorVal.b;
      buffer[_offset++] = colorVal.a;
    } else if (colorVal is Vector4) {
      buffer[_offset++] = colorVal.x;
      buffer[_offset++] = colorVal.y;
      buffer[_offset++] = colorVal.z;
      buffer[_offset++] = colorVal.w;
    } else {
      // Fallback to white
      buffer[_offset++] = 1.0;
      buffer[_offset++] = 1.0;
      buffer[_offset++] = 1.0;
      buffer[_offset++] = 1.0;
    }
  }

  /// Packs a Vector3 into a 4-float slot (vec4 in shader) with w=1.0.
  /// Handles Color, Vector3, and Vector4.
  void packVector3(dynamic value) {
    if (value is Color) {
      buffer[_offset++] = value.r;
      buffer[_offset++] = value.g;
      buffer[_offset++] = value.b;
    } else if (value is Vector3) {
      buffer[_offset++] = value.x;
      buffer[_offset++] = value.y;
      buffer[_offset++] = value.z;
    } else if (value is Vector4) {
      buffer[_offset++] = value.x;
      buffer[_offset++] = value.y;
      buffer[_offset++] = value.z;
    } else {
      // Fallback to neutral grey
      buffer[_offset++] = 0.5;
      buffer[_offset++] = 0.5;
      buffer[_offset++] = 0.5;
    }
    buffer[_offset++] = 1.0; // w component
  }

  /// Packs a boolean as a 1.0 (true) or 0.0 (false) float.
  void packBool(dynamic value) {
    buffer[_offset++] = (value is bool && value) ? 1.0 : 0.0;
  }

  /// Packs a numeric value as a double float.
  void packDouble(dynamic value) {
    buffer[_offset++] = (value as num? ?? 0.0).toDouble();
  }
}