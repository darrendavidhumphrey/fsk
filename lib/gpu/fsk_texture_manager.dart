import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
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
  bool isLoading = false;
  Future<void>? loadFuture;

  FskTextureInfo(this.id, this.url, this.samplerOptions,{this.texture});
}

/// A manager for loading, creating, and caching flutter_gpu textures.
class FskTextureManager with LoggableClass {
  final Map<String, FskTextureInfo> _textures = {};

  static String assetsRoot = "assets/";

  gpu.Texture? _transparentTexture;
  gpu.Texture? get transparentTexture => _transparentTexture;
  final String transparentTextureId = 'transparent';
  FskTextureInfo get transparentTextureInfo => _textures[transparentTextureId]!;

  gpu.Texture? _solidTexture;
  gpu.Texture? get solidTexture => _solidTexture;
  final String solidTextureId = 'solid';
  FskTextureInfo get solidTextureInfo => _textures[solidTextureId]!;

  // Make a 1 pixel transparent texture
  void _makeTransparentTexture() {
    _transparentTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      1,
      1,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
    );
    // Fill transparent with clear black [0, 0, 0, 0].
    // This ensures that MTSDF text falling back to this texture during loading
    // results in a sigDist of 0.0, making the quad invisible instead of black.
    final data = Uint8List.fromList([0, 0, 0, 0]);
    _transparentTexture!.overwrite(data.buffer.asByteData());

