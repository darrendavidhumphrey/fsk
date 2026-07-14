import 'dart:ui';

import 'package:flutter_angle/flutter_angle.dart';
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

  // Stub: Override this to perform an action as soon as the scene is ready
  // For example, mapping named nodes to objects
  void onSceneReady() {}

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
      final node = _createNode(objData);
      if (node != null) {
        rootNodes.add(node);
      }
    }
    logVerbose("Done building tree");
    // 4. Initialize nodes
    for (var node in rootNodes) {
      node.init(gls);
    }
    logVerbose("Done initializing tree");
    _sceneIsReady = true;

    // Allow derived class to call custom initialization
    onSceneReady();
  }

  FrameNode? _createNode(FrameObjectData objData) {
    FrameNode? node;
    if (objData is GroupData) {
      final groupNode = FrameGroupNode(objData);
      for (var childData in objData.children) {
        final childNode = _createNode(childData);
        if (childNode != null) {
          groupNode.children.add(childNode);
        }
      }
      node = groupNode;
    } else if (objData is QuadData) {
      node = FrameQuadNode(objData);
    } else if (objData is FrameTextData) {
      node = FrameTextNode(objData);
    }

    if (node != null) {
      nodeMap[objData.id] = node;
    }
    return node;
  }

  @override
  void drawScene() {
    super.drawScene();
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    gls.setDepthTest(false);
    gls.setBlend(true);
    gls.blendFuncSeparate(
      WebGL.SRC_ALPHA,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.SRC_ALPHA,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    mvMatrixStack.current = mvMatrix;

    for (var node in rootNodes) {
      node.draw(gls, pMatrix, mvMatrixStack);
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

  // Gets a UniformValue for a given node and uniform name
  // Simply call foo.value on the return result to set the uniform value,
  // which will be applied on the next frame
  // The set of uniforms available for a given node depend the shader that is set
  // Returns null if the node is not found
  // Returns null if the shader is not set on the node
  // Returns null if the uniform is not found in the shader
  UniformValue ?findObjectUniform(String nodeName,String uniformName){
    var node = findNodeByType<FrameQuadNode>(nodeName);
    if (node != null) {
      var object = node.object;
      if (object != null) {
        if (object.shader != null) {
          var uniformDef = object.shader!.uniforms[uniformName];
          if (uniformDef != null) {

            return object.getUniformValue(uniformDef);
          }
        }
      }
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
