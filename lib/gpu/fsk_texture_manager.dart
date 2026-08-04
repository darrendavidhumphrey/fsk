import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../logging.dart';
import '../fsk_singleton.dart';

class FskTextureInfo {
  String id;
  String url;
  gpu.Texture? texture;

  gpu.SamplerOptions samplerOptions;
  bool isLoaded = false;

  FskTextureInfo(this.id, this.url, this.samplerOptions);
}

/// A manager for loading, creating, and caching flutter_gpu textures.
class FskTextureManager with LoggableClass {
  final Map<String, FskTextureInfo> _textures = {};

  static String assetsRoot = "assets/";

  gpu.Texture? _dummyTexture;
  gpu.Texture? get dummyTexture => _dummyTexture;

  FskTextureManager() {
    _dummyTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      1,
      1,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
    );
    // Fill dummy with neutral PBR color (White albedo, neutral normal)
    final data = Uint8List.fromList([255, 255, 255, 255]);
    _dummyTexture!.overwrite(data.buffer.asByteData());
  }

  void dump() {
    _textures.forEach((id, textureInfo) {
      debugPrint("Texture: ID=$id, path=${textureInfo.url}");
    });
  }

  /// Clears all loaded textures from the manager.
  void clear() {
    _textures.clear();
    logInfo("TextureManager cleared.");
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
      logVerbose("Skip Loading Texture ID $id (already exists)");
      return _textures[id]!;
    }

    //  Bundle sampling parameters directly inside a unified SamplerOptions object
    final gpu.SamplerOptions samplerOptions = gpu.SamplerOptions(
      minFilter: minFilter,
      magFilter: magFilter,
      widthAddressMode: wrapS,
      heightAddressMode: wrapT,
    );

    var textureInfo = FskTextureInfo(id, url, samplerOptions);
    _textures[id] = textureInfo;

    String fullPath = '$assetsRoot$url';
    logVerbose("createTextureFromAsset: ID=$id, path=$fullPath");

    FSK().startLoad();
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

      // Actually upload the texture to the GPU!
      allocatedTexture.overwrite(byteData);
      textureInfo.texture = allocatedTexture;

      textureInfo.isLoaded = textureInfo.texture != null;
    } catch (e) {
      logError("Error processing flutter_gpu texture allocation for $url: $e");
      textureInfo.isLoaded = false;
    } finally {
      FSK().endLoad();
    }

    return textureInfo;
  }

  FskTextureInfo? getTextureInfo(String id) {
    return _textures[id];
  }
}