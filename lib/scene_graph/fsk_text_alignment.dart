// Enums for text justification

enum TextVerticalJustification {
  top('top'),
  center('center'),
  bottom('bottom');

  // The underlying string value associated with each enum value
  final String value;

  // Enhanced enum constructor
  const TextVerticalJustification(this.value);

  /// Parses a string into a [TextVerticalJustification].
  /// Returns the matching enum, or [defaultValue] if no match is found.
  static TextVerticalJustification fromString(
      String input, {
        TextVerticalJustification defaultValue = TextVerticalJustification.top,
      }) {
    final cleanInput = input.trim().toLowerCase();

    return TextVerticalJustification.values.firstWhere(
          (element) => element.value == cleanInput,
      orElse: () => defaultValue,
    );
  }
}

enum TextHorizontalJustification {
  left('left'),
  center('center'),
  right('right');

  // The underlying string value associated with each enum value
  final String value;

  // Enhanced enum constructor
  const TextHorizontalJustification(this.value);

  /// Parses a string into a [TextHorizontalJustification].
  /// Returns the matching enum, or [defaultValue] if no match is found.
  static TextHorizontalJustification fromString(
      String input, {
        TextHorizontalJustification defaultValue = TextHorizontalJustification.left,
      }) {
    final cleanInput = input.trim().toLowerCase();

    return TextHorizontalJustification.values.firstWhere(
          (element) => element.value == cleanInput,
      orElse: () => defaultValue,
    );
  }
}