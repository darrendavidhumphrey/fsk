import 'dart:ui' as ui;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

import '../util.dart';

class FskRenderTarget {
  final int width;
  final int height;
  final bool enableMsaa;

  gpu.Texture? _msaaColorTexture;
  gpu.Texture? _resolveTexture;
  gpu.Texture? _depthTexture;
  gpu.RenderTarget? _renderTarget;
  ui.Color clearColor;

  FskRenderTarget({
    required this.width,
    required this.height,
    required this.enableMsaa,
    required this.clearColor,
  }) {
    _allocateResources();
  }

  /// Expose the render target configuration required by the CommandBuffer.
  gpu.RenderTarget get renderTarget => _renderTarget!;

  /// Expose the final single-sample texture read by the canvas/samplers.
  gpu.Texture get outputTexture => _resolveTexture!;

  /// The sample count matches the texture layout boundaries (4 for MSAA, 1 for standard).
  int get sampleCount => enableMsaa ? 4 : 1;

  void _allocateResources() {
    _resolveTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
    );

    _depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      width,
      height,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
    );

    final depthAttachment = gpu.DepthStencilAttachment(
      texture: _depthTexture!,
      depthClearValue: 1.0,
      depthLoadAction: gpu.LoadAction.clear,
      depthStoreAction: gpu.StoreAction.dontCare,
    );

    if (enableMsaa && gpu.gpuContext.doesSupportOffscreenMSAA) {
      _msaaColorTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.deviceTransient,
        width,
        height,
        format: gpu.PixelFormat.r8g8b8a8UNormInt,
        sampleCount: 4,
        enableRenderTargetUsage: true,
        enableShaderReadUsage: false,
      );

      final msaaAttachment = gpu.ColorAttachment(
        texture: _msaaColorTexture!,
        resolveTexture: _resolveTexture!,
        clearValue: Vector4(0, 0, 0, 0),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.multisampleResolve,
      );

      _renderTarget = gpu.RenderTarget(
        colorAttachments: [msaaAttachment],
        depthStencilAttachment: depthAttachment,
      );
    } else {
      final standardAttachment = gpu.ColorAttachment(
        texture: _resolveTexture!,
        clearValue: colorToVector(clearColor),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      );

      _renderTarget = gpu.RenderTarget(
        colorAttachments: [standardAttachment],
        depthStencilAttachment: depthAttachment,
      );
    }
  }
}