    FskTextureInfo textureInfo = FskTextureInfo(
      transparentTextureId,
      '',
      gpu.SamplerOptions(
        minFilter: gpu.MinMagFilter.nearest,
        magFilter: gpu.MinMagFilter.nearest,
        mipFilter: gpu.MipFilter.nearest,
      ),
      texture: _transparentTexture,
    );
    textureInfo.isLoaded = true;
    _addTextureInfo(textureInfo);
  }

  // Make a 1 pixel solid white texture
  void _makeSolidTexture() {
    _solidTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      1,
      1,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
    );
    // Fill solid with solid white
    final data = Uint8List.fromList([255, 255, 255, 255]);
    _solidTexture!.overwrite(data.buffer.asByteData());

    FskTextureInfo textureInfo = FskTextureInfo(
      solidTextureId,
      '',
      gpu.SamplerOptions(
        minFilter: gpu.MinMagFilter.nearest,
        magFilter: gpu.MinMagFilter.nearest,
        mipFilter: gpu.MipFilter.nearest,
      ),
      texture: _solidTexture,
    );
    textureInfo.isLoaded = true;
    _addTextureInfo(textureInfo);
  }

  FskTextureManager();

  Future<void> init() async {
    if (_transparentTexture == null) {
      _makeTransparentTexture();
    }

    if(_solidTexture == null) {
      _makeSolidTexture();
    }
  }

  void dump() {
    _textures.forEach((id, textureInfo) {
      debugPrint("Texture: ID=$id, path=${textureInfo.url}");
    });
  }

  /// Clears all loaded textures from the manager.
  void clear() {
    if (_textures.isNotEmpty) {
      _textures.clear();
      _transparentTexture = null;
      _solidTexture = null;
      logInfo(
          "=========================TextureManager cleared============================");
    }
  }

  void registerTexture(FskTextureInfo textureInfo) {
    _textures[textureInfo.id] = textureInfo;
  }

  void removeTexture(String id) {
    _textures.remove(id);
  }

  void _addTextureInfo(FskTextureInfo textureInfo) {
    _textures[textureInfo.id] = textureInfo;
  }

  /// Loads an image from assets and creates a modern flutter_gpu texture directly.
  Future<FskTextureInfo> createTextureFromAsset(
      String id,
      String url, {
        gpu.MinMagFilter magFilter = gpu.MinMagFilter.linear,
        gpu.MinMagFilter minFilter = gpu.MinMagFilter.linear,
        gpu.MipFilter mipFilter = gpu.MipFilter.linear,
        gpu.SamplerAddressMode wrapS = gpu.SamplerAddressMode.repeat,
        gpu.SamplerAddressMode wrapT = gpu.SamplerAddressMode.repeat,
        bool generateMipmaps = false,
        int maxAnisotropy = 1,
      }) async {

    // Ensure engine is ready before any GPU resource allocation starts.
    if (FSK().state != FskState.initialized) {
      logInfo("Waiting for FSK initialization before loading texture: $id");
      await FSK().init();
    }

    if (_textures.containsKey(id)) {
      final info = _textures[id]!;
      // If it is already loaded or is currently in the process of loading, return the existing info.
      if (info.isLoaded || info.isLoading) {
        if (info.loadFuture != null) {
          await info.loadFuture;
        }
        
        // Final sanity check: if loading finished but handle is still null, we must retry.
        if (info.texture != null) {
          logVerbose("Skip Loading Texture ID $id (already exists and valid)");
          return info;
        }
        
        logInfo("Texture ID $id was marked loaded/loading but handle is NULL. Retrying...");
      }
      // If it exists but is not loaded and not loading, we fall through and retry.
      logInfo("Retrying failed texture load for ID $id");
    }

    // Avoid using a mip filter if we are not generating mipmaps, as some GPUs will return black.
    final gpu.MipFilter effectiveMipFilter =
        generateMipmaps ? mipFilter : gpu.MipFilter.nearest;

    // Bundle sampling parameters directly inside a unified SamplerOptions object
    final gpu.SamplerOptions samplerOptions = gpu.SamplerOptions(
      minFilter: minFilter,
      magFilter: magFilter,
      mipFilter: effectiveMipFilter,
      widthAddressMode: wrapS,
      heightAddressMode: wrapT,
      maxAnisotropy: maxAnisotropy,
    );

    final completer = Completer<void>();
    var textureInfo = FskTextureInfo(id, url, samplerOptions);
    textureInfo.isLoading = true;
    textureInfo.loadFuture = completer.future;
    
    _addTextureInfo(textureInfo);

    String fullPath = '$assetsRoot$url';
    logVerbose("createTextureFromAsset: ID=$id, path=$fullPath");

    FSK().startLoad();
    
    try {
      final ByteData data = await rootBundle.load(fullPath);

      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image uiImage = frameInfo.image;

      // Calculate mip level count if requested
      int mipLevelCount = 1;
      if (generateMipmaps) {
        // Use fullMipCount static from Texture
        mipLevelCount = gpu.Texture.fullMipCount(uiImage.width, uiImage.height);
      }

      // Allocate the physical hardware texture allocation
      final gpu.Texture allocatedTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate,
        uiImage.width,
        uiImage.height,
        format: gpu.PixelFormat.r8g8b8a8UNormInt,
        mipLevelCount: mipLevelCount,
      );

      // Immediately clear ALL mip levels to transparent black to avoid random GPU garbage.
      // This is critical for small objects (like the View Cube) that might sample higher 
      // mip levels before the font data is fully uploaded.
      final Uint8List clearBuffer = Uint8List(uiImage.width * uiImage.height * 4);
      final ByteData clearData = ByteData.sublistView(clearBuffer);
      for (int i = 0; i < mipLevelCount; i++) {
        final int mipWidth = max(1, uiImage.width >> i);
        final int mipHeight = max(1, uiImage.height >> i);
        final int levelSize = mipWidth * mipHeight * 4;
        allocatedTexture.overwrite(clearData.buffer.asByteData(0, levelSize), mipLevel: i);
      }
      logVerbose("Texture ID $id physically cleared to transparent black across $mipLevelCount levels.");

      // Populate each mip level via CPU-side downscaling
      for (int i = 0; i < mipLevelCount; i++) {
        final int mipWidth = max(1, uiImage.width >> i);
        final int mipHeight = max(1, uiImage.height >> i);

        ui.Image currentMipImage;
        if (i == 0) {
          currentMipImage = uiImage;
        } else {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawImageRect(
            uiImage,
            ui.Rect.fromLTWH(0, 0, uiImage.width.toDouble(), uiImage.height.toDouble()),
            ui.Rect.fromLTWH(0, 0, mipWidth.toDouble(), mipHeight.toDouble()),
            ui.Paint()..filterQuality = ui.FilterQuality.medium,
          );
          final picture = recorder.endRecording();
          currentMipImage = await picture.toImage(mipWidth, mipHeight);
          picture.dispose();
        }

        final ByteData? byteData = await currentMipImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData == null) {
          throw Exception("Could not convert mip $i image to raw RGBA bytes.");
        }

        // Upload level to the GPU
        allocatedTexture.overwrite(byteData, mipLevel: i);

        if (i > 0) {
          currentMipImage.dispose();
        }
      }

      uiImage.dispose(); // Dispose original after loop
      textureInfo.texture = allocatedTexture;
      textureInfo.isLoaded = textureInfo.texture != null;
    } catch (e) {
      logError("Error processing flutter_gpu texture allocation for $url: $e");
      textureInfo.isLoaded = false;
    } finally {
      textureInfo.isLoading = false;
      completer.complete();
      FSK().endLoad();
    }

    return textureInfo;
  }

  FskTextureInfo? getTextureInfo(String id) {
    return _textures[id];
  }
}
