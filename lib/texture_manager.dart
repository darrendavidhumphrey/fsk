import 'dart:typed_data';
import 'dart:ui';
import 'package:fsg/fsg.dart';
import 'package:mutex/mutex.dart';
import 'package:flutter_angle/flutter_angle.dart';

class TextureInfo {
  String url;
  WebGLTexture? texture;
  Image? image;
  int magFilter;
  int minFilter;
  int wrapS;
  int wrapT;
  bool isLoaded = false;
  bool isBound = false;

  TextureInfo(this.url,this.magFilter, this.minFilter, this.wrapS, this.wrapT);
}

/// A manager for loading, creating, and caching WebGL textures for a given GL context.
class TextureManager with GlContextManager, LoggableClass {
  final Map<String, TextureInfo> _textures = {};

  // List of textures that are loaded but unbound
  final List<TextureInfo> _unBoundTextures = [];
  final Mutex _unBoundTexturesLock = Mutex();

  /// Creates a new TextureManager.
  /// This class is intended to be held by a central singleton (e.g., FSG)
  /// rather than being a singleton itself.
  TextureManager();

  /// Loads an image from assets and creates a WebGL texture from it.
  ///
  /// Textures are cached based on their asset [url]. If a texture is already
  /// in the cache, the existing instance is returned. Otherwise, a new texture
  /// is created with the specified filtering and wrapping parameters.
  Future<TextureInfo> createTextureFromAsset(
    String url, {
    int magFilter = WebGL.LINEAR,
    int minFilter = WebGL.LINEAR_MIPMAP_LINEAR,
    int wrapS = WebGL.REPEAT,
    int wrapT = WebGL.REPEAT,
  }) async {
    if (!_textures.containsKey(url)) {
      var textureInfo = TextureInfo(url,magFilter, minFilter, wrapS, wrapT);
      _textures[url] = textureInfo;

      textureInfo.image = await gl.loadImageFromAsset('assets/$url');
      textureInfo.isLoaded = true;

      await _unBoundTexturesLock.protect(() async {
        _unBoundTextures.add(textureInfo);
      });
      return textureInfo;
    }

    return _textures[url]!;
  }

  TextureInfo? getTextureInfo(String url) {
    return _textures[url];
  }

  Future<void> bindUnboundTextures() async {
    List<TextureInfo> texturesToBind = [];
    List<TextureInfo> incompleteTextures = [];

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
        final ByteData? byteData = await uiImage.toByteData(format: ImageByteFormat.rawRgba);
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
        gl.bindTexture(WebGL.TEXTURE_2D, textureInfo.texture);
        gl.pixelStorei(WebGL.UNPACK_ALIGNMENT, 1);

        logVerbose("Uploading WebGL texture for: ${textureInfo.url}");

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
        gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_S, textureInfo.wrapS);
        gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_T, textureInfo.wrapT);
        gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, textureInfo.magFilter);
        gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, minFilter);

        if (minFilter == WebGL.NEAREST_MIPMAP_NEAREST ||
            minFilter == WebGL.LINEAR_MIPMAP_NEAREST ||
            minFilter == WebGL.NEAREST_MIPMAP_LINEAR ||
            minFilter == WebGL.LINEAR_MIPMAP_LINEAR) {
          gl.generateMipmap(WebGL.TEXTURE_2D);
        }

        // 4. Unbind the texture immediately to clean up the state context
        gl.bindTexture(WebGL.TEXTURE_2D, null);

        textureInfo.isBound = true;
        _textures[textureInfo.url] = textureInfo;

      } catch (e) {
        logError("Error processing WebGL texture allocation for ${textureInfo.url}: $e");
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
