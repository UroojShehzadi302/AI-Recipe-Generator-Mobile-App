// Foundation smoke tests for the design-system layer.
//
// The default Flutter counter test was removed — the app has no counter, and
// pumping the full app requires Firebase initialization which isn't available
// in a widget test. Instead we verify the reusable, token-driven widgets render
// correctly under the real AppTheme. This guards the Phase 1-3 foundation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_recipe_generator/core/theme/app_theme.dart';
import 'package:ai_recipe_generator/core/widgets/primary_button.dart';
import 'package:ai_recipe_generator/core/widgets/recipe_card.dart';
import 'package:ai_recipe_generator/core/widgets/section_title.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('PrimaryButton renders its label and fires onPressed',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(PrimaryButton(text: 'SIGN IN', onPressed: () => tapped = true)),
    );

    expect(find.text('SIGN IN'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows a spinner and is disabled while loading',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const PrimaryButton(text: 'SIGN IN', onPressed: null, isLoading: true)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
  });

  testWidgets('SectionTitle renders its title', (tester) async {
    await tester.pumpWidget(_wrap(const SectionTitle(title: 'Popular Recipes')));
    expect(find.text('Popular Recipes'), findsOneWidget);
  });

  testWidgets('RecipeCard fits a narrow grid cell without overflow',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Center(
          child: SizedBox(
            width: 120, // narrower than the 2-column favorites grid cells
            child: const RecipeCard(
              recipe: Recipe(
                title: 'A Very Long Recipe Title That Should Ellipsize',
                category: 'Breakfast',
                cookingTimeMinutes: 120,
                calories: 1200,
              ),
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // A RenderFlex overflow would surface here as a caught exception.
    expect(tester.takeException(), isNull);
  });
}
