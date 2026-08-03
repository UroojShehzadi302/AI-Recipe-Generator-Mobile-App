import '../../models/recipe_model.dart';

/// Curated built-in Pakistani / desi recipe set — authentic South Asian dishes
/// (biryani, karahi, nihari, haleem, kebabs, daal, and more).
///
/// WHY THIS EXISTS: TheMealDB's free tier has no Pakistani catalog, so the
/// app would otherwise show none of the region's staples. This hand-authored
/// set fills that gap. `RecipeRepository` blends these into the app's content
/// so they surface under the `'Pakistani'` category and in search alongside
/// the network feed.
///
/// The nutrition and calorie figures here are AUTHORED curated estimates
/// (reasonable per-serving values), not measured lab data. Images are real,
/// dish-accurate photos from Wikimedia Commons (free-licensed, served as 500px
/// thumbnails); the app falls back to a warm gradient if any URL fails.
class DesiRecipes {
  DesiRecipes._();

  static const Recipe _chickenBiryani = Recipe(
    recipeId: 'desi-chicken-biryani',
    title: 'Chicken Biryani',
    description:
        'Fragrant basmati rice layered with spiced chicken, caramelised '
        'onions, and saffron — the celebratory centrepiece of any desi table.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/%22Hyderabadi_Dum_Biryani%22.jpg/500px-%22Hyderabadi_Dum_Biryani%22.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 75,
    difficulty: 'hard',
    servings: 6,
    calories: 620,
    nutrition: Nutrition(protein: 34, carbs: 68, fat: 24, fiber: 4),
    ingredients: [
      Ingredient(name: 'basmati rice', quantity: '3 cups'),
      Ingredient(name: 'chicken, bone-in', quantity: '1 kg'),
      Ingredient(name: 'yogurt', quantity: '1 cup'),
      Ingredient(name: 'onions, thinly sliced', quantity: '3 large'),
      Ingredient(name: 'ginger-garlic paste', quantity: '2 tbsp'),
      Ingredient(name: 'biryani masala', quantity: '3 tbsp'),
      Ingredient(name: 'tomatoes, chopped', quantity: '2'),
      Ingredient(name: 'green chilies', quantity: '4'),
      Ingredient(name: 'saffron soaked in warm milk', quantity: '1/2 cup'),
      Ingredient(name: 'ghee', quantity: '1/4 cup'),
      Ingredient(name: 'fresh coriander & mint', quantity: 'a handful'),
    ],
    instructions: [
      'Deep-fry the sliced onions until golden and crisp, then set aside; keep the oil.',
      'Marinate the chicken in yogurt, ginger-garlic paste, biryani masala, and half the fried onions for 30 minutes.',
      'Cook the marinated chicken with tomatoes and green chilies until the oil separates and the masala thickens.',
      'Parboil the soaked basmati rice with whole spices and salt until 70% done, then drain.',
      'Layer the rice over the chicken masala, scatter coriander, mint, remaining onions, saffron milk, and ghee.',
      'Cover tightly and steam (dum) on the lowest heat for 20 minutes.',
      'Gently fold from the bottom and serve hot with raita.',
    ],
    tips: [
      'Soak the rice for 30 minutes so the grains stay long and separate.',
      'Seal the pot with dough or a tight lid to trap the dum steam.',
    ],
    tags: ['Pakistani', 'Rice', 'Spicy', 'Chicken'],
    sourceType: 'curated',
  );

