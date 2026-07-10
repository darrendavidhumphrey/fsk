import 'package:flutter_test/flutter_test.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Edge', () {
    test('Edge constructor', () {
      final start = Vector3(1, 2, 3);
      final end = Vector3(4, 5, 6);
      final edge = Edge(start, end);
      expect(edge.start, start);
      expect(edge.end, end);
    });

    test('Edge.zero constructor', () {
      final edge = Edge.zero();
      expect(edge.start, Vector3.zero());
      expect(edge.end, Vector3.zero());
    });

    test('transform method', () {
      final start = Vector3(1, 0, 0);
      final end = Vector3(0, 1, 0);
      final edge = Edge(start, end);
      final origin = Vector3(1, 1, 1);
      final xAxis = Vector3(1, 0, 0);
      final yAxis = Vector3(0, 1, 0);
      final transformedEdge = edge.transform(origin, xAxis, yAxis);
      expect(transformedEdge.start, Vector3(2, 1, 1));
      expect(transformedEdge.end, Vector3(1, 2, 1));
    });

    test('transformEdges method', () {
      final edges = [
        Edge(Vector3(1, 0, 0), Vector3(0, 1, 0)),
        Edge(Vector3(2, 0, 0), Vector3(0, 2, 0)),
      ];
      final origin = Vector3(1, 1, 1);
      final xAxis = Vector3(1, 0, 0);
      final yAxis = Vector3(0, 1, 0);
      final transformedEdges = Edge.transformEdges(edges, origin, xAxis, yAxis);
      expect(transformedEdges.length, 2);
      expect(transformedEdges[0].start, Vector3(2, 1, 1));
      expect(transformedEdges[0].end, Vector3(1, 2, 1));
      expect(transformedEdges[1].start, Vector3(3, 1, 1));
      expect(transformedEdges[1].end, Vector3(1, 3, 1));
    });

    test('edgeListsAreStrictlyEqual', () {
      final e1 = Edge(Vector3(1, 0, 0), Vector3(0, 1, 0));
      final e2 = Edge(Vector3(2, 0, 0), Vector3(0, 2, 0));

      // Test case 1: Two identical lists of edges
      final list1 = [e1, e2];
      final list2 = [e1, e2];
      expect(Edge.edgeListsAreStrictlyEqual(list1, list2), isTrue);

      // Test case 2: Two lists with the same edges but in a different order
      final list3 = [e2, e1];
      expect(Edge.edgeListsAreStrictlyEqual(list1, list3), isFalse);

      // Test case 3: Two lists with the same edges, but one edge has its start and end points swapped
      final e1Swapped = Edge(e1.end, e1.start);
      final list4 = [e1Swapped, e2];
      expect(Edge.edgeListsAreStrictlyEqual(list1, list4), isFalse);

      // Test case 4: Two lists of different lengths
      final list5 = [e1];
      expect(Edge.edgeListsAreStrictlyEqual(list1, list5), isFalse);

      // Test case 5: Two empty lists
      final emptyList1 = <Edge>[];
      final emptyList2 = <Edge>[];
      expect(Edge.edgeListsAreStrictlyEqual(emptyList1, emptyList2), isTrue);

      // Test case 6: One empty list and one non-empty list
      expect(Edge.edgeListsAreStrictlyEqual(emptyList1, list1), isFalse);
    });

    group('copyWith', () {
      final original = Edge(Vector3(1, 2, 3), Vector3(4, 5, 6));

      test('copies with no changes', () {
        final copy = original.copyWith();
        expect(copy, original);
        expect(identical(copy, original), isFalse);
      });

      test('copies with a new start point', () {
        final newStart = Vector3(7, 8, 9);
        final copy = original.copyWith(start: newStart);
        expect(copy.start, newStart);
        expect(copy.end, original.end);
      });

      test('copies with a new end point', () {
        final newEnd = Vector3(10, 11, 12);
        final copy = original.copyWith(end: newEnd);
        expect(copy.start, original.start);
        expect(copy.end, newEnd);
      });

      test('copies with both new start and end points', () {
        final newStart = Vector3(7, 8, 9);
        final newEnd = Vector3(10, 11, 12);
        final copy = original.copyWith(start: newStart, end: newEnd);
        expect(copy.start, newStart);
        expect(copy.end, newEnd);
      });
    });

    group('Equality and hashCode', () {
      final edge1 = Edge(Vector3(1, 2, 3), Vector3(4, 5, 6));
      final edge2 = Edge(Vector3(1, 2, 3), Vector3(4, 5, 6));
      final edge3 = Edge(Vector3(7, 8, 9), Vector3(10, 11, 12));
      final edge4 = Edge(Vector3(4, 5, 6), Vector3(1, 2, 3)); // Swapped points

      test('== operator returns true for equal objects', () {
        expect(edge1 == edge2, isTrue);
      });

      test('== operator returns false for unequal objects', () {
        expect(edge1 == edge3, isFalse);
        expect(edge1 == edge4, isFalse);
      });

      test('== operator returns false for different types', () {
        expect(edge1 == 'not an edge', isFalse);
      });

      test('hashCode is the same for equal objects', () {
        expect(edge1.hashCode, edge2.hashCode);
      });

      test('hashCode is different for unequal objects', () {
        expect(edge1.hashCode, isNot(edge3.hashCode));
        expect(edge1.hashCode, isNot(edge4.hashCode));
      });
    });
  });
}
