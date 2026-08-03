import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'frame_data.dart';

class FrameSceneBuilder with LoggableClass {
  static bool _initialized = false;

  static void registerDefaults() {
    if (_initialized) return;
    _initialized = true;

    FskQuad.registerWithFactories();
    FskGroup.registerWithFactories();
    FskBitmapText.registerWithFactories();
  }

  final FskFrameScene scene;
  final FrameData? frameData;

  FrameSceneBuilder(this.scene, this.frameData) {
    registerDefaults();
  }

  String getResourcePath(String textureName) {
    if (frameData == null) {
      return textureName;
    }

    if ((frameData!.assetsPath == null) || (frameData!.assetsPath!.isEmpty)) {
      return textureName;
    }
    return '${frameData!.assetsPath}/$textureName';
  }

  FskSceneObject? _createNode(FrameObjectData objData) {
    final node = FskSceneObjectFactory.create(scene, objData, _createNode);

    if (node != null) {
      if (FskGroup.enableDuplicateIdCheck && scene.nodeMap.containsKey(objData.id)) {
        logWarning('Duplicate node ID "${objData.id}" detected in scene hierarchy.');
      }
      scene.nodeMap[objData.id] = node;
    }
    return node;
  }

  Future<bool> buildScene() async {
    if (frameData == null) {
      return false;
    }

    // Set clear color, default to black if not set
    scene.clearColor = parseHexColor(frameData!.clearColor, defaultColor: Colors.black);
    
    // 1. Load textures
    for (var textureData in frameData!.textures.values) {
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
    for (var fontData in frameData!.fonts.values) {
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
    for (var objData in frameData!.objects) {
      final node = _createNode(objData);
      if (node != null) {
        scene.rootNodes.add(node);
      }
    }
    logVerbose("Done building tree");
    return true;
  }
}