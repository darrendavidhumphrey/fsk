import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

class WidgetNestingScene extends FskScene {
  WidgetNestingScene({super.navigationDelegate})
    : super(clearColor: const Color(0xFF1A1A2A));

  final TextEditingController _textController = TextEditingController(
    text: "100.0",
  );
  final FocusNode _focusNode = FocusNode();

  final ValueNotifier<bool> _validationEnabled = ValueNotifier<bool>(true);

  @override
  Future<void> onInit() async {
    await super.onInit();
    skinSize = const Size(1920, 1080);
    useBoxFitLayout = false; // Use pure world coordinates for OrbitView

    if (navigationDelegate is OrbitViewDelegate) {
      (navigationDelegate as OrbitViewDelegate).setViewDistance(800);
    }

    // 1. Create the main scene group
    final mainGroup = FskGroup("main_group", this);
    mainGroup.position = vm.Vector3.zero();
    addNode(mainGroup);

    final rotatingGroup = FskGroup("rotating_group", this);
    mainGroup.addNode(rotatingGroup);

    // Background
    final bgQuad = FskQuad(
      "bg",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3.zero(), const Size(800, 400)),
      const Rect.fromLTWH(0, 0, 1, 1),
      modulateColor: Colors.blueGrey.withValues(alpha: 0.3),
    );
    bgQuad.isPickable = false;
    rotatingGroup.addNode(bgQuad);

    // 2. Status/Display Texts (Flutter Text)
    final liveDisplay = FskFlutterText(
      "live_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 200, 0), const Size(800, 60)),
      text: "Live: 100.0",
      textColor: Colors.white,
      style: const TextStyle(fontFamily: 'isocpeur', fontSize: 60),
    );
    mainGroup.addNode(liveDisplay);

    final submittedDisplay = FskFlutterText(
      "submitted_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 280, 0), const Size(800, 60)),
      text: "Submitted: 100.0",
      textColor: Colors.greenAccent,
      style: const TextStyle(fontFamily: 'isocpeur', fontSize: 60),
    );
    mainGroup.addNode(submittedDisplay);

    final errorDisplay = FskFlutterText(
      "error_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 100, 20), const Size(800, 40)),
      text: "",
      textColor: Colors.redAccent,
      style: const TextStyle(fontFamily: 'isocpeur', fontSize: 40),
    );
    rotatingGroup.addNode(errorDisplay);

    _initInputWidget(
      rotatingGroup,
      liveDisplay: liveDisplay,
      submittedDisplay: submittedDisplay,
      errorDisplay: errorDisplay,
    );
  }

  void _initInputWidget(
    FskGroup rotatingGroup, {
    FskFlutterText? liveDisplay,
    FskFlutterText? submittedDisplay,
    FskFlutterText? errorDisplay,
  }) {
    // 3. The Interactive Input Widget
    final editableText = FskEditableTextObject(
      "editable_text",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 0, 20), const Size(600, 150)),
      controller: _textController,
      focusNode: _focusNode,
      style: const TextStyle(
        fontSize: 40,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      widgetSize: const Size(600, 150),
    );
    // Inject the complex widget with checkbox and validation awareness
    editableText.buildPortalWidgetOverride = () => _ComplexInputWidget(
      controller: _textController,
      focusNode: _focusNode,
      isHoveredNotifier: editableText.isHovered,
      validationEnabled: _validationEnabled,
      onSubmitted: (val) {
        Logging.logInfo(
          "WidgetNestingScene: onSubmitted received '$val'",
          source: "WidgetNestingScene",
        );
        submittedDisplay?.text = "Submitted: $val";
      },
    );

    rotatingGroup.addNode(editableText);

    // Wire up the live listener
    _textController.addListener(() {
      final text = _textController.text;
      if (liveDisplay != null) liveDisplay.text = "Live: $text";

      if (_validationEnabled.value) {
        final val = double.tryParse(text);
        if (val == null && text.isNotEmpty) {
          if (errorDisplay != null) {
            errorDisplay.text = "Invalid Double Number!";
          }
        } else {
          if (errorDisplay != null) errorDisplay.text = "";
        }
      } else {
        if (errorDisplay != null) errorDisplay.text = "";
      }
    });

    _validationEnabled.addListener(() {
      if (!_validationEnabled.value) {
        if (errorDisplay != null) errorDisplay.text = "";
      } else {
        _textController.notifyListeners();
      }
    });
  }

  @override
  void updateAnimations(DateTime now) {
    super.updateAnimations(now);
    final rotatingGroup = findNode<FskGroup>("rotating_group");
    if (rotatingGroup != null) {
      final t = currentTime;
      rotatingGroup.rotation = vm.Vector3(0.3 * math.sin(t * 0.5), t * 0.2, 0);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _validationEnabled.dispose();
    super.dispose();
  }
}

class _ComplexInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<bool> isHoveredNotifier;
  final ValueNotifier<bool> validationEnabled;
  final Function(String) onSubmitted;

  const _ComplexInputWidget({
    required this.controller,
    required this.focusNode,
    required this.isHoveredNotifier,
    required this.validationEnabled,
    required this.onSubmitted,
  });

  @override
  State<_ComplexInputWidget> createState() => _ComplexInputWidgetState();
}

class _ComplexInputWidgetState extends State<_ComplexInputWidget>
    with LoggableClass {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.isHoveredNotifier.addListener(_onHoverChanged);
    widget.validationEnabled.addListener(_rebuild);
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.isHoveredNotifier.removeListener(_onHoverChanged);
    widget.validationEnabled.removeListener(_rebuild);
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _onHoverChanged() {
    if (mounted) setState(() => _isHovered = widget.isHoveredNotifier.value);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: widget.focusNode.hasFocus
                ? Colors.cyanAccent
                : (_isHovered ? Colors.white : Colors.white70),
            width: widget.focusNode.hasFocus ? 4 : (_isHovered ? 3 : 2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                onChanged: (val) {
                  Logging.logInfo("ComplexInputWidget: TextField onChanged: '$val'", source: "ComplexInputWidget");
                },
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                onSubmitted: widget.onSubmitted,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            const VerticalDivider(color: Colors.white24, width: 20),
            Container(
              width: 100,
              color: Colors.white.withValues(alpha: 0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "VAL",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Checkbox(
                    value: widget.validationEnabled.value,
                    onChanged: (val) {
                      widget.validationEnabled.value = val ?? false;
                    },
                    activeColor: Colors.cyanAccent,
                    checkColor: Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
