import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test('FskMtsdfText creation and properties', () {
    // This is a simple unit test for the object structure
    // Since we don't have a GPU context here, we can't fully render.
    // But we can check if the base class and properties are correctly set.
    
    final scene = FskScene();
    final font = TextureFont.fromXml("test_font", """
      <font>
        <info face="Arial" size="32" />
        <common lineHeight="32" base="26" scaleW="256" scaleH="256" />
        <pages><page id="0" file="test.png" /></pages>
        <chars count="1">
          <char id="65" x="0" y="0" width="10" height="10" xoffset="0" yoffset="0" xadvance="10" page="0" chnl="15" />
        </chars>
      </font>
    """);
    
    final text = FskMtsdfText(
      "test_mtsdf",
      scene,
      ReferenceBox.fromCenterSize(vm.Vector3.zero(), const Size(100, 20)),
      font: font,
      text: "A",
      textColor: Colors.red,
      glowColor: Colors.blue,
      glowSize: 0.1,
    );
    
    expect(text.text, equals("A"));
    expect(text.textColor, equals(Colors.red));
    expect(text.glowColor, equals(Colors.blue));
    expect(text.glowSize, equals(0.1));
    expect(text.shaderMaterial, equals(FskShaderMaterial.mtsdfText));
  });
}