  static const Recipe _chickenKarahi = Recipe(
    recipeId: 'desi-chicken-karahi',
    title: 'Chicken Karahi',
    description:
        'A bold, tomato-forward wok curry of chicken cooked with ginger, '
        'green chilies, and whole spices — a dhaba-style Pakistani classic.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Punjabi_Chicken_Karahi.JPG/500px-Punjabi_Chicken_Karahi.JPG',
    category: 'Pakistani',
    cookingTimeMinutes: 40,
    difficulty: 'medium',
    servings: 4,
    calories: 480,
    nutrition: Nutrition(protein: 36, carbs: 12, fat: 32, fiber: 3),
    ingredients: [
      Ingredient(name: 'chicken, cut into pieces', quantity: '1 kg'),
      Ingredient(name: 'tomatoes, ripe', quantity: '5 medium'),
      Ingredient(name: 'ginger-garlic paste', quantity: '2 tbsp'),
      Ingredient(name: 'green chilies, slit', quantity: '5'),
      Ingredient(name: 'cooking oil', quantity: '1/2 cup'),
      Ingredient(name: 'crushed red chili', quantity: '1 tbsp'),
      Ingredient(name: 'crushed coriander seeds', quantity: '1 tbsp'),
      Ingredient(name: 'garam masala', quantity: '1 tsp'),
      Ingredient(name: 'julienned ginger', quantity: 'for garnish'),
    ],
    instructions: [
      'Heat the oil and fry the chicken with ginger-garlic paste until it changes colour.',
      'Add the chopped tomatoes, cover, and cook until they break down and soften.',
      'Uncover and stir-fry on high heat until the oil separates and the masala clings to the chicken.',
      'Add crushed red chili, coriander seeds, and salt; bhuno for a few minutes.',
      'Finish with garam masala, slit green chilies, and julienned ginger.',
      'Serve sizzling with naan.',
    ],
    tips: [
      'Cook on high heat and keep the sauce thick — karahi should not be watery.',
      'Use fresh ripe tomatoes rather than paste for the authentic tang.',
    ],
    tags: ['Pakistani', 'Curry', 'Spicy', 'Chicken'],
    sourceType: 'curated',
  );

  static const Recipe _beefNihari = Recipe(
    recipeId: 'desi-beef-nihari',
    title: 'Beef Nihari',
    description:
        'A slow-cooked, deeply spiced beef stew in a rich, silky gravy — '
        'traditionally a Pakistani breakfast eaten with naan.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/Nalli_Nihari_India.jpg/500px-Nalli_Nihari_India.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 240,
    difficulty: 'hard',
    servings: 6,
    calories: 560,
    nutrition: Nutrition(protein: 40, carbs: 18, fat: 36, fiber: 3),
    ingredients: [
      Ingredient(name: 'beef shank, bone-in', quantity: '1.5 kg'),
      Ingredient(name: 'nihari masala', quantity: '4 tbsp'),
      Ingredient(name: 'wheat flour', quantity: '1/2 cup'),
      Ingredient(name: 'ginger-garlic paste', quantity: '2 tbsp'),
      Ingredient(name: 'onions, sliced', quantity: '2'),
      Ingredient(name: 'ghee or oil', quantity: '1 cup'),
      Ingredient(name: 'bone marrow (optional)', quantity: '2 pieces'),
      Ingredient(name: 'julienned ginger & lemon', quantity: 'to serve'),
    ],
    instructions: [
      'Fry the sliced onions in ghee until golden, then add ginger-garlic paste.',
      'Add the beef and sear, then stir in the nihari masala and salt.',
      'Pour in plenty of water, cover, and simmer on very low heat for 3–4 hours until the meat is fork-tender.',
      'Whisk the wheat flour into a little water and stir into the stew to thicken the gravy.',
      'Simmer another 20 minutes until glossy and rich, adding bone marrow if using.',
      'Serve topped with julienned ginger, fresh coriander, and a squeeze of lemon.',
    ],
    tips: [
      'The longer and slower the cook, the silkier the gravy — do not rush it.',
      'Temper a spoon of hot oil with red chili on top just before serving.',
    ],
    tags: ['Pakistani', 'Beef', 'Slow-Cooked', 'Spicy'],
    sourceType: 'curated',
  );

  static const Recipe _haleem = Recipe(
    recipeId: 'desi-haleem',
    title: 'Haleem',
    description:
        'A hearty, slow-simmered porridge of wheat, barley, lentils, and '
        'shredded meat blended into a thick, spiced comfort dish.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Pakistani_Haleem_served_with_garnish.jpg/500px-Pakistani_Haleem_served_with_garnish.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 180,
    difficulty: 'hard',
    servings: 8,
    calories: 430,
    nutrition: Nutrition(protein: 26, carbs: 44, fat: 16, fiber: 8),
    ingredients: [
      Ingredient(name: 'boneless beef or chicken', quantity: '750 g'),
      Ingredient(name: 'cracked wheat', quantity: '1 cup'),
      Ingredient(name: 'barley', quantity: '1/4 cup'),
      Ingredient(name: 'mixed lentils (chana, masoor, moong)', quantity: '1 cup'),
      Ingredient(name: 'ginger-garlic paste', quantity: '2 tbsp'),
      Ingredient(name: 'haleem masala', quantity: '3 tbsp'),
      Ingredient(name: 'fried onions', quantity: '1 cup'),
      Ingredient(name: 'ghee', quantity: '1/2 cup'),
      Ingredient(name: 'ginger, chilies & lemon', quantity: 'to garnish'),
    ],
    instructions: [
      'Soak the wheat, barley, and lentils together for a few hours, then boil until very soft.',
      'Separately cook the meat with ginger-garlic paste and haleem masala until tender, then shred it.',
      'Blend the cooked grains and lentils into a smooth, thick paste.',
      'Combine the shredded meat with the grain paste and simmer, stirring constantly, until it thickens.',
      'Beat in ghee and adjust the consistency and salt.',
      'Serve topped with fried onions, julienned ginger, green chilies, coriander, and lemon.',
    ],
    tips: [
      'Stir often near the end so the thick haleem does not catch and burn.',
      'Mash thoroughly — the signature texture is smooth, not chunky.',
    ],
    tags: ['Pakistani', 'Lentils', 'Slow-Cooked', 'Comfort'],
    sourceType: 'curated',
  );

