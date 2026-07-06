import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';
import 'frame_data.dart';

class FrameSceneParser {

  static String assetsRoot = "assets/";
  static Future<FrameData> parseFromAssets(String assetPath) async {
    String fullPath = assetPath;
    if (!kIsWeb) {
      fullPath = "$assetsRoot$assetPath";
    }
    final String xmlString = await rootBundle.loadString(fullPath);
    return parse(xmlString);
  }

  static Future<FrameData> parseFromFile(File file) async {
    final String xmlString = await file.readAsString();
    return parse(xmlString);
  }

  static FrameData parse(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final root = document.getElement('frameScene')!;
    final version = root.getAttribute('version') ?? '1.0';
    final double width = double.tryParse(root.getAttribute('width') ?? '') ?? 1280.0;
    final double height = double.tryParse(root.getAttribute('height') ?? '') ?? 720.0;
    final String? assetsPath = root.getAttribute('assetsPath');

    final textures = <FrameTextureData>[];
    final texturesElement = root.getElement('textures');
    if (texturesElement != null) {
      for (final node in texturesElement.findElements('texture')) {
        textures.add(FrameTextureData(
          id: node.getAttribute('id')!,
          file: node.getAttribute('file')!,
        ));
      }
    }

    final fonts = <FrameFontData>[];
    final fontsElement = root.getElement('fonts');
    if (fontsElement != null) {
      for (final node in fontsElement.findElements('font')) {
        fonts.add(FrameFontData(
          id: node.getAttribute('id')!,
          fntFile: node.getAttribute('fntFile')!,
          texture: node.getAttribute('texture')!,
        ));
      }
    }

    final anchors = <String, FrameAnchorData>{};
    final anchorsElement = root.getElement('anchors');
    if (anchorsElement != null) {
      for (final node in anchorsElement.findElements('anchor')) {
        final id = node.getAttribute('id')!;
        anchors[id] = FrameAnchorData(
          id: id,
          val: _parseVector3(node.getAttribute('val')!, {}),
        );
      }
    }

    final objects = <FrameObjectData>[];
    final objectsElement = root.getElement('objects');
    if (objectsElement != null) {
      for (final node in objectsElement.children.whereType<XmlElement>()) {
        final obj = _parseObject(node, anchors);
        if (obj != null) {
          objects.add(obj);
        }
      }
    }

    return FrameData(
      frameSize: Size(width, height),
      assetsPath: assetsPath,
      version: version,
      textures: textures,
      fonts: fonts,
      anchors: anchors.values.toList(),
      objects: objects,
    );
  }

  static FrameObjectData? _parseObject(XmlElement node, Map<String, FrameAnchorData> anchors) {
    switch (node.name.local) {
      case 'quad':
        return QuadData(
          id: node.getAttribute('id')!,
          texture: node.getAttribute('texture')!,
          screenRect: _parseRect(node.getAttribute('screenRect')!),
          textureRect: _parseRect(node.getAttribute('textureRect')!),
          premultiplyAlpha: node.getAttribute('premultiplyAlpha') == 'true',
        );
      case 'group':
        final children = <FrameObjectData>[];
        // Directly iterate through the child XML elements of the group node
        for (final childNode in node.children.whereType<XmlElement>()) {
          final child = _parseObject(childNode, anchors);
          if (child != null) {
            children.add(child);
          }
        }
        return GroupData(
          id: node.getAttribute('id')!,
          anchor: _parseVector3(node.getAttribute('anchor')!, anchors),
          children: children,
        );
      case 'text':
        return FrameTextData(
          id: node.getAttribute('id')!,
          font: node.getAttribute('font')!,
          text: node.getAttribute('text')!,
          screenRect: _parseRect(node.getAttribute('screenRect')!),
          hJustify: node.getAttribute('hJustify'),
          maxLen: int.tryParse(node.getAttribute('maxLen') ?? ''),
          scaleToFit: node.getAttribute('scaleToFit') == 'YES',
        );
      default:
        return null;
    }
  }

  static Rect _parseRect(String s) {
    final regex = RegExp(
        r'\{\{\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*\}\s*,\s*\{\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*\}\}');
    final match = regex.firstMatch(s);
    if (match != null) {
      double x = double.parse(match.group(1)!);
      double y = double.parse(match.group(2)!);
      double w = double.parse(match.group(3)!);
      double h = double.parse(match.group(4)!);
      return Rect.fromLTWH(x, y, w, h);
    }
    return Rect.zero;
  }

  static Vector3 _parseVector3(String s, Map<String, FrameAnchorData> anchors) {
    if (anchors.containsKey(s)) {
      return anchors[s]!.val.clone();
    }
    final regex = RegExp(
        r'\{\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*\}');
    final match = regex.firstMatch(s);
    if (match != null) {
      double x = double.parse(match.group(1)!);
      double y = double.parse(match.group(2)!);
      double z = double.parse(match.group(3)!);
      return Vector3(x, y, z);
    }
    return Vector3.zero();
  }
}
