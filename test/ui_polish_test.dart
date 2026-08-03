// Widget tests for the UI-polish layer: the floating bottom navigation, the
// button/field/empty-state primitives, and the responsiveness guarantees the
// design system is supposed to provide.
//
// These lock in behaviour that is easy to regress by eye: that the nav hides
// labels on very small screens rather than overflowing, that buttons actually
// block taps while loading, and that the redesigned cards survive a narrow
// grid cell and a landscape viewport without overflowing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_recipe_generator/core/theme/app_animations.dart';
import 'package:ai_recipe_generator/core/theme/app_colors.dart';
import 'package:ai_recipe_generator/core/theme/app_dimensions.dart';
import 'package:ai_recipe_generator/core/theme/app_scroll_behavior.dart';
import 'package:ai_recipe_generator/core/theme/app_text_styles.dart';
import 'package:ai_recipe_generator/core/theme/app_theme.dart';
import 'package:ai_recipe_generator/core/widgets/app_bottom_nav.dart';
import 'package:ai_recipe_generator/core/widgets/app_text_field.dart';
import 'package:ai_recipe_generator/core/widgets/category_chip.dart';
import 'package:ai_recipe_generator/core/widgets/empty_state.dart';
import 'package:ai_recipe_generator/core/widgets/favorite_button.dart';
import 'package:ai_recipe_generator/core/widgets/primary_button.dart';
import 'package:ai_recipe_generator/core/widgets/profile_avatar.dart';
import 'package:ai_recipe_generator/core/widgets/recipe_card.dart';
import 'package:ai_recipe_generator/core/widgets/recipe_opening_overlay.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(body: child),
    );

