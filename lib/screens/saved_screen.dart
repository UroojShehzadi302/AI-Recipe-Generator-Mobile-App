import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/recipe_card.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Saved tab — recipes the user generated with AI and kept.
///
/// Loads from Firestore (`users/{uid}/generatedRecipes`) via [RecipeProvider].
/// Stays empty until AI generation ships (M6); shows a branded empty state.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<RecipeProvider>().loadSaved(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<RecipeProvider>().saved;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Recipes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: saved.isEmpty
                  ? const EmptyState(
                      icon: Icons.bookmark_border,
                      title: 'No saved recipes',
                      message:
                          'Recipes you generate with AI and save will appear here.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.recipeGridColumns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.74,
                      ),
                      itemCount: saved.length,
                      itemBuilder: (context, i) => RecipeCard(
                        recipe: saved[i],
                        width: double.infinity,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.recipeDetail,
                          arguments: saved[i],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
