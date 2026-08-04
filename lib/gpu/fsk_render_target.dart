import 'dart:ui' as ui;
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../util.dart';

class FskRenderTarget {
  final int width;
  final int height;
  final bool enableMsaa;

  gpu.Texture? _msaaColorTexture;
  gpu.Texture? _resolveTexture;
  gpu.Texture? _depthTexture;
  gpu.RenderTarget? _renderTargetClear;
  gpu.RenderTarget? _renderTargetLoad;
  ui.Color clearColor;

  FskRenderTarget({
    required this.width,
    required this.height,
    required this.enableMsaa,
    required this.clearColor,
  }) {
    _allocateResources();
  }

  /// Expose the render target configuration for clearing the frame.
  gpu.RenderTarget get renderTarget => _renderTargetClear!;

  /// Expose the render target configuration for loading existing content.
  gpu.RenderTarget get loadTarget => _renderTargetLoad!;

  /// Expose the final single-sample texture read by the canvas/samplers.
  gpu.Texture get outputTexture => _resolveTexture!;

  /// The sample count matches the texture layout boundaries (4 for MSAA, 1 for standard).
  int get sampleCount => enableMsaa ? 4 : 1;

  void _allocateResources() {
    _resolveTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      width,
      height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
    );

    _depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
    );

    final depthAttachmentClear = gpu.DepthStencilAttachment(
      texture: _depthTexture!,
      depthClearValue: 1.0,
      depthLoadAction: gpu.LoadAction.clear,
      depthStoreAction: gpu.StoreAction.store, // Keep depth for subsequent passes
    );

    final depthAttachmentLoad = gpu.DepthStencilAttachment(
      texture: _depthTexture!,
      depthLoadAction: gpu.LoadAction.load,
      depthStoreAction: gpu.StoreAction.store,
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

      final colorAttachmentClear = gpu.ColorAttachment(
        texture: _msaaColorTexture!,
        resolveTexture: _resolveTexture!,
        clearValue: colorToVector(clearColor),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.multisampleResolve,
      );

      final colorAttachmentLoad = gpu.ColorAttachment(
        texture: _msaaColorTexture!,
        resolveTexture: _resolveTexture!,
        loadAction: gpu.LoadAction.load,
        storeAction: gpu.StoreAction.multisampleResolve,
      );

      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [colorAttachmentClear],
        depthStencilAttachment: depthAttachmentClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentLoad,
      );
    } else {
      final colorAttachmentClear = gpu.ColorAttachment(
        texture: _resolveTexture!,
        clearValue: colorToVector(clearColor),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      );

      final colorAttachmentLoad = gpu.ColorAttachment(
        texture: _resolveTexture!,
        loadAction: gpu.LoadAction.load,
        storeAction: gpu.StoreAction.store,
      );

      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [colorAttachmentClear],
        depthStencilAttachment: depthAttachmentClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentLoad,
      );
    }
  }
}
