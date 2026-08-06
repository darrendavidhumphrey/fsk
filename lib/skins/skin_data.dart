import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';
import 'package:fsk/fsk.dart';

typedef SkinObjectDataParser = SkinObjectData? Function(
  XmlElement node,
  Map<String, SkinAnchorData> anchors,
  SkinObjectData? Function(XmlElement, Map<String, SkinAnchorData>) parseObject,
);

class SkinObjectDataFactory {
  static final Map<String, SkinObjectDataParser> _parsers = {};

  static void register(String type, SkinObjectDataParser parser) {
    _parsers[type] = parser;
  }

  static SkinObjectData? parse(
    XmlElement node,
    Map<String, SkinAnchorData> anchors,
    SkinObjectData? Function(XmlElement, Map<String, SkinAnchorData>) parseObject,
  ) {
    final parser = _parsers[node.name.local];
    if (parser != null) {
      return parser(node, anchors, parseObject);
    }
    return null;
  }
}

typedef FskSceneObjectBuilder = FskSceneObject? Function(
  FskScene scene,
  SkinObjectData data,
  FskSceneObject? Function(SkinObjectData) createNode,
);

class FskSceneObjectFactory {
  static final Map<Type, FskSceneObjectBuilder> _builders = {};

  static void register(Type dataType, FskSceneObjectBuilder builder) {
    _builders[dataType] = builder;
  }

  static FskSceneObject? create(
    FskScene scene,
    SkinObjectData data,
    FskSceneObject? Function(SkinObjectData) createNode,
  ) {
    final builder = _builders[data.runtimeType];
    if (builder != null) {
      return builder(scene, data, createNode);
    }
    return null;
  }
}

class SkinData with LoggableClass {
  final String version;
  final Map<String, SkinTextureData> textures;
  final Map<String, SkinFontData> fonts;
  final Map<String, SkinAnchorData> anchors;
  final List<SkinObjectData> objects;
  final Map<String, SkinObjectData> _objectMap = {};
  final Size _skinSize;
  final String? _clearColor;
  final String? _assetsPath;

  Size get skinSize => _skinSize;
  String? get assetsPath => _assetsPath;
  String? get clearColor => _clearColor;

  SkinData({
    required this.version,
    required List<SkinTextureData> textures,
    required List<SkinFontData> fonts,
    required List<SkinAnchorData> anchors,
    required this.objects,
    required this._skinSize,
    required this._clearColor,
    required this._assetsPath,
  })  : textures = {for (var t in textures) t.id: t},
        fonts = {for (var f in fonts) f.id: f},
        anchors = {for (var a in anchors) a.id: a} {
    for (var obj in objects) {
      _registerObject(obj);
    }
  }

  void _registerObject(SkinObjectData obj) {
    _objectMap[obj.id] = obj;
    if (obj is SkinGroupDataExplicit) {
       for (var child in obj.children) {
        _registerObject(child);
      }
    }
  }

  SkinObjectData? findObject(String id) => _objectMap[id];

  void dumpTree() {
    logInfo('📂 SkinData (Version: $version, Size: ${_skinSize.width}x${_skinSize.height} ClearColor ${_clearColor?.toString()} AssetsPath "$_assetsPath")');
    for (int i = 0; i < objects.length; i++) {
      final isLast = i == objects.length - 1;
      _printNode(objects[i], '     ', isLast);
    }
  }

  void _printNode(SkinObjectData obj, String indent, bool isLast) {
    final marker = isLast ? '└── ' : '├── ';
    final nextIndent = indent + (isLast ? '    ' : '│   ');
    logInfo('$indent$marker${obj.runtimeType} [ID: ${obj.id}]');
    if (obj is SkinGroupDataExplicit) {
       for (int i = 0; i < obj.children.length; i++) {
        final isChildLast = i == obj.children.length - 1;
        _printNode(obj.children[i], nextIndent, isChildLast);
      }
    }
  }
}

abstract class SkinGroupDataExplicit extends SkinObjectData {
  SkinGroupDataExplicit({required super.id, required super.visible, super.shader, required super.shaderParams});
  List<SkinObjectData> get children;
}

class SkinTextureData {
  final String id;
  final String file;
  SkinTextureData({required this.id, required this.file});
}

class SkinFontData {
  final String id;
  final String fntFile;
  final String texture;
  SkinFontData({required this.id, required this.fntFile, required this.texture});
}

class SkinAnchorData {
  final String id;
  final Vector3 val;
  SkinAnchorData({required this.id, required this.val});
}

abstract class SkinObjectData {
  final String id;
  final bool visible;
  final String? shader;
  final Map<String, String> shaderParams;
  SkinObjectData({required this.id,required this.visible,this.shader,required this.shaderParams});

  static ReferenceBox screenRectToRefBox(Rect screenRect) {
    return ReferenceBox(
      Vector3(screenRect.left, screenRect.top, 0),
      Vector3(screenRect.width, 0, 0),
      Vector3(0, screenRect.height, 0),
      Vector3(0, 0, 1),
    );
  }
}
