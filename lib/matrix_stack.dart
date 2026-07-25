import 'package:vector_math/vector_math.dart';

/// A class to manage a stack of matrices, useful for hierarchical scene graphs.
class MatrixStack {
  /// The current matrix at the top of the stack.
  Matrix4 current = Matrix4.identity();

  final List<Matrix4> _stack = <Matrix4>[];

  /// Pushes a copy of the current matrix onto the stack.
  void push() {
    _stack.add(Matrix4.copy(current));
  }

  /// Pops the last matrix off the stack, restoring the previous state.
  /// If the stack is empty, this operation does nothing.
  void pop() {
    if (_stack.isNotEmpty) {
      current = _stack.removeLast();
    }
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
