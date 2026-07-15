// Tests for the responsive helper (grid columns per size class) and the
// shimmer skeleton widgets (render without overflow/exception on one frame —
// NOT pumpAndSettle, since the shimmer animation repeats forever).

import 'package:ai_recipe_generator/core/utils/responsive.dart';
import 'package:ai_recipe_generator/core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] at a fixed logical screen [size] so `context.*` responsive
/// getters resolve against a known width.
Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('ResponsiveContext.recipeGridColumns', () {
    testWidgets('2 columns on a phone width', (tester) async {
      int? cols;
      await _pumpAt(
        tester,
        const Size(400, 800),
        Builder(builder: (context) {
          cols = context.recipeGridColumns;
          return const SizedBox();
        }),
      );
      expect(cols, 2);
    });

    testWidgets('3 columns at tablet width', (tester) async {
      int? cols;
      await _pumpAt(
        tester,
        const Size(700, 1000),
        Builder(builder: (context) {
          cols = context.recipeGridColumns;
          return const SizedBox();
        }),
      );
      expect(cols, 3);
    });

    testWidgets('4 columns at desktop width', (tester) async {
      int? cols;
      await _pumpAt(
        tester,
        const Size(1200, 900),
        Builder(builder: (context) {
          cols = context.recipeGridColumns;
          return const SizedBox();
        }),
      );
      expect(cols, 4);
    });
  });

  group('Shimmer skeletons', () {
    testWidgets('RecipeGridSkeleton renders card skeletons without error',
        (tester) async {
      await _pumpAt(
        tester,
        const Size(400, 800),
        const RecipeGridSkeleton(columns: 2, count: 6),
      );
      // One frame is enough — the animation runs forever, so no pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(RecipeCardSkeleton), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecipeRailSkeleton renders without error', (tester) async {
      await _pumpAt(
        tester,
        const Size(400, 800),
        const RecipeRailSkeleton(height: 212, cardWidth: 172, count: 4),
      );
      await tester.pump(const Duration(milliseconds: 200));
      // The horizontal ListView builds lazily, so only the visible cards exist.
      expect(find.byType(RecipeCardSkeleton), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
