import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

import '../logging.dart';

class FrameData with LoggableClass {
  final String version;
  final Map<String, FrameTextureData> textures;
  final Map<String, FrameFontData> fonts;
  final Map<String, FrameAnchorData> anchors;
  final List<FrameObjectData> objects;
  final Map<String, FrameObjectData> _objectMap = {};
  final Size _frameSize;
  final String? _assetsPath;

  Size get frameSize => _frameSize;
  String? get assetsPath => _assetsPath;

  FrameData({
    required this.version,
    required List<FrameTextureData> textures,
    required List<FrameFontData> fonts,
    required List<FrameAnchorData> anchors,
    required this.objects,
    required this._frameSize,
    required this._assetsPath,
  })  : textures = {for (var t in textures) t.id: t},
        fonts = {for (var f in fonts) f.id: f},
        anchors = {for (var a in anchors) a.id: a} {
    for (var obj in objects) {
      _registerObject(obj);
    }
  }

  void _registerObject(FrameObjectData obj) {
    _objectMap[obj.id] = obj;
    if (obj is GroupData) {
      for (var child in obj.children) {
        _registerObject(child);
      }
    }
  }

  FrameObjectData? findObject(String id) => _objectMap[id];

  void dumpTree() {
    logInfo('📂 FrameData (Version: $version, Size: ${_frameSize.width}x${_frameSize.height} AssetsPath "$_assetsPath")');

    // Print metadata summaries
    logInfo(' ├── 🖼️ Textures (${textures.length}): ${textures.keys.join(', ')}');
    logInfo(' ├── 🔤 Fonts (${fonts.length}): ${fonts.keys.join(', ')}');
    logInfo(' ├── ⚓ Anchors (${anchors.length}): ${anchors.keys.join(', ')}');
    logInfo(' └── 🌳 Scene Hierarchy:');

    // Print object tree recursively
    for (int i = 0; i < objects.length; i++) {
      final isLast = i == objects.length - 1;
      _printNode(objects[i], '     ', isLast);
    }
  }

  void _printNode(FrameObjectData obj, String indent, bool isLast) {
    final marker = isLast ? '└── ' : '├── ';
    final nextIndent = indent + (isLast ? '    ' : '│   ');

    if (obj is GroupData) {
      logInfo('$indent$marker📁 Group [ID: ${obj.id}] (Anchor: ${obj.anchor.x}, ${obj.anchor.y}, ${obj.anchor.z})');
      for (int i = 0; i < obj.children.length; i++) {
        final isChildLast = i == obj.children.length - 1;
        _printNode(obj.children[i], nextIndent, isChildLast);
      }
    } else if (obj is QuadData) {
      final rect = obj.screenRect;
      logInfo('$indent$marker🖼️ Quad [ID: ${obj.id}] (Tex: ${obj.texture}, Rect: [L:${rect.left}, T:${rect.top}, W:${rect.width}, H:${rect.height}])');
    } else if (obj is FrameTextData) {
      logInfo('$indent$marker🔤 Text [ID: ${obj.id}] (Font: ${obj.font}, Text: "${obj.text}")');
    } else {
      logInfo('$indent$marker❓ Unknown Object [ID: ${obj.id}]');
    }
  }
}

class FrameTextureData {
  final String id;
  final String file;

  FrameTextureData({required this.id, required this.file});
}

class FrameFontData {
  final String id;
  final String fntFile;
  final String texture;

  FrameFontData({
    required this.id,
    required this.fntFile,
    required this.texture,
  });
}

class FrameAnchorData {
  final String id;
  final Vector3 val;

  FrameAnchorData({required this.id, required this.val});
}

abstract class FrameObjectData {
  final String id;
  FrameObjectData({required this.id});
}

class QuadData extends FrameObjectData {
  final String texture;
  final Rect screenRect;
  final Rect textureRect;
  final bool premultiplyAlpha;

  QuadData({
    required super.id,
    required this.texture,
    required this.screenRect,
    required this.textureRect,
    this.premultiplyAlpha = false,
  });
}

class GroupData extends FrameObjectData {
  final Vector3 anchor;
  final List<FrameObjectData> children;

  GroupData({
    required super.id,
    required this.anchor,
    required this.children,
  });
}

class FrameTextData extends FrameObjectData {
  final String font;
  final String text;
  final Rect screenRect;
  final String? hJustify;
  final int? maxLen;
  final bool scaleToFit;

  FrameTextData({
    required super.id,
    required this.font,
    required this.text,
    required this.screenRect,
    this.hJustify,
    this.maxLen,
    this.scaleToFit = false,
  });
}
