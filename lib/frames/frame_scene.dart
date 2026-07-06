import 'package:flutter_angle/flutter_angle.dart';
import '../fsk.dart';
import 'frame_data.dart';
import 'frame_scene_nodes.dart';

class FrameScene extends FskScene {
  late FrameData _data;
  final List<FrameNode> rootNodes = [];
  final Map<String, FrameNode> nodeMap = {};

  bool _sceneIsReady = false;
  bool get sceneIsReady => _sceneIsReady;

  FrameScene();


  set data(FrameData value) {
    _data = value;
    buildScene();
  }

  String getResourcePath(String textureName) {
    if ((_data.assetsPath == null) || (_data.assetsPath!.isEmpty)) {
      return textureName;
    }
    return '${_data.assetsPath}/$textureName';
  }

  Future<void> buildScene() async {
    // 1. Load textures
    for (var textureData in _data.textures.values) {

      logVerbose("Loading texture: ID=${textureData.id} path=${textureData.file}, path=${getResourcePath(textureData.file)}");

      await FSK().textureManager.createTextureFromAsset(textureData.id,getResourcePath(textureData.file));
    }
    logVerbose("Done reading textures");

    // 2. Load fonts
    for (var fontData in _data.fonts.values) {
      String texturePath = getResourcePath(fontData.texture);
      String fontPath = getResourcePath(fontData.fntFile);

      await BitmapFontManager().createFontFromFile(fontData.id,fontPath, texturePath);
    }
    logVerbose("Done registering fonts");

    // 3. Build node tree
    for (var objData in _data.objects) {
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
    gls.blendFuncSeparate(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA,WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
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

  FrameNode? findNode(String id) => nodeMap[id];

  void setVisible(String id, bool visible) {
    findNode(id)?.visible = visible;
  }

  void setText(String id, String text) {
    final node = findNode(id);
    if (node is FrameTextNode) {
      node.object?.setText(text);
    }
  }
}
