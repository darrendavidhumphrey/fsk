import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:fsk/fsk.dart';
import 'package:mutex/mutex.dart';
import 'package:flutter_angle/flutter_angle.dart';

class FskTextureInfo {
  String id;
  String url;
  WebGLTexture? texture;
  Image? image;
  int magFilter;
  int minFilter;
  int wrapS;
  int wrapT;
  bool isLoaded = false;
  bool isBound = false;

  FskTextureInfo(this.id,this.url, this.magFilter, this.minFilter, this.wrapS, this.wrapT);
}

/// A manager for loading, creating, and caching WebGL textures for a given GL context.
class FskTextureManager with GlContextManager, LoggableClass {
  final Map<String, FskTextureInfo> _textures = {};

  static String assetsRoot = "assets/";
  // List of textures that are loaded but unbound
  final List<FskTextureInfo> _unBoundTextures = [];
  final Mutex _unBoundTexturesLock = Mutex();

  GlStateManager gls;

  /// Creates a new TextureManager.
  /// This class is intended to be held by a central singleton (e.g., FSK)
  /// rather than being a singleton itself.
  FskTextureManager(this.gls);

  void dump() {
    for (var textureInfo in _textures.values) {
      logInfo("Texture: ID=${textureInfo.id}, path=${textureInfo.url}");
    }
  }
  /// Loads an image from assets and creates a WebGL texture from it.
  ///
  /// Textures are cached based on their asset [url]. If a texture is already
  /// in the cache, the existing instance is returned. Otherwise, a new texture
  /// is created with the specified filtering and wrapping parameters.
  Future<FskTextureInfo> createTextureFromAsset(
      String id,
    String url, {
    int magFilter = WebGL.LINEAR,
    int minFilter = WebGL.LINEAR_MIPMAP_LINEAR,
    int wrapS = WebGL.REPEAT,
    int wrapT = WebGL.REPEAT,
  }) async {
    if (!_textures.containsKey(id)) {
      var textureInfo = FskTextureInfo(id,url, magFilter, minFilter, wrapS, wrapT);
      _textures[id] = textureInfo;

      String fullPath = '$assetsRoot$url';
      logVerbose("createTextureFromAsset: ID=$id, path=$fullPath");


      final ByteData data = await rootBundle.load(fullPath);

      final Codec codec = await instantiateImageCodec(data.buffer.asUint8List());
      final FrameInfo frameInfo = await codec.getNextFrame();

      textureInfo.image = frameInfo.image;
      textureInfo.isLoaded = true;

      await _unBoundTexturesLock.protect(() async {
        _unBoundTextures.add(textureInfo);
      });
      return textureInfo;
    }
    else {
      logInfo("Skip Loading Texture ID $id (already exists)");
    }

    return _textures[id]!;
  }

  FskTextureInfo? getTextureInfo(String id) {
    return _textures[id];
  }

  Future<void> bindUnboundTextures() async {
    List<FskTextureInfo> texturesToBind = [];
    List<FskTextureInfo> incompleteTextures = [];

    // 1. Safely copy elements out of the thread-lock
    await _unBoundTexturesLock.protect(() async {
      if (_unBoundTextures.isNotEmpty) {
        texturesToBind = List.from(_unBoundTextures);
        _unBoundTextures.clear();
      }
    });

    if (texturesToBind.isEmpty) return;

    // 2. Process textures.
    for (var textureInfo in texturesToBind) {
      if (textureInfo.image == null) {
        incompleteTextures.add(textureInfo);
        continue;
      }

      try {
        final Image uiImage = textureInfo.image as Image;

        // ====================================================================
        // STEP A: ASYNCHRONOUS WORK (DO NOT TOUCH THE WEBGL STATE MACHINE HERE)
        // We await the byte conversion FIRST. If the render loop switches bound
        // textures during this await, it won't affect our logic because we
        // haven't bound anything yet.
        // ====================================================================
        final ByteData? byteData = await uiImage.toByteData(
          format: ImageByteFormat.rawRgba,
        );
        if (byteData == null) {
          throw Exception("Could not convert image to raw RGBA bytes.");
        }

        final Uint8List pixels = byteData.buffer.asUint8List();
        final Uint8Array nativePixelArray = Uint8Array.fromList(pixels);

        // ====================================================================
        // STEP B: SYNCHRONOUS WEBGL PIPELINE (ZERO AWAITS INSIDE THIS BLOCK)
        // Now that the data is ready in local variables, we change state
        // and upload the data seamlessly in a single synchronous execution pass.
        // ====================================================================

        // 1. Instantly allocate and isolate the target texture slot
        textureInfo.texture = gl.createTexture();
        gls.bindTexture(WebGL.TEXTURE_2D, textureInfo.texture);
        gl.pixelStorei(WebGL.UNPACK_ALIGNMENT, 1);

        logVerbose("Uploading WebGL texture for:${textureInfo.id} path=${textureInfo.url}");

        // 2. Upload the data immediately without yielding the main thread
        gl.texImage2D(
          WebGL.TEXTURE_2D,
          0,
          WebGL.RGBA,
          uiImage.width,
          uiImage.height,
          0,
          WebGL.RGBA,
          WebGL.UNSIGNED_BYTE,
          nativePixelArray,
        );

        // 3. Configure sampling parameters safely while the texture remains bound
        int minFilter = textureInfo.minFilter;
        gls.setTextureParameters(
          textureInfo.texture!,
          wrapS: textureInfo.wrapS,
          wrapT: textureInfo.wrapT,
          minFilter: minFilter,
          magFilter: textureInfo.magFilter,
        );

        if (minFilter == WebGL.NEAREST_MIPMAP_NEAREST ||
            minFilter == WebGL.LINEAR_MIPMAP_NEAREST ||
            minFilter == WebGL.NEAREST_MIPMAP_LINEAR ||
            minFilter == WebGL.LINEAR_MIPMAP_LINEAR) {
          gl.generateMipmap(WebGL.TEXTURE_2D);
        }

        // 4. Unbind the texture immediately to clean up the state context
        gls.bindTexture(WebGL.TEXTURE_2D, null);

        textureInfo.isBound = true;
        _textures[textureInfo.id] = textureInfo;
      } catch (e) {
        logError(
          "Error processing WebGL texture allocation for ${textureInfo.url}: $e",
        );
        incompleteTextures.add(textureInfo);
      }
    }

    // 3. Put incomplete textures back into the main queue under lock protection
    if (incompleteTextures.isNotEmpty) {
      await _unBoundTexturesLock.protect(() async {
        _unBoundTextures.addAll(incompleteTextures);
      });
    }
  }

  /// Disposes all cached textures.
  ///
  /// This method is asynchronous to safely handle textures that may still be
  /// loading at the time of disposal.
  Future<void> dispose() async {
    _textures.clear();
  }
}
