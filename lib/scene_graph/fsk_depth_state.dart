import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/scene_graph/fsk_scene_object.dart';

class FskDepthState {
  bool depthTestEnabled;
  bool depthWriteEnabled;
  gpu.CompareFunction depthCompareOperation;

  FskDepthState({
    this.depthTestEnabled = true,
    this.depthWriteEnabled = true,
    this.depthCompareOperation = gpu.CompareFunction.lessEqual,
  });

  void setDepthState({
    bool? depthTestEnabled,
    bool? depthWriteEnabled,
    gpu.CompareFunction? depthCompareOperation,
  }) {
    if (depthTestEnabled != null) this.depthTestEnabled = depthTestEnabled;
    if (depthWriteEnabled != null) this.depthWriteEnabled = depthWriteEnabled;
    if (depthCompareOperation != null) this.depthCompareOperation = depthCompareOperation;
  }
}

mixin FskDepthStateMixin on FskRenderableObject {
  bool get depthTestEnabled => renderer?.depthState.depthTestEnabled ?? true;
  set depthTestEnabled(bool value) {
    if (renderer == null) return;
    renderer!.depthState.depthTestEnabled = value;
    renderer!.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  bool get depthWriteEnabled => renderer?.depthState.depthWriteEnabled ?? true;
  set depthWriteEnabled(bool value) {
    if (renderer == null) return;
    renderer!.depthState.depthWriteEnabled = value;
    renderer!.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  gpu.CompareFunction get depthCompareOperation =>
      renderer?.depthState.depthCompareOperation ?? gpu.CompareFunction.lessEqual;
  set depthCompareOperation(gpu.CompareFunction value) {
    if (renderer == null) return;
    renderer!.depthState.depthCompareOperation = value;
    renderer!.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  void setDepthState({
    bool? depthTestEnabled,
    bool? depthWriteEnabled,
    gpu.CompareFunction? depthCompareOperation,
  }) {
    if (renderer == null) return;
    renderer!.depthState.setDepthState(
      depthTestEnabled: depthTestEnabled,
      depthWriteEnabled: depthWriteEnabled,
      depthCompareOperation: depthCompareOperation,
    );
    renderer!.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }
}
