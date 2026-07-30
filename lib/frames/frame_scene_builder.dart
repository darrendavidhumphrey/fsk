import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'frame_data.dart';

class FrameSceneBuilder with LoggableClass {

  final FskFrameScene scene;
  final FrameData? frameData;

  FrameSceneBuilder(this.scene, this.frameData);

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
    FskSceneObject? node;
    if (objData is FrameGroupData) {
      final groupNode = FskGroup.fromData(objData.id,scene, objData);
      for (var childData in objData.children) {
        final childNode = _createNode(childData);
        if (childNode != null) {
          groupNode.children.add(childNode);
        }
      }
      node = groupNode;
    } else if (objData is FrameQuadData) {
      node = FskQuad.fromData(objData.id,scene, objData);
    } else if (objData is FrameTextData) {
      node = FskBitmapText.fromData(objData.id,scene,objData);
    }

    if (node != null) {
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

    print("clearColor: ${scene.clearColor}");
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