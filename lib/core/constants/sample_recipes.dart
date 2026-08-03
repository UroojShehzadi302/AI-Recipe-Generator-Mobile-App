import '../../models/recipe_model.dart';

/// Placeholder recipe data for the Home / Recipe Detail UI and, as of M10,
/// the Search & Categories screen.
///
/// TEMPORARY: seeds the Home rails, the detail screen, and the M10 search /
/// category browse so the app looks complete before the content backend
/// exists. Replaced by the real cached `home_feed` (Backend Architecture §6.4)
/// and a real search source (Open Decision 1) in later milestones.
///
/// Images use TheMealDB's free public food-photo CDN so real pictures show in
/// development. Replace with your own copyright-cleared photos for production.
class SampleRecipes {
  SampleRecipes._();

  static const Recipe _mushroomChicken = Recipe(
    recipeId: 'sample-mushroom-chicken',
    title: 'Creamy Mushroom Chicken',
    description:
        'Tender pan-seared chicken in a rich, garlicky mushroom cream sauce '
        'with a touch of thyme and white wine.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
    category: 'Dinner',
    cookingTimeMinutes: 30,
    difficulty: 'easy',
    servings: 2,
    calories: 480,
    nutrition: Nutrition(protein: 38, carbs: 12, fat: 28, fiber: 2),
    ingredients: [
      Ingredient(name: 'chicken breasts', quantity: '2'),
      Ingredient(name: 'mushrooms, sliced', quantity: '1 cup'),
      Ingredient(name: 'garlic cloves', quantity: '3'),
      Ingredient(name: 'heavy cream', quantity: '1 cup'),
      Ingredient(name: 'thyme', quantity: '1 tsp'),
      Ingredient(name: 'salt & pepper', quantity: 'to taste'),
    ],
    instructions: [
      'Season the chicken with salt and pepper, then sear in a hot pan until golden on both sides.',
      'Remove the chicken and sauté the mushrooms and garlic until soft.',
      'Pour in the cream and thyme, then simmer for 5 minutes.',
      'Return the chicken to the pan and cook through in the sauce.',
      'Serve warm with rice or pasta.',
    ],
    tips: [
      'Do not overcrowd the pan when searing — it steams the chicken.',
      'A splash of white wine before the cream adds depth.',
    ],
    sourceType: 'curated',
  );

  static const Recipe _breakfastPlate = Recipe(
    recipeId: 'sample-breakfast-plate',
    title: 'Full Breakfast Plate',
    description:
        'A hearty morning plate with eggs, grilled tomatoes, and toast to '
        'start the day right.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/sqrtwu1511721265.jpg',
    category: 'Breakfast',
    cookingTimeMinutes: 20,
    difficulty: 'easy',
    servings: 1,
    calories: 420,
    nutrition: Nutrition(protein: 22, carbs: 30, fat: 22, fiber: 4),
    ingredients: [
      Ingredient(name: 'eggs', quantity: '2'),
      Ingredient(name: 'tomato, halved', quantity: '1'),
      Ingredient(name: 'bread slices', quantity: '2'),
      Ingredient(name: 'butter', quantity: '1 tbsp'),
    ],
    instructions: [
      'Fry the eggs to your liking.',
      'Grill the tomato halves until soft.',
      'Toast the bread and butter it.',
      'Plate everything together and season to taste.',
    ],
    tips: ['Add a pinch of chili flakes on the eggs for a kick.'],
    sourceType: 'curated',
  );

  static const Recipe _arrabiata = Recipe(
    recipeId: 'sample-arrabiata',
    title: 'Spicy Arrabiata Pasta',
    description:
        'Penne tossed in a fiery tomato and garlic sauce with a hint of chili '
        'and fresh parsley.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg',
    category: 'Lunch',
    cookingTimeMinutes: 25,
    difficulty: 'medium',
    servings: 2,
    calories: 540,
    nutrition: Nutrition(protein: 16, carbs: 82, fat: 14, fiber: 6),
    ingredients: [
      Ingredient(name: 'penne pasta', quantity: '250 g'),
      Ingredient(name: 'crushed tomatoes', quantity: '1 can'),
      Ingredient(name: 'garlic cloves', quantity: '4'),
      Ingredient(name: 'red chili flakes', quantity: '1 tsp'),
      Ingredient(name: 'olive oil', quantity: '2 tbsp'),
      Ingredient(name: 'parsley', quantity: 'a handful'),
    ],
    instructions: [
      'Cook the penne in salted boiling water until al dente.',
      'Sauté garlic and chili flakes in olive oil until fragrant.',
      'Add the crushed tomatoes and simmer for 10 minutes.',
      'Toss the drained pasta in the sauce and finish with parsley.',
    ],
    tips: ['Save a little pasta water to loosen the sauce if needed.'],
    sourceType: 'curated',
  );

