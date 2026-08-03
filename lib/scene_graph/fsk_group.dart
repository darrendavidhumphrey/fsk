import 'dart:ui';

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';
import '../frames/frame_data.dart';

class FrameGroupData extends FrameGroupDataExplicit {
  final Vector3 anchor;
  @override
  final List<FrameObjectData> children;

  FrameGroupData({
    required super.id,
    required super.visible,
    super.shader,
    required super.shaderParams,
    required this.anchor,
    required this.children,
  });
}

class FskGroup extends FskRenderableObject with FskTransformableMixin {
  /// Global flag to enable or disable duplicate ID checks for performance.
  static bool enableDuplicateIdCheck = true;

  final List<FskSceneObject> children = [];

  static void registerWithFactories() {
    FrameObjectDataFactory.register('group', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap = FrameSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      final children = <FrameObjectData>[];
      for (final childNode in node.children.whereType<XmlElement>()) {
        final child = parseObject(childNode, anchors);
        if (child != null) {
          children.add(child);
        }
      }
      return FrameGroupData(
        id: node.getAttribute('id')!,
        visible: FrameSceneParser.isVisible(node),
        anchor: FrameSceneParser.parseVector3(node.getAttribute('anchor')!, anchors),
        children: children,
        shader: shaderName,
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(FrameGroupData, (scene, data, createNode) {
      final groupData = data as FrameGroupData;
      final groupNode = FskGroup.fromData(groupData.id, scene, groupData);
      for (var childData in groupData.children) {
        final childNode = createNode(childData);
        if (childNode != null) {
          groupNode.addNode(childNode);
        }
      }
      return groupNode;
    });
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskGroup(super.id,super.parentScene);

  FskGroup.fromData(super.id,super.parentScene, FrameGroupData data) {

    if (data.anchor.x != 0 || data.anchor.y != 0 || data.anchor.z != 0) {
      transformable.anchor = data.anchor;
    }
    visible = data.visible;
  }

  /// Adds a child node to this group.
  void addNode(FskSceneObject node) {
    if (enableDuplicateIdCheck) {
      for (final child in children) {
        if (child.id == node.id) {
          logWarning('Duplicate node ID "${node.id}" added to group "$id".');
          break;
        }
      }
    }
    children.add(node);
  }

  @override
  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
      Size viewportSize,
      ) {
    if (!visible) return;

    // Create the child object's local translation matrix
    final Matrix4 localTranslation = Matrix4.identity();

    // Handle dynamic translations
    if (transformable.isTransformed()) {
      localTranslation.setFrom(transformable.getTransform());
    }

    // Pass down the fully computed local-to-world context downward
    for (var child in children) {
      // Clone the incoming matrix to ensure absolute isolation between child branches
      final Matrix4 mvTrans = mvMatrix.clone()..multiply(localTranslation);

      if (child is FskRenderableObject) {
        child.draw(renderPass, transients, pMatrix, mvTrans, viewportSize);
      }
    }
  }

  @override
  void rebuildGeometry() {
    for (var child in children) {
      child.rebuildGeometry();
    }
  }

  @override
  void rebuildPipelineIfNeeded() {
    for (var child in children) {
      child.rebuildPipelineIfNeeded();
    }
  }

  @override
  T? findNodeRecursive<T>(List<String> parts) {
    if (parts.isEmpty) return null;

    if (id == parts[0]) {
      if (parts.length == 1) {
        return (this is T) ? this as T : null;
      }
      final remaining = parts.sublist(1);
      for (final child in children) {
        final result = child.findNodeRecursive<T>(remaining);
        if (result != null) return result;
      }
    } else {
      // Try to find the start of the path in the children
      for (final child in children) {
        final result = child.findNodeRecursive<T>(parts);
        if (result != null) return result;
      }
    }
    return null;
  }
}
