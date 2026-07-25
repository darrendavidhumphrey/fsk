import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

class FskTextureInfo {
  String id;
  String url;
  gpu.Texture? texture;

  // FIX: Swapped Sampler objects out for flutter_gpu's consolidated SamplerOptions state mapping
  gpu.SamplerOptions samplerOptions;
  bool isLoaded = false;

  FskTextureInfo(this.id, this.url, this.samplerOptions);
}

/// A manager for loading, creating, and caching flutter_gpu textures.
class FskTextureManager {
  final Map<String, FskTextureInfo> _textures = {};

  static String assetsRoot = "assets/";

  FskTextureManager();

  void dump() {
    _textures.forEach((id, textureInfo) {
      debugPrint("Texture: ID=$id, path=${textureInfo.url}");
    });
  }

  /// Loads an image from assets and creates a modern flutter_gpu texture directly.
  Future<FskTextureInfo> createTextureFromAsset(
      String id,
      String url, {
        gpu.MinMagFilter magFilter = gpu.MinMagFilter.linear,
        gpu.MinMagFilter minFilter = gpu.MinMagFilter.linear,
        gpu.SamplerAddressMode wrapS = gpu.SamplerAddressMode.repeat,
        gpu.SamplerAddressMode wrapT = gpu.SamplerAddressMode.repeat,
      }) async {
    if (_textures.containsKey(id)) {
      debugPrint("Skip Loading Texture ID $id (already exists)");
      return _textures[id]!;
    }

    // FIX: Bundle sampling parameters directly inside a unified SamplerOptions object
    final gpu.SamplerOptions samplerOptions = gpu.SamplerOptions(
      minFilter: minFilter,
      magFilter: magFilter,
      widthAddressMode: wrapS,
      heightAddressMode: wrapT,
    );

    var textureInfo = FskTextureInfo(id, url, samplerOptions);
    _textures[id] = textureInfo;

    String fullPath = '$assetsRoot$url';
    debugPrint("createTextureFromAsset: ID=$id, path=$fullPath");

    try {
      final ByteData data = await rootBundle.load(fullPath);

      final Codec codec = await instantiateImageCodec(data.buffer.asUint8List());
      final FrameInfo frameInfo = await codec.getNextFrame();
      final Image uiImage = frameInfo.image;

      final ByteData? byteData = await uiImage.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw Exception("Could not convert image to raw RGBA bytes.");
      }

      // Allocate the physical hardware texture allocation
      final gpu.Texture allocatedTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.hostVisible,
        uiImage.width,
        uiImage.height,
        format: gpu.PixelFormat.r8g8b8a8UNormInt,
      );
      textureInfo.texture = allocatedTexture;

      textureInfo.isLoaded = textureInfo.texture != null;
    } catch (e) {
      debugPrint("Error processing flutter_gpu texture allocation for $url: $e");
      textureInfo.isLoaded = false;
    }

    return textureInfo;
  }

  FskTextureInfo? getTextureInfo(String id) {
    return _textures[id];
  }

  /// Optional WebGL fallback shim. Completely bypassed under modern graphics backends.
  Future<void> bindUnboundTextures() async {
    return;
  }

  /// Disposes all cached textures and unlinks physical memory references.
  void dispose() {
    for (var info in _textures.values) {
      info.texture = null; // Unlocks reference chains so the GPU can safely clean up hardware memory
    }
    _textures.clear();
  }
}