  static const Recipe _beefPie = Recipe(
    recipeId: 'sample-beef-pie',
    title: 'Beef & Mustard Pie',
    description:
        'Slow-cooked beef in a savory mustard gravy under a golden, flaky '
        'pastry lid.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/sytuqu1511553755.jpg',
    category: 'Dinner',
    cookingTimeMinutes: 45,
    difficulty: 'medium',
    servings: 4,
    calories: 610,
    nutrition: Nutrition(protein: 34, carbs: 40, fat: 32, fiber: 3),
    ingredients: [
      Ingredient(name: 'beef chunks', quantity: '500 g'),
      Ingredient(name: 'wholegrain mustard', quantity: '2 tbsp'),
      Ingredient(name: 'beef stock', quantity: '2 cups'),
      Ingredient(name: 'onion, diced', quantity: '1'),
      Ingredient(name: 'puff pastry', quantity: '1 sheet'),
    ],
    instructions: [
      'Brown the beef and onion in a pot.',
      'Stir in the mustard and stock, then simmer until the beef is tender.',
      'Transfer to a dish and top with the pastry sheet.',
      'Bake at 200°C until the pastry is golden.',
    ],
    tips: ['Brush the pastry with egg wash for extra shine.'],
    sourceType: 'curated',
  );

  static const Recipe _salmon = Recipe(
    recipeId: 'sample-salmon',
    title: 'Baked Salmon',
    description:
        'Flaky salmon fillets baked with lemon and herbs — light, healthy, '
        'and ready in minutes.',
    imageUrl: 'https://www.themealdb.com/images/media/meals/1548772327.jpg',
    category: 'Dinner',
    cookingTimeMinutes: 15,
    difficulty: 'easy',
    servings: 2,
    calories: 360,
    nutrition: Nutrition(protein: 34, carbs: 2, fat: 24, fiber: 0),
    ingredients: [
      Ingredient(name: 'salmon fillets', quantity: '2'),
      Ingredient(name: 'lemon', quantity: '1'),
      Ingredient(name: 'olive oil', quantity: '1 tbsp'),
      Ingredient(name: 'dill', quantity: '1 tsp'),
    ],
    instructions: [
      'Place the salmon on a lined tray and drizzle with olive oil.',
      'Top with lemon slices and dill, season well.',
      'Bake at 200°C for 12–15 minutes until it flakes easily.',
    ],
    tips: ['Do not overbake — salmon keeps cooking off the heat.'],
    sourceType: 'curated',
  );

  static const Recipe _pastaSalad = Recipe(
    recipeId: 'sample-pasta-salad',
    title: 'Mediterranean Pasta Salad',
    description:
        'A fresh, colorful salad with pasta, olives, tomatoes, and feta in a '
        'lemon-olive-oil dressing.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/wtsvxx1511296896.jpg',
    category: 'Healthy',
    cookingTimeMinutes: 18,
    difficulty: 'easy',
    servings: 3,
    calories: 290,
    nutrition: Nutrition(protein: 10, carbs: 38, fat: 12, fiber: 5),
    ingredients: [
      Ingredient(name: 'fusilli pasta', quantity: '200 g'),
      Ingredient(name: 'cherry tomatoes', quantity: '1 cup'),
      Ingredient(name: 'olives', quantity: '1/2 cup'),
      Ingredient(name: 'feta cheese', quantity: '100 g'),
      Ingredient(name: 'lemon juice', quantity: '2 tbsp'),
    ],
    instructions: [
      'Cook and cool the pasta.',
      'Chop the tomatoes and combine with olives and feta.',
      'Toss everything with lemon juice and olive oil, then chill.',
    ],
    tips: ['Make it ahead — it tastes better after resting in the fridge.'],
    sourceType: 'curated',
  );

