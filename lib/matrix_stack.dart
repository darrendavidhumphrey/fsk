import 'package:vector_math/vector_math.dart';

/// A class to manage a stack of matrices, useful for hierarchical scene graphs.
class MatrixStack {
  /// The current matrix at the top of the stack.
  final List<Matrix4> _stack = [];
  Matrix4 current = Matrix4.identity();

  /// Saves the current matrix copy to the stack
  void push() {
    // CRITICAL: You must call .clone() so mutations don't alter the history
    _stack.add(current.clone());
  }

  /// Restores the previous matrix context
  void pop() {
    if (_stack.isEmpty) {
      throw StateError('MatrixStack underflow: Cannot pop an empty stack.');
    }
    current = _stack.removeLast();
  }

  /// Executes the provided [commands] within a new matrix state.
  ///
  /// This is the safest way to use the stack, as it guarantees that the
  /// matrix state is restored even if an error occurs.
  void withPushed(void Function() commands) {
    push();
    try {
      commands();
    } finally {
      pop();
    }
  }
}