  static const Recipe _chapliKebab = Recipe(
    recipeId: 'desi-chapli-kebab',
    title: 'Chapli Kebab',
    description:
        'A flat, spiced minced-beef patty from Khyber Pakhtunkhwa, studded '
        'with tomato and coriander seeds and shallow-fried until crisp.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Chapli_Kebab.jpg/500px-Chapli_Kebab.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 35,
    difficulty: 'medium',
    servings: 4,
    calories: 400,
    nutrition: Nutrition(protein: 24, carbs: 10, fat: 30, fiber: 2),
    ingredients: [
      Ingredient(name: 'minced beef', quantity: '500 g'),
      Ingredient(name: 'tomato, finely chopped', quantity: '1'),
      Ingredient(name: 'onion, finely chopped', quantity: '1'),
      Ingredient(name: 'coarsely crushed coriander seeds', quantity: '2 tbsp'),
      Ingredient(name: 'crushed red chili', quantity: '1 tbsp'),
      Ingredient(name: 'cornmeal or gram flour', quantity: '3 tbsp'),
      Ingredient(name: 'egg', quantity: '1'),
      Ingredient(name: 'green chilies & coriander', quantity: 'a handful'),
      Ingredient(name: 'oil for shallow frying', quantity: 'as needed'),
    ],
    instructions: [
      'Mix the mince with chopped tomato, onion, crushed coriander seeds, red chili, egg, and cornmeal.',
      'Fold in the green chilies and fresh coriander and season with salt.',
      'Rest the mixture for 20 minutes so the flavours meld.',
      'Shape into wide, flat, thin patties.',
      'Shallow-fry in hot oil until deeply browned and crisp on both sides.',
      'Serve hot with naan, sliced onions, and chutney.',
    ],
    tips: [
      'Keep the patties thin and wide — that is the defining chapli shape.',
      'Press a tomato slice into the top of each patty before frying for authenticity.',
    ],
    tags: ['Pakistani', 'Kebab', 'Beef', 'Fried'],
    sourceType: 'curated',
  );

  static const Recipe _chanaDaal = Recipe(
    recipeId: 'desi-chana-daal',
    title: 'Chana Daal',
    description:
        'Split chickpea lentils simmered until tender and finished with a '
        'sizzling garlic-and-cumin tarka — everyday desi comfort food.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Chana_Dal_Curry.jpg/500px-Chana_Dal_Curry.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 50,
    difficulty: 'easy',
    servings: 4,
    calories: 300,
    nutrition: Nutrition(protein: 15, carbs: 42, fat: 8, fiber: 11),
    ingredients: [
      Ingredient(name: 'chana daal (split chickpeas)', quantity: '1.5 cups'),
      Ingredient(name: 'onion, chopped', quantity: '1'),
      Ingredient(name: 'tomato, chopped', quantity: '1'),
      Ingredient(name: 'ginger-garlic paste', quantity: '1 tbsp'),
      Ingredient(name: 'turmeric', quantity: '1/2 tsp'),
      Ingredient(name: 'red chili powder', quantity: '1 tsp'),
      Ingredient(name: 'cumin seeds', quantity: '1 tsp'),
      Ingredient(name: 'garlic cloves, sliced', quantity: '4'),
      Ingredient(name: 'oil or ghee', quantity: '3 tbsp'),
    ],
    instructions: [
      'Rinse and soak the chana daal for 30 minutes, then boil with turmeric and salt until soft but not mushy.',
      'In a separate pan, fry the onion until golden, then add ginger-garlic paste and tomato.',
      'Stir in the red chili powder and cook until the masala thickens.',
      'Fold the cooked daal into the masala and simmer to your preferred consistency.',
      'For the tarka, heat oil and fry cumin seeds and sliced garlic until golden, then pour over the daal.',
      'Garnish with fresh coriander and serve with roti or rice.',
    ],
    tips: [
      'Do not overcook the daal — the grains should hold their shape.',
      'The final garlic tarka is essential for the authentic aroma.',
    ],
    tags: ['Pakistani', 'Lentils', 'Vegetarian', 'Comfort'],
    sourceType: 'curated',
  );