  static const Recipe _pancakes = Recipe(
    recipeId: 'sample-pancakes',
    title: 'Fluffy Pancakes',
    description:
        'Light, airy pancakes stacked high and perfect with syrup and fresh '
        'berries.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/rwuyqx1511383174.jpg',
    category: 'Breakfast',
    cookingTimeMinutes: 20,
    difficulty: 'easy',
    servings: 2,
    calories: 340,
    nutrition: Nutrition(protein: 9, carbs: 54, fat: 10, fiber: 2),
    ingredients: [
      Ingredient(name: 'flour', quantity: '1 cup'),
      Ingredient(name: 'milk', quantity: '3/4 cup'),
      Ingredient(name: 'egg', quantity: '1'),
      Ingredient(name: 'baking powder', quantity: '2 tsp'),
      Ingredient(name: 'sugar', quantity: '2 tbsp'),
    ],
    instructions: [
      'Whisk the dry and wet ingredients into a smooth batter.',
      'Pour rounds onto a greased pan over medium heat.',
      'Flip when bubbles form and cook until golden.',
    ],
    tips: ['Do not overmix — a few lumps keep pancakes fluffy.'],
    sourceType: 'curated',
  );

  static const Recipe _avocadoToast = Recipe(
    recipeId: 'sample-avocado-toast',
    title: 'Avocado Toast with Egg',
    description:
        'Creamy smashed avocado on toasted sourdough, topped with a soft '
        'poached egg and chili flakes.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/1550441882.jpg',
    category: 'Breakfast',
    cookingTimeMinutes: 12,
    difficulty: 'easy',
    servings: 1,
    calories: 310,
    nutrition: Nutrition(protein: 14, carbs: 26, fat: 18, fiber: 7),
    ingredients: [
      Ingredient(name: 'sourdough bread', quantity: '2 slices'),
      Ingredient(name: 'ripe avocado', quantity: '1'),
      Ingredient(name: 'egg', quantity: '1'),
      Ingredient(name: 'chili flakes', quantity: 'a pinch'),
      Ingredient(name: 'lemon juice', quantity: '1 tsp'),
    ],
    instructions: [
      'Toast the sourdough until golden and crisp.',
      'Smash the avocado with lemon juice, salt, and pepper.',
      'Poach the egg in gently simmering water for 3 minutes.',
      'Spread the avocado on the toast, top with the egg and chili flakes.',
    ],
    tips: ['A splash of vinegar in the water helps the egg white hold together.'],
    sourceType: 'curated',
  );

  static const Recipe _caesarWrap = Recipe(
    recipeId: 'sample-caesar-wrap',
    title: 'Chicken Caesar Wrap',
    description:
        'Grilled chicken, crisp romaine, and parmesan tossed in creamy Caesar '
        'dressing, rolled in a soft tortilla.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/2dsltq1560461468.jpg',
    category: 'Lunch',
    cookingTimeMinutes: 20,
    difficulty: 'easy',
    servings: 2,
    calories: 460,
    nutrition: Nutrition(protein: 32, carbs: 34, fat: 22, fiber: 3),
    ingredients: [
      Ingredient(name: 'chicken breast', quantity: '1'),
      Ingredient(name: 'romaine lettuce', quantity: '2 cups'),
      Ingredient(name: 'parmesan, grated', quantity: '1/4 cup'),
      Ingredient(name: 'Caesar dressing', quantity: '3 tbsp'),
      Ingredient(name: 'large tortillas', quantity: '2'),
    ],
    instructions: [
      'Season and grill the chicken, then slice into strips.',
      'Toss the romaine and parmesan with the Caesar dressing.',
      'Lay the salad and chicken along each tortilla.',
      'Roll tightly, tucking in the sides, then halve and serve.',
    ],
    tips: ['Warm the tortillas briefly so they roll without cracking.'],
    sourceType: 'curated',
  );

  static const Recipe _garlicShrimp = Recipe(
    recipeId: 'sample-garlic-shrimp',
    title: 'Garlic Butter Shrimp',
    description:
        'Juicy shrimp sautéed in garlic butter with a squeeze of lemon and a '
        'sprinkle of parsley — ready in minutes.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/1529443236.jpg',
    category: 'Dinner',
    cookingTimeMinutes: 15,
    difficulty: 'easy',
    servings: 2,
    calories: 320,
    nutrition: Nutrition(protein: 30, carbs: 4, fat: 20, fiber: 1),
    ingredients: [
      Ingredient(name: 'large shrimp, peeled', quantity: '400 g'),
      Ingredient(name: 'butter', quantity: '3 tbsp'),
      Ingredient(name: 'garlic cloves, minced', quantity: '4'),
      Ingredient(name: 'lemon', quantity: '1/2'),
      Ingredient(name: 'parsley, chopped', quantity: '2 tbsp'),
    ],
    instructions: [
      'Melt the butter in a large pan over medium-high heat.',
      'Add the garlic and cook until fragrant, about 30 seconds.',
      'Add the shrimp and cook 2 minutes per side until pink.',
      'Finish with lemon juice and parsley, then serve.',
    ],
    tips: ['Do not overcook — shrimp turn rubbery once past opaque.'],
    sourceType: 'curated',
  );

