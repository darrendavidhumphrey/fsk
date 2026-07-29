import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/scene_graph/fsk_quads_renderer.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import '../fsk.dart';
import 'fsk_text_quad_builder.dart';


/// A class that manages the geometry and rendering for a single line of text
/// using a [BitmapFont].
///
/// It generates a set of quads for the text, scaled to fit within a target
/// [ReferenceBox], and renders them using a [FskQuadsRenderer].
class FskBitmapText extends FskRenderableObject {
  /// The string to render
  String _text;

  /// The [ReferenceBox] that defines the target area for the text to be rendered into.
  final ReferenceBox _screenRect;

  /// The font to render the text with
  BitmapFont _font;

  /// The [BitmapFont] to use for rendering.
  BitmapFont get font => _font;

  /// The target width of the text.
  final double _width;

  /// Text justification mode
  TextVerticalJustification _verticalJustification;
  TextHorizontalJustification _horizontalJustification;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer;

  /// Optional maxLen field can truncate the text
  int? _maxLen;

  /// The color applied to modulate the text texture quads.
  Color _textColor = const Color(0xFFFFFFFF);

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  /// Sets a new font and flags the text for a rebuild.
  void setFont(BitmapFont font) {
    if (_font != font) {
      _font = font;

      _renderer.setTexture(font.textureInfo);
      needsRebuild = true;
    }
  }

  /// The text string to be rendered.
  String get text => _text;

  /// Sets a new text string and flags the text for a rebuild.
  void setText(String newText) {
    if (_maxLen != null) {
      newText = text.substring(0, min(_maxLen!, newText.length));
    }

    if (_text != newText) {
      _text = newText;
      needsRebuild = true;
    }
  }

  // Optional max length field
  int? get maxLen => _maxLen;

  /// Sets a new max length and flags the text for a rebuild.
  set maxLen(int? value) {
    _maxLen = value;

    // Truncate the text if required
    if (_maxLen != null) {
      _text = _text.substring(0, min(_maxLen!, text.length));
    }
    needsRebuild = true;
  }

  /// Sets a new text color
  set textColor(Color value) {
    _textColor = value;
    _renderer.setModulateColor(_textColor);
  }

  TextVerticalJustification get verticalJustification => _verticalJustification;

  /// Sets a new text vertical justification and flags the text for a rebuild.
  set verticalJustification(TextVerticalJustification value) {
    _verticalJustification = value;
    needsRebuild = true;
  }

  TextHorizontalJustification get horizontalJustification =>
      _horizontalJustification;

  /// Sets a new text horizontal justification and flags the text for a rebuild.
  set horizontalJustification(TextHorizontalJustification value) {
    _horizontalJustification = value;
    needsRebuild = true;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskBitmapText(
    super.parentScene,
    this._font,
    this._text,
    this._screenRect, {
    this._textColor = const Color(0xFFFFFFFF),
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
  }): _renderer = FskQuadsRenderer(), _width = _screenRect.xVector.length
  {
    _renderer.setTexture(font.textureInfo);

    // Trigger the setter
    textColor = _textColor;
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  /// Disposes the vertex buffer associated with this text.
  void dispose() {
    _renderer.dispose();
  }

  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    // If anything is wrong, just bail out and create an empty set
    if ((!font.isInitialized) || (text.isEmpty)) {
      _renderer.setFromUnrolledQuads(0, Float32List(0));
      return;
    }

    /// Rebuilds the list of geometry and texture quads for the current text string.
    FskBitmapTextQuadBuilder quadBuilder = FskBitmapTextQuadBuilder(
      text: text,
      font: font,
      screenRect: _screenRect,
      horizontalJustification: horizontalJustification,
      verticalJustification: verticalJustification,
      width: _width);

    final result = quadBuilder.build();
    _renderer.setFromUnrolledQuads(result.numQuads, result.vertexData);
  }

  @override
  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients,Matrix4 pMatrix, Matrix4 mvMatrix) {
    _renderer.draw(renderPass, transients, pMatrix, mvMatrix);
  }
}