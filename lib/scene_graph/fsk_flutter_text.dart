import 'package:flutter/material.dart';
import 'fsk_widget_object.dart';
import 'fsk_text_alignment.dart';
import '../geometry/reference_box.dart';

/// A scene object that renders text using standard Flutter widgets.
///
/// This provides a high-fidelity alternative to texture-based fonts,
/// allowing for the use of any Flutter font, rich text features, and
/// high-DPI rendering through the widget portal system.
class FskFlutterText extends FskWidgetObject {
  String _text;
  Color _textColor;
  TextStyle _style;
  TextHorizontalJustification _horizontalJustification;
  TextVerticalJustification _verticalJustification;
  bool scaleToFit;

  /// Internal notifier to trigger portal widget rebuilds when properties change.
  final ValueNotifier<int> _rebuildNotifier = ValueNotifier<int>(0);

  FskFlutterText(
    super.id,
    super.parentScene,
    super.refBox, {
    required this._text,
    this._textColor = Colors.white,
    this._style = const TextStyle(fontSize: 40),
    this._horizontalJustification = TextHorizontalJustification.center,
    this._verticalJustification = TextVerticalJustification.center,
    this.scaleToFit = false,
    Size? widgetSize,
  }) : super(
         widget: const SizedBox.shrink(),
         // 4x supersampling for high fidelity.
         widgetSize: widgetSize ?? Size(refBox.xVector.length * 4, refBox.yVector.length * 4),
       ) {
    premultiplyAlpha = false;
  }

  /// The text string to be rendered.
  String get text => _text;
  set text(String value) {
    if (_text != value) {
      _text = value;
      _rebuildNotifier.value++;
    }
  }

  /// The color of the text.
  Color get textColor => _textColor;
  set textColor(Color value) {
    if (_textColor != value) {
      _textColor = value;
      _rebuildNotifier.value++;
    }
  }

  /// The Flutter [TextStyle] to apply to the text.
  TextStyle get style => _style;
  set style(TextStyle value) {
    _style = value;
    _rebuildNotifier.value++;
  }

  /// How the text should be aligned horizontally within the [ReferenceBox].
  TextHorizontalJustification get horizontalJustification => _horizontalJustification;
  set horizontalJustification(TextHorizontalJustification value) {
    if (_horizontalJustification != value) {
      _horizontalJustification = value;
      _rebuildNotifier.value++;
    }
  }

  /// How the text should be aligned vertically within the [ReferenceBox].
  TextVerticalJustification get verticalJustification => _verticalJustification;
  set verticalJustification(TextVerticalJustification value) {
    if (_verticalJustification != value) {
      _verticalJustification = value;
      _rebuildNotifier.value++;
    }
  }

  @override
  Widget buildPortalWidget() {
    return ValueListenableBuilder<int>(
      valueListenable: _rebuildNotifier,
      builder: (context, _, _) {
        final double quadHeight = refBox.yVector.length;
        final double fontSize = _style.fontSize ?? 72.0;
        
        // The ratio of the requested font size to the total box height.
        final double heightFactor = fontSize / quadHeight;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widgetSize.width,
              height: widgetSize.height,
              alignment: _getAlignment(),
              child: FittedBox(
                // scaleToFit=true: fill the box (BoxFit.contain).
                // scaleToFit=false: use natural size relative to box (mimicked via FractionallySizedBox).
                fit: scaleToFit ? BoxFit.contain : BoxFit.scaleDown,
                alignment: _getAlignment(),
                child: SizedBox(
                  // We use a large fixed size for the inner text to ensure high-quality capture,
                  // then FittedBox/SizedBox handles the 3D unit mapping.
                  height: widgetSize.height * heightFactor,
                  child: Center(
                    child: Text(
                      _text,
                      style: _style.copyWith(
                        color: _textColor,
                        fontSize: widgetSize.height * heightFactor * 0.8, // Slightly smaller to account for glyph ascenders
                      ),
                      textAlign: _getHorizontalTextAlign(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextAlign _getHorizontalTextAlign() {
    switch (_horizontalJustification) {
      case TextHorizontalJustification.left:
        return TextAlign.left;
      case TextHorizontalJustification.center:
        return TextAlign.center;
      case TextHorizontalJustification.right:
        return TextAlign.right;
    }
  }

  Alignment _getAlignment() {
    switch (_verticalJustification) {
      case TextVerticalJustification.top:
        switch (_horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.topLeft;
          case TextHorizontalJustification.center: return Alignment.topCenter;
          case TextHorizontalJustification.right: return Alignment.topRight;
        }
      case TextVerticalJustification.center:
        switch (_horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.centerLeft;
          case TextHorizontalJustification.center: return Alignment.center;
          case TextHorizontalJustification.right: return Alignment.centerRight;
        }
      case TextVerticalJustification.bottom:
        switch (_horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.bottomLeft;
          case TextHorizontalJustification.center: return Alignment.bottomCenter;
          case TextHorizontalJustification.right: return Alignment.bottomRight;
        }
    }
  }
}