  static const Recipe _quinoaSalad = Recipe(
    recipeId: 'sample-quinoa-salad',
    title: 'Quinoa Avocado Salad',
    description:
        'A protein-packed bowl of fluffy quinoa, avocado, cucumber, and cherry '
        'tomatoes in a zesty lime dressing.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/xxpqsy1511452222.jpg',
    category: 'Healthy',
    cookingTimeMinutes: 22,
    difficulty: 'easy',
    servings: 3,
    calories: 280,
    nutrition: Nutrition(protein: 11, carbs: 36, fat: 12, fiber: 8),
    ingredients: [
      Ingredient(name: 'quinoa', quantity: '1 cup'),
      Ingredient(name: 'avocado, diced', quantity: '1'),
      Ingredient(name: 'cucumber, diced', quantity: '1'),
      Ingredient(name: 'cherry tomatoes', quantity: '1 cup'),
      Ingredient(name: 'lime juice', quantity: '2 tbsp'),
    ],
    instructions: [
      'Rinse and cook the quinoa, then let it cool.',
      'Combine the avocado, cucumber, and tomatoes in a bowl.',
      'Fold in the quinoa and toss with lime juice and olive oil.',
      'Season to taste and serve chilled.',
    ],
    tips: ['Toast the quinoa dry for a minute before boiling for a nutty flavor.'],
    sourceType: 'curated',
  );

  static const Recipe _chocolateCookies = Recipe(
    recipeId: 'sample-chocolate-cookies',
    title: 'Chocolate Chip Cookies',
    description:
        'Soft, chewy cookies with gooey chocolate chips and crisp golden '
        'edges — a timeless bake.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/uttupv1511815050.jpg',
    category: 'Desserts',
    cookingTimeMinutes: 25,
    difficulty: 'easy',
    servings: 12,
    calories: 190,
    nutrition: Nutrition(protein: 3, carbs: 26, fat: 9, fiber: 1),
    ingredients: [
      Ingredient(name: 'flour', quantity: '2 cups'),
      Ingredient(name: 'butter, softened', quantity: '1 cup'),
      Ingredient(name: 'brown sugar', quantity: '3/4 cup'),
      Ingredient(name: 'egg', quantity: '1'),
      Ingredient(name: 'chocolate chips', quantity: '1 cup'),
    ],
    instructions: [
      'Cream the butter and sugar until light and fluffy.',
      'Beat in the egg, then fold in the flour and chocolate chips.',
      'Scoop rounds onto a lined tray, spacing them apart.',
      'Bake at 180°C for 10–12 minutes until the edges are golden.',
    ],
    tips: ['Pull them out while the centers still look soft — they set as they cool.'],
    sourceType: 'curated',
  );

  static const Recipe _berryCheesecake = Recipe(
    recipeId: 'sample-berry-cheesecake',
    title: 'No-Bake Berry Cheesecake',
    description:
        'A creamy, tangy cheesecake on a buttery biscuit base, crowned with '
        'fresh mixed berries — no oven required.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/wxywrq1468235067.jpg',
    category: 'Desserts',
    cookingTimeMinutes: 30,
    difficulty: 'medium',
    servings: 8,
    calories: 360,
    nutrition: Nutrition(protein: 6, carbs: 34, fat: 23, fiber: 2),
    ingredients: [
      Ingredient(name: 'digestive biscuits', quantity: '200 g'),
      Ingredient(name: 'butter, melted', quantity: '100 g'),
      Ingredient(name: 'cream cheese', quantity: '400 g'),
      Ingredient(name: 'icing sugar', quantity: '1/2 cup'),
      Ingredient(name: 'mixed berries', quantity: '1 cup'),
    ],
    instructions: [
      'Crush the biscuits and mix with melted butter, then press into a tin.',
      'Beat the cream cheese with icing sugar until smooth.',
      'Spread the filling over the base and chill for at least 4 hours.',
      'Top with fresh berries just before serving.',
    ],
    tips: ['Chill overnight for the cleanest slices.'],
    sourceType: 'curated',
  );

