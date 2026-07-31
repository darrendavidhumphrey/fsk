import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';
import '../fsk.dart';
import 'frame_data.dart';

class FrameSceneParser with LoggableClass {
  static bool _initialized = false;

  static void registerDefaults() {
    if (_initialized) return;
    _initialized = true;

    FskQuad.registerWithFactories();
    FskGroup.registerWithFactories();
    FskBitmapText.registerWithFactories();
  }

  static String assetsRoot = "assets/";
  static Future<FrameData?> parseFromAssets(String assetPath) async {
    String fullPath = assetPath;
    if (!kIsWeb) {
      fullPath = "$assetsRoot$assetPath";
    }
    final String xmlString = await rootBundle.loadString(fullPath);
    return parse(xmlString);
  }

  static bool isVisible(XmlElement node) {
    String? visibleStr = node.getAttribute('visible');

    if (visibleStr != null) {
      return (visibleStr.toLowerCase() == 'true');
    }
    return true;
  }

  static Future<FrameData?> parseFromFile(File file) async {
    final String xmlString = await file.readAsString();
    return parse(xmlString);
  }

  static FrameData? parse(String xmlString) {
    registerDefaults();
    try {
      final document = XmlDocument.parse(xmlString);
      final root = document.getElement('frameScene')!;
      final version = root.getAttribute('version') ?? '1.0';
      final double width = double.tryParse(root.getAttribute('width') ?? '') ??
          1280.0;
      final double height = double.tryParse(
          root.getAttribute('height') ?? '') ?? 720.0;
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
            val: parseVector3(node.getAttribute('val')!, {}),
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
        clearColor: root.getAttribute('clearColor'),
        assetsPath: assetsPath,
        version: version,
        textures: textures,
        fonts: fonts,
        anchors: anchors.values.toList(),
        objects: objects,
      );
    }
    catch (e, stackTrace) {
      Logging.log(LogLevel.error, "Error loading frame file': $e", source: "FrameSceneParser");
      Logging.log(LogLevel.error, "StackTrace: $stackTrace", source: "FrameSceneParser");
      return null;
    }
  }

  static Rect parseTextureRect(String ?rectString) {
    if (rectString != null) {
      return parseRect(rectString);
    }

    // If no rectString is provided, return a default value
    return Rect.fromLTWH(0, 0, 1, 1);
  }

  static FrameObjectData? _parseObject(XmlElement node, Map<String, FrameAnchorData> anchors) {
    return FrameObjectDataFactory.parse(node, anchors, _parseObject);
  }

  static Rect parseRect(String s) {
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

  static Vector3 parseVector3(String s, Map<String, FrameAnchorData> anchors) {
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

  /// Converts a semicolon or comma-separated key:value string into a Map configuration profile.
  /// Semicolons are preferred as delimiters when values (like vectors) contain commas.
  static Map<String, String> parseShaderParams(String? rawParams) {
    final Map<String, String> paramsMap = {};
    if (rawParams == null || rawParams.trim().isEmpty) {
      return paramsMap;
    }

    // Try splitting by semicolon first as it's the safer delimiter for complex values
    List<String> pairs;
    if (rawParams.contains(';')) {
      pairs = rawParams.split(';');
    } else {
      // Fallback to comma if no semicolons are found, 
      // but this may fail if vector values also use commas.
      pairs = rawParams.split(',');
    }

    for (final pair in pairs) {
      final indexOfColon = pair.indexOf(':');
      if (indexOfColon != -1) {
        final key = pair.substring(0, indexOfColon).trim();
        final value = pair.substring(indexOfColon + 1).trim();
        if (key.isNotEmpty) {
          paramsMap[key] = value;
        }
      }
    }
    return paramsMap;
  }
}
