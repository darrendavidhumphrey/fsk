import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';
import '../fsk.dart';

typedef FrameObjectDataParser = FrameObjectData? Function(
  XmlElement node,
  Map<String, FrameAnchorData> anchors,
  FrameObjectData? Function(XmlElement, Map<String, FrameAnchorData>) parseObject,
);

class FrameObjectDataFactory {
  static final Map<String, FrameObjectDataParser> _parsers = {};

  static void register(String type, FrameObjectDataParser parser) {
    _parsers[type] = parser;
  }

  static FrameObjectData? parse(
    XmlElement node,
    Map<String, FrameAnchorData> anchors,
    FrameObjectData? Function(XmlElement, Map<String, FrameAnchorData>) parseObject,
  ) {
    final parser = _parsers[node.name.local];
    if (parser != null) {
      return parser(node, anchors, parseObject);
    }
    return null;
  }
}

typedef FskSceneObjectBuilder = FskSceneObject? Function(
  FskFrameScene scene,
  FrameObjectData data,
  FskSceneObject? Function(FrameObjectData) createNode,
);

class FskSceneObjectFactory {
  static final Map<Type, FskSceneObjectBuilder> _builders = {};

  static void register(Type dataType, FskSceneObjectBuilder builder) {
    _builders[dataType] = builder;
  }

  static FskSceneObject? create(
    FskFrameScene scene,
    FrameObjectData data,
    FskSceneObject? Function(FrameObjectData) createNode,
  ) {
    final builder = _builders[data.runtimeType];
    if (builder != null) {
      return builder(scene, data, createNode);
    }
    return null;
  }
}

class FrameData with LoggableClass {
  final String version;
  final Map<String, FrameTextureData> textures;
  final Map<String, FrameFontData> fonts;
  final Map<String, FrameAnchorData> anchors;
  final List<FrameObjectData> objects;
  final Map<String, FrameObjectData> _objectMap = {};
  final Size _frameSize;
  final String? _clearColor;
  final String? _assetsPath;

  Size get frameSize => _frameSize;
  String? get assetsPath => _assetsPath;
  String? get clearColor => _clearColor;

  FrameData({
    required this.version,
    required List<FrameTextureData> textures,
    required List<FrameFontData> fonts,
    required List<FrameAnchorData> anchors,
    required this.objects,
    required this._frameSize,
    required this._clearColor,
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
    if (obj is FrameGroupDataExplicit) {
       for (var child in obj.children) {
        _registerObject(child);
      }
    }
  }

  FrameObjectData? findObject(String id) => _objectMap[id];

  void dumpTree() {
    logInfo('📂 FrameData (Version: $version, Size: ${_frameSize.width}x${_frameSize.height} ClearColor ${_clearColor?.toString()} AssetsPath "$_assetsPath")');
    for (int i = 0; i < objects.length; i++) {
      final isLast = i == objects.length - 1;
      _printNode(objects[i], '     ', isLast);
    }
  }

  void _printNode(FrameObjectData obj, String indent, bool isLast) {
    final marker = isLast ? '└── ' : '├── ';
    final nextIndent = indent + (isLast ? '    ' : '│   ');
    logInfo('$indent$marker${obj.runtimeType} [ID: ${obj.id}]');
    if (obj is FrameGroupDataExplicit) {
       for (int i = 0; i < obj.children.length; i++) {
        final isChildLast = i == obj.children.length - 1;
        _printNode(obj.children[i], nextIndent, isChildLast);
      }
    }
  }
}

abstract class FrameGroupDataExplicit extends FrameObjectData {
  FrameGroupDataExplicit({required super.id, required super.visible, super.shader, required super.shaderParams});
  List<FrameObjectData> get children;
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
  FrameFontData({required this.id, required this.fntFile, required this.texture});
}

class FrameAnchorData {
  final String id;
  final Vector3 val;
  FrameAnchorData({required this.id, required this.val});
}

abstract class FrameObjectData {
  final String id;
  final bool visible;
  final String? shader;
  final Map<String, String> shaderParams;
  FrameObjectData({required this.id,required this.visible,this.shader,required this.shaderParams});

  static ReferenceBox screenRectToRefBox(Rect screenRect) {
    return ReferenceBox(
      Vector3(screenRect.left, screenRect.top, 0),
      Vector3(screenRect.width, 0, 0),
      Vector3(0, screenRect.height, 0),
      Vector3(0, 0, 1),
    );
  }
}