  static const Recipe _buddhaBowl = Recipe(
    recipeId: 'sample-buddha-bowl',
    title: 'Chickpea Buddha Bowl',
    description:
        'A wholesome vegan bowl of roasted chickpeas, sweet potato, kale, and '
        'brown rice drizzled with tahini dressing.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/1520084413.jpg',
    category: 'Vegan',
    cookingTimeMinutes: 35,
    difficulty: 'easy',
    servings: 2,
    calories: 420,
    nutrition: Nutrition(protein: 15, carbs: 62, fat: 14, fiber: 12),
    ingredients: [
      Ingredient(name: 'chickpeas, drained', quantity: '1 can'),
      Ingredient(name: 'sweet potato, cubed', quantity: '1'),
      Ingredient(name: 'kale', quantity: '2 cups'),
      Ingredient(name: 'cooked brown rice', quantity: '1 cup'),
      Ingredient(name: 'tahini', quantity: '2 tbsp'),
    ],
    instructions: [
      'Roast the chickpeas and sweet potato with olive oil at 200°C for 25 minutes.',
      'Massage the kale with a little oil and lemon until softened.',
      'Whisk the tahini with water and lemon into a pourable dressing.',
      'Assemble the rice, roasted veg, and kale in a bowl and drizzle with tahini.',
    ],
    tips: ['Pat the chickpeas dry before roasting so they crisp up.'],
    sourceType: 'curated',
  );

  static const Recipe _lentilCurry = Recipe(
    recipeId: 'sample-lentil-curry',
    title: 'Coconut Lentil Curry',
    description:
        'A cozy vegan curry of red lentils simmered in coconut milk with '
        'ginger, garlic, and warm spices.',
    imageUrl:
        'https://www.themealdb.com/images/media/meals/wtqvvv1511180578.jpg',
    category: 'Vegan',
    cookingTimeMinutes: 30,
    difficulty: 'easy',
    servings: 4,
    calories: 380,
    nutrition: Nutrition(protein: 16, carbs: 48, fat: 14, fiber: 11),
    ingredients: [
      Ingredient(name: 'red lentils', quantity: '1 cup'),
      Ingredient(name: 'coconut milk', quantity: '1 can'),
      Ingredient(name: 'onion, diced', quantity: '1'),
      Ingredient(name: 'garlic & ginger paste', quantity: '1 tbsp'),
      Ingredient(name: 'curry powder', quantity: '2 tsp'),
    ],
    instructions: [
      'Sauté the onion, garlic, and ginger until soft.',
      'Stir in the curry powder and cook for a minute until fragrant.',
      'Add the lentils, coconut milk, and a cup of water.',
      'Simmer for 20 minutes until the lentils are tender, then season.',
    ],
    tips: ['Finish with a squeeze of lime and fresh coriander.'],
    sourceType: 'curated',
  );

  static const List<Recipe> popular = <Recipe>[
    _mushroomChicken,
    _breakfastPlate,
    _arrabiata,
    _beefPie,
  ];

  static const List<Recipe> quickAndEasy = <Recipe>[
    _salmon,
    _pastaSalad,
    _pancakes,
  ];

  static const List<String> categories = <String>[
    'For You',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Desserts',
    'Healthy',
    'Vegan',
    'Pakistani',
  ];

  /// Every recipe defined in this file, used to back Search & Categories (M10).
  static const List<Recipe> all = <Recipe>[
    _mushroomChicken,
    _breakfastPlate,
    _arrabiata,
    _beefPie,
    _salmon,
    _pastaSalad,
    _pancakes,
    _avocadoToast,
    _caesarWrap,
    _garlicShrimp,
    _quinoaSalad,
    _chocolateCookies,
    _berryCheesecake,
    _buddhaBowl,
    _lentilCurry,
  ];

  /// Recipes whose [Recipe.category] matches [category] case-insensitively.
  ///
  /// An empty category or `'For You'` (the "all" pseudo-category) returns
  /// every recipe.
  static List<Recipe> byCategory(String category) {
    final String normalized = category.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'for you') {
      return all;
    }
    return all
        .where((Recipe r) => r.category.trim().toLowerCase() == normalized)
        .toList(growable: false);
  }

  /// Popular search suggestions shown on the empty Search screen (M10).
  static const List<String> popularSearches = <String>[
    'Chicken',
    'Pasta',
    'Salad',
    'Vegan',
    'Dessert',
    'Breakfast',
  ];
}