  static const Recipe _alooGosht = Recipe(
    recipeId: 'desi-aloo-gosht',
    title: 'Aloo Gosht',
    description:
        'A homely curry of tender mutton or beef and potatoes in a spiced '
        'onion-tomato gravy — a staple of Pakistani home kitchens.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Aaloo_Gosht_%28cropped%29.JPG/500px-Aaloo_Gosht_%28cropped%29.JPG',
    category: 'Pakistani',
    cookingTimeMinutes: 90,
    difficulty: 'medium',
    servings: 5,
    calories: 470,
    nutrition: Nutrition(protein: 30, carbs: 26, fat: 28, fiber: 4),
    ingredients: [
      Ingredient(name: 'mutton or beef, cubed', quantity: '1 kg'),
      Ingredient(name: 'potatoes, peeled & halved', quantity: '4'),
      Ingredient(name: 'onions, sliced', quantity: '2'),
      Ingredient(name: 'tomatoes, chopped', quantity: '2'),
      Ingredient(name: 'ginger-garlic paste', quantity: '2 tbsp'),
      Ingredient(name: 'red chili powder', quantity: '1 tbsp'),
      Ingredient(name: 'turmeric', quantity: '1/2 tsp'),
      Ingredient(name: 'coriander powder', quantity: '1 tbsp'),
      Ingredient(name: 'oil', quantity: '1/2 cup'),
      Ingredient(name: 'garam masala', quantity: '1 tsp'),
    ],
    instructions: [
      'Fry the sliced onions in oil until golden, then add ginger-garlic paste.',
      'Add the meat and sear, then stir in the tomatoes and ground spices.',
      'Bhuno (stir-fry) until the oil separates and the masala is thick.',
      'Add water, cover, and simmer until the meat is nearly tender.',
      'Add the potatoes and cook until both meat and potatoes are soft and the gravy thickens.',
      'Finish with garam masala and fresh coriander; serve with roti.',
    ],
    tips: [
      'Add the potatoes only after the meat is nearly done so they do not disintegrate.',
      'A pressure cooker cuts the meat-tenderising time roughly in half.',
    ],
    tags: ['Pakistani', 'Curry', 'Beef', 'Comfort'],
    sourceType: 'curated',
  );

  static const Recipe _seekhKabab = Recipe(
    recipeId: 'desi-seekh-kabab',
    title: 'Seekh Kabab',
    description:
        'Spiced minced meat moulded onto skewers and grilled until smoky and '
        'juicy — a barbecue and iftar favourite across Pakistan.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/Pakistani_Food_Beef_Kabobs.jpg/500px-Pakistani_Food_Beef_Kabobs.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 40,
    difficulty: 'medium',
    servings: 4,
    calories: 350,
    nutrition: Nutrition(protein: 26, carbs: 6, fat: 24, fiber: 1),
    ingredients: [
      Ingredient(name: 'minced beef or mutton', quantity: '500 g'),
      Ingredient(name: 'onion, grated & squeezed dry', quantity: '1'),
      Ingredient(name: 'ginger-garlic paste', quantity: '1 tbsp'),
      Ingredient(name: 'green chilies, minced', quantity: '3'),
      Ingredient(name: 'red chili powder', quantity: '1 tsp'),
      Ingredient(name: 'roasted cumin powder', quantity: '1 tsp'),
      Ingredient(name: 'garam masala', quantity: '1 tsp'),
      Ingredient(name: 'gram flour, roasted', quantity: '2 tbsp'),
      Ingredient(name: 'fresh coriander, chopped', quantity: '1/4 cup'),
    ],
    instructions: [
      'Blend the mince with all the spices, grated onion, chilies, and coriander into a sticky, smooth mixture.',
      'Knead well and chill for 30 minutes so the kababs hold together.',
      'Wet your hands and mould the mixture firmly along metal skewers.',
      'Grill over charcoal or a hot pan, turning, until browned and cooked through.',
      'Brush with a little oil while grilling to keep them juicy.',
      'Serve with naan, onion rings, and mint chutney.',
    ],
    tips: [
      'Squeeze all moisture from the grated onion or the kababs will slide off the skewer.',
      'A piece of coal smoked in the covered bowl (dhungar) adds authentic barbecue aroma.',
    ],
    tags: ['Pakistani', 'Kebab', 'Grilled', 'BBQ'],
    sourceType: 'curated',
  );

