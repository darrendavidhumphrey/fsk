import 'package:flutter/material.dart'; // Adds the 'Colors' constant utility
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/gl_state_manager.dart';
import 'package:fsg/vbo_filler.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../fsg_singleton.dart';
import '../reference_box.dart';
import '../shaders/bitmap_text_shader.dart';
import '../shaders/shaders.dart';
import '../vertex_buffer.dart';
import 'bitmap_font.dart';

/// A class that manages the geometry and rendering for a single line of text
/// using a [BitmapFont].
///
/// It generates a set of quads for the text, scaled to fit within a target
/// [ReferenceBox], and manages the associated [VertexBuffer] for rendering.
class BitmapText {
  /// The list of 3D quads representing the geometry of each character.
  List<Quad> quads = [];

  /// The list of texture coordinate rectangles corresponding to each character quad.
  List<Rect> textureQuads = [];

  String _text;

  /// The [ReferenceBox] that defines the target area for the text to be rendered into.
  late final ReferenceBox _screenRect;

  bool _needsRebuild = true;

  /// A flag indicating if the text geometry needs to be recalculated.
  bool get needsRebuild => _needsRebuild;

  /// The text string to be rendered.
  String get text => _text;

  BitmapFont? _font;

  /// The [BitmapFont] to use for rendering.
  BitmapFont? get font => _font;

  late double _width;

  /// The color applied to modulate the text texture quads.
  Color textColor = const Color(0xFFFFFFFF);

  /// The vertex buffer object that holds the geometry for rendering.
  VertexBuffer vbo = VertexBuffer.v3t2();

  // One shader shared by all text instances
  static BitmapTextShader? shader;

  /// Creates a [BitmapText] object.
  ///
  /// - [_font]: The font to use for rendering.
  /// - [_text]: The initial text string.
  /// - [_screenRect]: The target area for the text.
  BitmapText(this._font, this._text, this._screenRect) {
    // Cache the target width from the reference box.
    _width = _screenRect.xVector.length;
  }

  BitmapText.origin({required this._text,required BitmapFont font,Vector3? origin,Color? color,double? width}) {
    origin ??= Vector3.zero();
    _font = font;


    if (width == null) {
      _width = _font!.widthOfString(_text);
    } else {
      _width = width;
    }
    _screenRect = ReferenceBox(
      origin,
      Vector3(_width, 0, 0),
      Vector3(0, _width, 0),
      Vector3(0, 0, 1),
    );
    if (color != null) {
      textColor = color;
    }
  }

  /// Disposes the vertex buffer associated with this text.
  void dispose() {
      vbo.dispose();
  }

  /// Sets a new font and flags the text for a rebuild.
  void setFont(BitmapFont font) {
    if (_font != font) {
      _font = font;
      _needsRebuild = true;
    }
  }

  /// Sets a new text string and flags the text for a rebuild.
  void setText(String text) {
    if (_text != text) {
      _text = text;
      _needsRebuild = true;
    }
  }

  /// Rebuilds the vertex buffer object if the text or font has changed.
  void rebuild(GlStateManager gls) {
    // Guard against unnecessary, expensive rebuilds.
    if (!_needsRebuild) return;

    rebuildQuads();

    // Create the VBO if it doesn't exist.
    vbo.init(gls);

    int vertexCount = quads.length * 6; // Two triangles per character quad.

    Float32Array? vertexTexCoordArray = vbo.requestBuffer(vertexCount);

    if (vertexTexCoordArray != null) {
      // Fill the VBO with the generated quad data.
      VboFiller.addTexturedQuads(quads, textureQuads,vbo);
    }

    vbo.setActiveVertexCount(vertexCount);
    _needsRebuild = false; // Reset the flag after a successful rebuild.
  }

  /// Rebuilds the list of geometry and texture quads for the current text string.
  ///
  /// This uses a two-pass approach for efficiency:
  /// 1. First pass gathers character data and calculates the total unscaled line length.
  /// 2. Second pass pre-allocates lists and generates the final scaled and transformed quads.
  void rebuildQuads() {
    if ((text.isEmpty) || (font == null)) {
      quads = [];
      textureQuads = [];
      return;
    }

    // --- Pass 1: Gather layout information and calculate total width ---
    final layoutData = <({CharInfo char, double kerning})>[];
    double lineLength = 0;

    for (int i = 0; i < _text.length; i++) {
      final charInfo = _font!.chars[_text[i]];
      if (charInfo == null) continue;

      double kerning = 0.0;
      if ((i + 1) < _text.length) {
        kerning = _font!.kerningForPair(
          _text.codeUnitAt(i),
          _text.codeUnitAt(i + 1),
        );
      }
      layoutData.add((char: charInfo, kerning: kerning));
      lineLength += charInfo.xAdvance + kerning;
    }

    // --- Pass 2: Pre-allocate lists and generate scaled quads ---
    final characterCount = layoutData.length;
    quads = List<Quad>.filled(characterCount, Quad());
    textureQuads = List<Rect>.filled(characterCount, Rect.zero);

    double currentX = 0;
    final double ratio = (lineLength > 0) ? _width / lineLength : 1.0;
    final double lineHeight = _font!.lineHeight * ratio;
    final double vCenter = -lineHeight / 2.0;

    for (int i = 0; i < characterCount; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      // Calculate unscaled vertex positions relative to the baseline
      final top = _font!.baseline - charInfo.yOffset;
      final bottom = top - charInfo.region.height;
      final left = currentX + charInfo.xOffset;
      final right = left + charInfo.region.width;

      final unscaledQuad = Quad.points(
        Vector3(left, bottom, 0), // Bottom-left
        Vector3(right, bottom, 0), // Bottom-right
        Vector3(right, top, 0), // Top-right
        Vector3(left, top, 0), // Top-left
      );

      // Scale the quad to fit the target width and vertically center it.
      final blc = Vector2(unscaledQuad.point0.x * ratio, unscaledQuad.point0.y * ratio + vCenter);
      final trc = Vector2(unscaledQuad.point2.x * ratio, unscaledQuad.point2.y * ratio + vCenter);
      // Transform the 2D scaled quad into the 3D space of the reference box.
      quads[i] = _screenRect.calcQuadFrom2DVectors(blc, trc);

      // Calculate normalized texture coordinates from the font atlas region.
      final tLeft = charInfo.region.left / _font!.scaleW;
      final tTop = charInfo.region.top / _font!.scaleH;
      final tRight = (charInfo.region.left + charInfo.region.width) / _font!.scaleW;
      final tBottom = (charInfo.region.top + charInfo.region.height) / _font!.scaleH;
      textureQuads[i] = Rect.fromLTRB(tLeft, tTop, tRight, tBottom);

      currentX += charInfo.xAdvance + kerning;
    }
  }

  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader ??= FSG().shaders.getShader<BitmapTextShader>();
    if ((font == null) || (shader==null)) return;

    gls.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);


    gls.setBlend(true);
    gls.setTexturingEnabled(true);
    gls.activeTexture(WebGL.TEXTURE0);

    gls.blendFuncSeparate(
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    shader!.setTextureSampler(0);
  }

  void draw(GlStateManager gls) {
    if ((font == null) || (!font!.isInitialized) || (shader==null)) return;

    shader!.setTextColor(textColor);

    gls.bindTexture(WebGL.TEXTURE_2D, font!.textureInfo!.texture);

    vbo.bind();
    vbo.drawTriangles();

  }
}
