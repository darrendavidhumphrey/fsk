import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../fsk.dart';

class FskMtlxLoader {
  static Future<void> loadIntoUniforms(String assetPath, PbrUniforms uniforms) async {
    final String content = await rootBundle.loadString(assetPath);
    final document = XmlDocument.parse(content);
    
    // Find all tiledimage nodes
    final images = document.findAllElements('tiledimage');
    
    for (var image in images) {
      final name = image.getAttribute('name');
      final fileInput = image.findElements('input').firstWhere(
        (node) => node.getAttribute('name') == 'file',
        orElse: () => throw Exception('Missing file input in mtlx image node'),
      );
      
      final fileName = fileInput.getAttribute('value')!;
      
      if (name != null) {
        final info = await FSK().textureManager.createTextureFromAsset(name, fileName);
        
        // Ensure the uniforms use the tiling/sampling options from the material
        uniforms.samplerOptions = info.samplerOptions;

        if (name.toLowerCase().contains('color')) {
          uniforms.texture = info.texture;
        } else if (name.toLowerCase().contains('normal')) {
          uniforms.normalMap = info.texture;
        } else if (name.toLowerCase().contains('roughness')) {
          uniforms.metallicRoughnessMap = info.texture;
        }
      }
    }
  }
}
