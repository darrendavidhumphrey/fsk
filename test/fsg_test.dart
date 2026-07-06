import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsk.dart';
import 'package:fsg/native_array/index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() {
  test('tbd', () {

    Vector3 v = Vector3(1,2,3);

    Float32Array array = Float32Array(100);
    Float32ArrayFiller filler = Float32ArrayFiller(array);

    filler.addV3(v);

    expect(array[0], v.x);
    expect(array[1], v.y);
    expect(array[2], v.z);


  });
}
