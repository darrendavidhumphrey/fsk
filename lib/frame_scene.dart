import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart';
import 'fsg.dart';
import 'frame_data.dart';
import 'frame_scene_nodes.dart';

class FrameScene extends Scene {
  late FrameData _data;
  final List<FrameNode> rootNodes = [];
  final Map<String, FrameNode> nodeMap = {};
  final Map<String, WebGLTexture> textureMap = {};
  bool _sceneIsReady = false;
  bool get sceneIsReady => _sceneIsReady;
  String _assetsPath = "";

  FrameScene();

  set assetsPath(String value) {
    _assetsPath = value;
  }

  set data(FrameData value) {
    _data = value;
    buildScene();
  }

  String getTexturePath(String textureName) {
    if (_assetsPath.isEmpty) {
      return textureName;
    }
    return '$_assetsPath/$textureName';
  }
  Future<void> buildScene() async {
    // 1. Load textures
    for (var textureData in _data.textures.values) {
      logVerbose("Loading texture: ${textureData.file}, full path is ${getTexturePath(textureData.file)}");
       var texInfo = await FSG().textureManager.createTextureFromAsset(getTexturePath(textureData.file));
      logVerbose("Did texture ${textureData.file} load? ${texInfo.isLoaded}");
    }
    logVerbose("Done reading textures");

    // 2. Load fonts
    for (var fontData in _data.fonts.values) {
      // Assuming BitmapFontManager has a way to load from asset strings, 
      // but the current implementation of createFont uses hardcoded asset logic.
      // For now, we assume fonts are already registered or we'd need to fetch their XML.
      // This part might need more robust asset loading.

      // TODO: Implement this
    }
/*
    // 3. Build node tree
    for (var objData in _data.objects) {
      final node = _createNode(objData);
      if (node != null) {
        rootNodes.add(node);
      }
    }

    // 4. Initialize nodes
    for (var node in rootNodes) {
      node.init(gls);
    }

    // 5. Assign textures to quads
    _assignTextures();
 */
    _sceneIsReady = true;
  }

  void _assignTextures() {
    for (var node in nodeMap.values) {
      if (node is FrameQuadNode) {
        final quadData = node.data as QuadData;
        node.texture = textureMap[quadData.texture];
      }
    }
  }

  FrameNode? _createNode(SceneObject objData) {
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
    } else if (objData is TextData) {
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

    mvMatrixStack.current = Matrix4.identity();
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
      node.bitmapText?.setText(text);
    }
  }
}
