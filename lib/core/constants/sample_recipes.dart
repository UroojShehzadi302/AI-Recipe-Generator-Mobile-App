import '../../models/recipe_model.dart';

/// Placeholder recipe data for the Home / Recipe Detail UI.
///
/// TEMPORARY: seeds the Home rails and the detail screen so the redesign looks
/// complete before the content backend exists. Replaced by the real cached
/// `home_feed` (Backend Architecture §6.4) in milestone M5.
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
  ];
}
