import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fsk_widget_object.dart';
import 'fsk_text_alignment.dart';
import 'fsk_scene_base.dart';
import '../geometry/reference_box.dart';
import '../geometry/mesh_hit_tester.dart';

/// A scene object that renders an interactive, editable text field using Flutter widgets.
///
/// Features include:
/// * In-scene editing when clicked.
/// * Live validation with error message display.
/// * Escape key to cancel editing and revert changes.
/// * High-fidelity high-DPI rendering.
class FskEditableFlutterText extends FskWidgetObject {
  Color _textColor;
  TextStyle _style;
  TextHorizontalJustification _horizontalJustification;
  TextVerticalJustification _verticalJustification;
  bool scaleToFit;

  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  final String? Function(String)? onValidate;
  final void Function(String)? onSubmitted;

  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> _rebuildNotifier = ValueNotifier<int>(0);
  String _originalText;

  FskEditableFlutterText(
    super.id,
    super.parentScene,
    super.refBox, {
    required String text,
    Color textColor = Colors.white,
    TextStyle style = const TextStyle(fontSize: 40),
    TextHorizontalJustification horizontalJustification = TextHorizontalJustification.center,
    TextVerticalJustification verticalJustification = TextVerticalJustification.center,
    this.scaleToFit = false,
    this.onValidate,
    this.onSubmitted,
    Size? widgetSize,
  }) : _originalText = text,
       _textColor = textColor,
       _style = style,
       _horizontalJustification = horizontalJustification,
       _verticalJustification = verticalJustification,
       controller = TextEditingController(text: text),
       super(
         widget: const SizedBox.shrink(),
         // 4x supersampling for high fidelity.
         widgetSize: widgetSize ?? Size(refBox.xVector.length * 4, refBox.yVector.length * 4),
       ) {
    premultiplyAlpha = false;
    controller.addListener(_handleTextChanged);
    focusNode.addListener(_handleFocusChanged);
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

  void _handleTextChanged() {
    if (onValidate != null) {
      _errorNotifier.value = onValidate!(controller.text);
    }
    _rebuildNotifier.value++;
  }

  void _handleFocusChanged() {
    if (focusNode.hasFocus) {
      _originalText = controller.text;
    }
    _rebuildNotifier.value++;
  }

  @override
  void updateRefBox(ReferenceBox newBox) {
    super.updateRefBox(newBox);
    _rebuildNotifier.value++;
  }

  @override
  bool onPointerDown(PointerDownEvent event, FskHitDetails hit) {
    focusNode.requestFocus();
    return super.onPointerDown(event, hit);
  }

  @override
  Widget buildPortalWidget() {
    return _FskEditableFlutterTextWidget(
      controller: controller,
      focusNode: focusNode,
      style: _style,
      textColor: _textColor,
      horizontalJustification: _horizontalJustification,
      verticalJustification: _verticalJustification,
      scaleToFit: scaleToFit,
      widgetSize: widgetSize,
      refBox: refBox,
      errorNotifier: _errorNotifier,
      rebuildNotifier: _rebuildNotifier,
      onSubmitted: (val) {
        if (_errorNotifier.value == null) {
          onSubmitted?.call(val);
          focusNode.unfocus();
        }
      },
      onCancel: () {
        controller.text = _originalText;
        focusNode.unfocus();
      },
    );
  }

  @override
  void dispose() {
    controller.removeListener(_handleTextChanged);
    focusNode.removeListener(_handleFocusChanged);
    controller.dispose();
    focusNode.dispose();
    _errorNotifier.dispose();
    _rebuildNotifier.dispose();
    super.dispose();
  }
}

class _FskEditableFlutterTextWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color textColor;
  final TextHorizontalJustification horizontalJustification;
  final TextVerticalJustification verticalJustification;
  final bool scaleToFit;
  final Size widgetSize;
  final ReferenceBox refBox;
  final ValueNotifier<String?> errorNotifier;
  final ValueNotifier<int> rebuildNotifier;
  final void Function(String) onSubmitted;
  final VoidCallback onCancel;

  const _FskEditableFlutterTextWidget({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.textColor,
    required this.horizontalJustification,
    required this.verticalJustification,
    required this.scaleToFit,
    required this.widgetSize,
    required this.refBox,
    required this.errorNotifier,
    required this.rebuildNotifier,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([rebuildNotifier, errorNotifier, focusNode]),
      builder: (context, _) {
        final double quadHeight = refBox.yVector.length;
        final double fontSize = style.fontSize ?? 72.0;
        final double heightFactor = fontSize / quadHeight;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): onCancel,
              },
              child: Container(
                width: widgetSize.width,
                height: widgetSize.height,
                alignment: _getAlignment(),
                child: FittedBox(
                  fit: scaleToFit ? BoxFit.contain : BoxFit.scaleDown,
                  alignment: _getAlignment(),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: _getCrossAxisAlignment(),
                      children: [
                        if (errorNotifier.value != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              errorNotifier.value!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: widgetSize.height * heightFactor * 0.3,
                                fontWeight: FontWeight.bold,
                                fontFamily: style.fontFamily,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: widgetSize.height * heightFactor,
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: false,
                            cursorColor: textColor,
                            style: style.copyWith(
                              color: textColor,
                              fontSize: widgetSize.height * heightFactor * 0.8,
                            ),
                            textAlign: _getHorizontalTextAlign(),
                            onSubmitted: onSubmitted,
                            decoration: InputDecoration(
                              border: focusNode.hasFocus ? const UnderlineInputBorder() : InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
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
    switch (horizontalJustification) {
      case TextHorizontalJustification.left: return TextAlign.left;
      case TextHorizontalJustification.center: return TextAlign.center;
      case TextHorizontalJustification.right: return TextAlign.right;
    }
  }

  CrossAxisAlignment _getCrossAxisAlignment() {
    switch (horizontalJustification) {
      case TextHorizontalJustification.left: return CrossAxisAlignment.start;
      case TextHorizontalJustification.center: return CrossAxisAlignment.center;
      case TextHorizontalJustification.right: return CrossAxisAlignment.end;
    }
  }

  Alignment _getAlignment() {
    switch (verticalJustification) {
      case TextVerticalJustification.top:
        switch (horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.topLeft;
          case TextHorizontalJustification.center: return Alignment.topCenter;
          case TextHorizontalJustification.right: return Alignment.topRight;
        }
      case TextVerticalJustification.center:
        switch (horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.centerLeft;
          case TextHorizontalJustification.center: return Alignment.center;
          case TextHorizontalJustification.right: return Alignment.centerRight;
        }
      case TextVerticalJustification.bottom:
        switch (horizontalJustification) {
          case TextHorizontalJustification.left: return Alignment.bottomLeft;
          case TextHorizontalJustification.center: return Alignment.bottomCenter;
          case TextHorizontalJustification.right: return Alignment.bottomRight;
        }
    }
    return Alignment.center;
  }
}