const List<NavDestination> _destinations = <NavDestination>[
  NavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  NavDestination(
    icon: Icons.favorite_border_rounded,
    activeIcon: Icons.favorite_rounded,
    label: 'Favorites',
  ),
  NavDestination(
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    label: 'Ask AI',
    emphasized: true,
  ),
  NavDestination(
    icon: Icons.bookmark_border_rounded,
    activeIcon: Icons.bookmark_rounded,
    label: 'Saved',
  ),
  NavDestination(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

/// Renders at a given logical screen size so responsiveness can be asserted.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(child));
  await tester.pumpAndSettle();
}

void main() {
  group('AppBottomNav', () {
    testWidgets('labels only the selected destination', (tester) async {
      await _pumpAt(
        tester,
        AppBottomNav(
          index: 0,
          onSelect: (_) {},
          destinations: _destinations,
        ),
        size: const Size(400, 800),
      );

      // Only the active tab is labelled; the rest are icon-only, which is what
      // keeps five destinations fitting on a narrow phone.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Favorites'), findsNothing);
    });

    testWidgets('reports taps for each destination', (tester) async {
      int selected = -1;
      await _pumpAt(
        tester,
        AppBottomNav(
          index: 0,
          onSelect: (i) => selected = i,
          destinations: _destinations,
        ),
        size: const Size(400, 800),
      );

      // Tapped by icon, since unselected tabs render no visible label.
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      expect(selected, 3);

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pump();
      expect(selected, 4);
    });

    testWidgets('shows the filled icon only for the selected tab',
        (tester) async {
      await _pumpAt(
        tester,
        AppBottomNav(
          index: 0,
          onSelect: (_) {},
          destinations: _destinations,
        ),
        size: const Size(400, 800),
      );

      // Home is selected -> filled glyph; Favorites is not -> outline glyph.
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('fits a very narrow screen without overflowing',
        (tester) async {
      await _pumpAt(
        tester,
        AppBottomNav(
          index: 0,
          onSelect: (_) {},
          destinations: _destinations,
        ),
        // A small/older phone — five destinations plus the active label must
        // still fit, which is why only the selected tab is labelled.
        size: const Size(320, 640),
      );

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sits at the bottom of the Scaffold, not the middle',
        (tester) async {
      // Regression: the bar's root was a `Center`, which expanded into the
      // loose vertical constraints `bottomNavigationBar` is given and floated
      // the bar to the middle of the screen.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: AppBottomNav(
              index: 0,
              onSelect: (_) {},
              destinations: _destinations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect bar = tester.getRect(find.byType(AppBottomNav));
      // The bar must hug the bottom edge: its own height plus margin, not half
      // the screen.
      expect(bar.bottom, 800);
      expect(bar.height, lessThan(120));
    });

    testWidgets('lays out without overflow in landscape', (tester) async {
      await _pumpAt(
        tester,
        AppBottomNav(
          index: 2,
          onSelect: (_) {},
          destinations: _destinations,
        ),
        size: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PrimaryButton', () {
    testWidgets('ignores taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            text: 'SAVE',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ignores taps when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(text: 'SAVE', onPressed: null)),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('SAVE'), findsOneWidget);
    });

    testWidgets('renders an icon and label for each variant', (tester) async {
      for (final ButtonVariant variant in ButtonVariant.values) {
        await tester.pumpWidget(
          _wrap(
            PrimaryButton(
              text: 'DELETE',
              icon: Icons.delete_outline_rounded,
              variant: variant,
              onPressed: () {},
            ),
          ),
        );
        expect(find.text('DELETE'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      }
    });
  });

  group('AppTextField', () {
    testWidgets('toggles password visibility', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AppTextField(
            controller: controller,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('surfaces a validation message', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: AppTextField(
              controller: controller,
              label: 'Email',
              icon: Icons.email_outlined,
              validator: (_) => 'Enter a valid email',
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('disposes cleanly when it owns its focus node',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AppTextField(
            controller: controller,
            label: 'Name',
            icon: Icons.person_outline_rounded,
          ),
        ),
      );
      // Replacing the tree disposes the field; an internally-created focus
      // node must not throw on dispose.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('Layout resilience', () {
    const Recipe recipe = Recipe(
      title: 'A very long recipe title that would wrap onto several lines',
      category: 'Pakistani',
      cookingTimeMinutes: 45,
      calories: 620,
    );

    testWidgets('RecipeCard survives a narrow grid cell', (tester) async {
      await _pumpAt(
        tester,
        const Center(
          child: SizedBox(
            width: 120,
            height: 220,
            child: RecipeCard(recipe: recipe, width: double.infinity),
          ),
        ),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecipeCard survives a short landscape cell', (tester) async {
      await _pumpAt(
        tester,
        const Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: RecipeCard(recipe: recipe, width: double.infinity),
          ),
        ),
        size: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'RecipeCard renders in a grid cell with an image URL and infinite width',
        (tester) async {
      // Regression: the card derived its image decode size from `width`, which
      // every grid passes as `double.infinity`. `(infinity * 2).round()` throws
      // "Unsupported operation: Infinity or NaN toInt", so Favorites/Saved/
      // Search/Category all rendered a red error box instead of the recipe.
      const Recipe withImage = Recipe(
        title: 'Chicken Karahi',
        category: 'Pakistani',
        imageUrl: 'https://example.com/karahi.jpg',
      );

      await _pumpAt(
        tester,
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          children: const <Widget>[
            RecipeCard(recipe: withImage, width: double.infinity),
            RecipeCard(recipe: withImage, width: double.infinity),
          ],
        ),
        size: const Size(400, 800),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Chicken Karahi'), findsNWidgets(2));
    });

    testWidgets('EmptyState scrolls rather than overflowing when short',
        (tester) async {
      await _pumpAt(
        tester,
        const EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No saved recipes',
          message: 'Recipes you generate with AI and save will appear here.',
        ),
        // A deliberately cramped viewport, as with a keyboard open.
        size: const Size(320, 240),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('No saved recipes'), findsOneWidget);
    });

    testWidgets('CategoryChip reports taps and reflects selection',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: CategoryChip(
              label: 'Breakfast',
              selected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Breakfast'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('Tap feedback', () {
    testWidgets('PressableScale plays its press cycle before firing onTap',
        (tester) async {
      // The animation is the point: firing onTap on tapUp meant the route push
      // started on the same frame and the scale was never visible.
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: PressableScale(
              onTap: () => fired = true,
              confirmBeforeTap: true,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PressableScale));
      await tester.pump();
      // Still animating — the callback must not have run yet.
      expect(fired, isFalse);

      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });

    testWidgets('tapping the heart favorites without opening the recipe',
        (tester) async {
      // The heart lives inside the card's own PressableScale, so a mis-wired
      // gesture would both favorite AND navigate.
      var favorited = 0;
      var opened = 0;

      await _pumpAt(
        tester,
        Center(
          child: SizedBox(
            width: 180,
            height: 240,
            child: RecipeCard(
              recipe: const Recipe(title: 'Karahi', category: 'Pakistani'),
              width: double.infinity,
              onTap: () => opened++,
              onFavorite: () => favorited++,
            ),
          ),
        ),
        size: const Size(400, 800),
      );

      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();

      expect(favorited, 1);
      expect(opened, 0, reason: 'the heart must not open the recipe');
    });

    testWidgets('FavoriteButton bursts only when switching favorite ON',
        (tester) async {
      // Stateful host: the real screens flip `isFavorite` via the provider, and
      // a const `false` here would never exercise the on-switch path.
      bool favorite = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: FavoriteButton(
                isFavorite: favorite,
                onPressed: () => setState(() => favorite = !favorite),
              ),
            ),
          ),
        ),
      );

      // Reads the scale off the Transform inside the button. `getSize` can't
      // see this: Transform is a paint-time effect and does not change the
      // child's layout size.
      double heartScale() {
        final Transform t = tester.widget<Transform>(
          find
              .descendant(
                of: find.byType(FavoriteButton),
                matching: find.byType(Transform),
              )
              .first,
        );
        return t.transform.getMaxScaleOnAxis();
      }

      await tester.tap(find.byType(FavoriteButton));

      // Step through the burst and keep the largest scale seen. Sampling with
      // one big pump is unreliable — the exact peak frame depends on how the
      // tween sequence lands.
      double peak = 0;
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        peak = peak > heartScale() ? peak : heartScale();
      }
      final double midBurst = peak;

      await tester.pumpAndSettle();
      final double atRest = heartScale();

      expect(atRest, closeTo(1.0, 0.01));
      expect(
        midBurst,
        greaterThan(1.1),
        reason: 'the heart should overshoot past its resting size when '
            'favorited, which is what makes the toggle feel celebratory',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Favorite colour timing', () {
    testWidgets('heart is red on the SAME frame as the tap', (tester) async {
      // The pop must be red throughout. Waiting for the parent's state to come
      // back (or cross-fading outline→filled over 200ms) made the heart pop
      // while still colourless and only turn red afterwards.
      bool favorite = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: FavoriteButton(
                isFavorite: favorite,
                // Deliberately deferred, standing in for a Firestore write:
                // the icon must not wait for this to land.
                onPressed: () => Future<void>.delayed(
                  const Duration(milliseconds: 300),
                  () => setState(() => favorite = true),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byType(FavoriteButton));
      await tester.pump();

      // Filled red immediately, despite the parent still reporting `false`.
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      final Icon icon = tester.widget<Icon>(
        find.byIcon(Icons.favorite_rounded),
      );
      expect(icon.color, AppColors.error);

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('fills its circle with a cover fit', (tester) async {
      // A contain fit leaves empty bars inside the circle for any non-square
      // source — the black space around the profile picture.
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: ProfileAvatar(
              radius: 40,
              imageUrl: 'https://example.com/portrait.jpg',
            ),
          ),
        ),
      );

      final Image image = tester.widget<Image>(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.cover);
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('keeps the same image provider across unrelated rebuilds',
        (tester) async {
      // Regression: the provider was resolved inside build(), so every rebuild
      // decoded the base64 avatar into a NEW Uint8List. MemoryImage keys its
      // cache on that list's identity, so each rebuild was a cache miss and
      // the avatar visibly flickered — e.g. when favoriting a recipe rebuilt
      // the Home tree.
      const String dataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1'
          'HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

      late StateSetter rebuild;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return const Center(
                child: ProfileAvatar(radius: 24, imageUrl: dataUri),
              );
            },
          ),
        ),
      );

      ImageProvider<Object>? providerNow() => tester
          .widget<Image>(
            find.descendant(
              of: find.byType(ProfileAvatar),
              matching: find.byType(Image),
            ),
          )
          .image;

      final ImageProvider<Object>? first = providerNow();

      // Force an unrelated rebuild, as favoriting does.
      rebuild(() {});
      await tester.pump();

      expect(
        identical(providerNow(), first),
        isTrue,
        reason: 'a new provider per rebuild re-decodes and flickers',
      );
    });

    testWidgets('falls back to an initial without an image', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: ProfileAvatar(radius: 40, fallbackInitial: 'u'),
          ),
        ),
      );
      expect(find.text('U'), findsOneWidget);
    });
  });

  group('Recipe opening animation', () {
    const Recipe recipe = Recipe(
      title: 'Chicken Karahi',
      recipeId: '52940',
      imageUrl: 'https://example.com/karahi.jpg',
    );

    testWidgets('overlay shows the recipe being opened', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const Stack(
          children: <Widget>[RecipeOpeningOverlay(recipe: recipe)],
        )),
      );
      // A fixed pump, not pumpAndSettle: the loader's arc repeats forever, so
      // settling would never complete.
      await tester.pump(const Duration(milliseconds: 400));

      // Naming the recipe is the point — an anonymous spinner reads as a
      // stall, whereas the tapped card's title reads as progress.
      expect(find.text('Chicken Karahi'), findsOneWidget);
      expect(find.text('Getting the recipe ready…'), findsOneWidget);

      // Must absorb taps so the list underneath can't be re-tapped mid-fetch.
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('overlay falls back gracefully for an untitled recipe',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const Stack(
          children: <Widget>[
            RecipeOpeningOverlay(recipe: Recipe(title: '')),
          ],
        )),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Opening recipe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('hero tags are stable and namespaced by list', () {
      // Both ends of the flight derive the tag from this one helper. If a
      // caller hand-built the string instead and drifted, the hero would
      // silently not animate — so pin the contract.
      final String fromCard = RecipeCard.heroTagFor(recipe, prefix: 'fav-');
      final String fromDetail = RecipeCard.heroTagFor(recipe, prefix: 'fav-');
      expect(fromCard, fromDetail);

      // Different lists must not collide: the same recipe can be on screen in
      // two rails at once, and duplicate hero tags throw at runtime.
      expect(
        RecipeCard.heroTagFor(recipe, prefix: 'popular-'),
        isNot(RecipeCard.heroTagFor(recipe, prefix: 'quick-')),
      );
    });

    test('hero tag falls back to the title when a recipe has no id', () {
      const Recipe generated = Recipe(title: 'AI Pasta');
      expect(
        RecipeCard.heroTagFor(generated),
        contains('AI Pasta'),
      );
    });
  });

  group('Nav bar spacing tokens', () {
    test('overlap is smaller than clearance', () {
      // Two different jobs, and mixing them up is a real bug I hit twice:
      //  * clearance — for SCROLLABLES, which must scroll fully clear of the
      //    bar, so it includes both margins plus a breathing gap;
      //  * overlap — for a bottom-pinned surface that paints to the screen
      //    edge, which only has to clear the bar's height + margin. Using
      //    clearance there pushes the content visibly too high.
      expect(
        AppDimensions.navBarOverlap,
        lessThan(AppDimensions.navBarClearance),
      );
      expect(
        AppDimensions.navBarOverlap,
        greaterThanOrEqualTo(AppDimensions.navBarHeight),
      );
    });
  });

  group('App-wide scroll behavior', () {
    testWidgets('supplies bouncing physics with an always-scrollable parent',
        (tester) async {
      // The parent matters as much as the bounce: it is what keeps a short
      // list draggable, which is what pull-to-refresh needs to fire. Screens
      // that set `physics: AlwaysScrollableScrollPhysics()` themselves to get
      // that were silently REPLACING the bounce — exactly the Home bug this
      // guards against.
      late ScrollPhysics physics;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Builder(
            builder: (context) {
              physics = ScrollConfiguration.of(context).getScrollPhysics(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(physics, isA<BouncingScrollPhysics>());
      expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
    });

    test('no screen re-specifies scroll physics', () {
      // The bounce is applied once via ScrollConfiguration, so a local
      // `physics:` on a screen silently REPLACES it — that is how Home lost
      // its bounce. Nested scrollables are the one legitimate exception and
      // must use NeverScrollableScrollPhysics.
      final Directory lib = Directory('lib');
      final List<String> offenders = <String>[];

      for (final FileSystemEntity file in lib.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;

        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (!line.contains('physics:')) continue;
          // Comments describing the rule are not violations of it.
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('NeverScrollableScrollPhysics')) continue;
          offenders.add('${file.path}:${i + 1}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These set physics: and so override AppScrollBehavior. Remove '
            'the line (nested scrollables may use NeverScrollableScrollPhysics).',
      );
    });
  });

  group('Typography scale', () {
    test('follows the intended hierarchy', () {
      // Guards the reduced scale: a future edit that inflates one token would
      // break the visual rhythm across every screen.
      expect(AppTextStyles.display.fontSize, 28);
      expect(AppTextStyles.screenTitle.fontSize, 22);
      expect(AppTextStyles.sectionTitle.fontSize, 18);
      expect(AppTextStyles.cardTitle.fontSize, 16);
      expect(AppTextStyles.body.fontSize, 14);
      expect(AppTextStyles.caption.fontSize, 12);
      expect(AppTextStyles.label.fontSize, 11);
    });

    test('semantic aliases stay pinned to the scale', () {
      expect(AppTextStyles.heading, AppTextStyles.screenTitle);
      expect(AppTextStyles.title, AppTextStyles.sectionTitle);
      expect(AppTextStyles.subtitle.fontSize, 14);
    });

    test('headings use the display serif, UI text uses the body sans', () {
      // The pairing only works if the split holds: Fraunces carries character
      // at large sizes but is hard to read at 11-14px, so anything small must
      // stay on Inter.
      for (final TextStyle heading in <TextStyle>[
        AppTextStyles.display,
        AppTextStyles.screenTitle,
        AppTextStyles.sectionTitle,
      ]) {
        expect(heading.fontFamily, AppTextStyles.displayFamily);
      }

      for (final TextStyle ui in <TextStyle>[
        AppTextStyles.cardTitle,
        AppTextStyles.body,
        AppTextStyles.bodyMedium,
        AppTextStyles.subtitle,
        AppTextStyles.caption,
        AppTextStyles.label,
        AppTextStyles.button,
      ]) {
        expect(ui.fontFamily, AppTextStyles.fontFamily);
      }
    });

    test('the app theme defaults to the body family', () {
      // A stray default of the display serif would set every unstyled Text in
      // the app in Fraunces.
      expect(AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily,
          AppTextStyles.fontFamily);
    });
  });
}
