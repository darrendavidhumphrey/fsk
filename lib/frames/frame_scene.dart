import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk.dart';
import 'frame_data.dart';

class FrameScene extends FskScene {
  FrameData? _frameData;
  final List<FrameNode> rootNodes = [];
  final Map<String, FrameNode> nodeMap = {};

  bool _sceneIsReady = false;
  bool get sceneIsReady => _sceneIsReady;
  bool skinLoaded = false;

  FrameScene({super.navigationDelegate});

  set frameData(FrameData? value) {
    _frameData = value;
    buildScene();
  }

  FrameData? get frameData => _frameData;

  String getResourcePath(String textureName) {
    if (_frameData == null) {
      return textureName;
    }

    if ((_frameData!.assetsPath == null) || (_frameData!.assetsPath!.isEmpty)) {
      return textureName;
    }
    return '${_frameData!.assetsPath}/$textureName';
  }

  Future<void> buildScene() async {
    if (_frameData == null) {
      return;
    }

    // 1. Load textures
    for (var textureData in _frameData!.textures.values) {
      logVerbose(
        "Loading texture: ID=${textureData.id} path=${textureData.file}, path=${getResourcePath(textureData.file)}",
      );

      await FSK().textureManager.createTextureFromAsset(
        textureData.id,
        getResourcePath(textureData.file),
      );
    }
    logVerbose("Done reading textures");

    // 2. Load fonts
    for (var fontData in _frameData!.fonts.values) {
      String texturePath = getResourcePath(fontData.texture);
      String fontPath = getResourcePath(fontData.fntFile);

      await BitmapFontManager().createFontFromFile(
        fontData.id,
        fontPath,
        texturePath,
      );
    }
    logVerbose("Done registering fonts");

    // 3. Build node tree
    for (var objData in _frameData!.objects) {
      final node = _createNode(
          objData);
      if (node != null) {
        rootNodes.add(node);
      }
    }
    logVerbose("Done building tree");
    _sceneIsReady = true;
  }

  FrameNode? _createNode(FrameObjectData objData) {
    FrameNode? node;
    if (objData is GroupData) {
      final groupNode = FrameGroupNode(this,objData);
      for (var childData in objData.children) {
        final childNode = _createNode(childData);
        if (childNode != null) {
          groupNode.children.add(childNode);
        }
      }
      node = groupNode;
    } else if (objData is QuadData) {
      node = FrameQuadNode(this,objData);
    } else if (objData is FrameTextData) {
      node = FrameTextNode(this,objData);
    }

    if (node != null) {
      nodeMap[objData.id] = node;
    }
    return node;
  }

  @override
  void drawScene(gpu.RenderPass renderPass) {
    if (!sceneIsReady) return;

    super.setupScissor(renderPass);

    mvMatrixStack.current = mvMatrix;

    for (var node in rootNodes) {
      node.draw(renderPass, pMatrix, mvMatrixStack);
    }
  }

  @override
  void dispose() {
    for (var node in rootNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Generic findNode function
  FrameNode? findNode(String id) => nodeMap[id];

  // Type safe findNode function
  T? findNodeByType<T>(String id) {
    var node = nodeMap[id];

    if (node is T) {
      return node as T;
    }

    return null;
  }

  Future<void> loadSkin(String skinPath) async {
    try {
      frameData = await FrameSceneParser.parseFromAssets(skinPath);

      if ((navigationDelegate != null) &&
          (frameData != null) &&
          (navigationDelegate is ScreenRectSubscriber)) {
        var viewRect = Rect.fromLTWH(
          0,
          0,
          frameData!.frameSize.width,
          frameData!.frameSize.height,
        );

        var screenRectSub = navigationDelegate as ScreenRectSubscriber;
        screenRectSub.setViewRect(viewRect);
      }
      skinLoaded = true;
      if (frameData != null) {
        frameData!.dumpTree();
      }
    } catch (e, stackTrace) {
      logError("Error skin XML '$skinPath': $e");
      logError("StackTrace: $stackTrace");
    }
  }
}