  static const Recipe _chanaChaat = Recipe(
    recipeId: 'desi-chana-chaat',
    title: 'Chana Chaat',
    description:
        'A tangy, refreshing chickpea salad tossed with potato, onion, and '
        'chaat masala — a beloved Ramadan iftar street snack.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Chana_Chaat.jpg/500px-Chana_Chaat.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 20,
    difficulty: 'easy',
    servings: 4,
    calories: 240,
    nutrition: Nutrition(protein: 10, carbs: 40, fat: 5, fiber: 9),
    ingredients: [
      Ingredient(name: 'boiled chickpeas', quantity: '2 cups'),
      Ingredient(name: 'boiled potato, diced', quantity: '1'),
      Ingredient(name: 'onion, finely chopped', quantity: '1'),
      Ingredient(name: 'tomato, diced', quantity: '1'),
      Ingredient(name: 'green chilies, chopped', quantity: '2'),
      Ingredient(name: 'chaat masala', quantity: '1 tbsp'),
      Ingredient(name: 'tamarind chutney', quantity: '3 tbsp'),
      Ingredient(name: 'lemon juice', quantity: '2 tbsp'),
      Ingredient(name: 'fresh coriander', quantity: 'a handful'),
    ],
    instructions: [
      'Add the boiled chickpeas and potato to a large bowl.',
      'Mix in the chopped onion, tomato, and green chilies.',
      'Sprinkle over the chaat masala, salt, and lemon juice.',
      'Drizzle with tamarind chutney and toss everything gently.',
      'Garnish with fresh coriander and serve chilled.',
    ],
    tips: [
      'Add the tamarind chutney and lemon just before serving so it stays crisp.',
      'A sprinkle of crushed papri or sev on top adds crunch.',
    ],
    tags: ['Pakistani', 'Snack', 'Vegetarian', 'Street Food'],
    sourceType: 'curated',
  );

  static const Recipe _kheer = Recipe(
    recipeId: 'desi-kheer',
    title: 'Kheer',
    description:
        'A slow-cooked rice pudding simmered in milk with cardamom and nuts — '
        'the classic desi dessert for weddings and festive occasions.',
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/Kheer.jpg/500px-Kheer.jpg',
    category: 'Pakistani',
    cookingTimeMinutes: 60,
    difficulty: 'easy',
    servings: 6,
    calories: 320,
    nutrition: Nutrition(protein: 8, carbs: 48, fat: 11, fiber: 1),
    ingredients: [
      Ingredient(name: 'full-fat milk', quantity: '1.5 litres'),
      Ingredient(name: 'basmati rice', quantity: '1/3 cup'),
      Ingredient(name: 'sugar', quantity: '3/4 cup'),
      Ingredient(name: 'green cardamom pods', quantity: '4'),
      Ingredient(name: 'almonds & pistachios, slivered', quantity: '1/4 cup'),
      Ingredient(name: 'kewra or rose water', quantity: '1 tsp'),
    ],
    instructions: [
      'Rinse and soak the rice for 20 minutes, then drain.',
      'Bring the milk to a boil with the crushed cardamom, then add the rice.',
      'Simmer on low heat, stirring often, until the rice is soft and the milk thickens.',
      'Stir in the sugar and half the nuts and cook a few more minutes.',
      'Add the kewra or rose water and remove from the heat.',
      'Garnish with the remaining nuts and serve warm or chilled.',
    ],
    tips: [
      'Stir frequently to stop the milk sticking and to build a creamy texture.',
      'Kheer thickens as it cools, so keep it slightly loose on the stove.',
    ],
    tags: ['Pakistani', 'Dessert', 'Sweet', 'Rice'],
    sourceType: 'curated',
  );

  /// Every curated Pakistani recipe defined in this file, in menu order.
  /// Blended into the app's content by `RecipeRepository` and surfaced under
  /// the `'Pakistani'` category and in search.
  static const List<Recipe> all = <Recipe>[
    _chickenBiryani,
    _chickenKarahi,
    _beefNihari,
    _haleem,
    _chapliKebab,
    _chanaDaal,
    _alooGosht,
    _seekhKabab,
    _chanaChaat,
    _kheer,
  ];
}
