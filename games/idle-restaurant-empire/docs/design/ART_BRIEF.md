# Idle Restaurant Empire — Art Brief

All assets must be delivered before TestFlight submission. Assets marked **[BLOCKING]** must arrive before the first internal build. Others can ship in a follow-up update.

---

## Style Guide

- **Mood:** Warm, vibrant, food-forward. Think illustrated food editorial — not cartoon, not hyper-realistic.
- **Palette base:** Deep burgundy backgrounds, amber/gold highlights, cream text areas. Level-specific palettes in the JSON.
- **Reference:** Level scene art should feel like a high-quality mobile idle game (e.g. Adventure Capitalist, Egg, Inc.) — clean, readable at small sizes, rich in detail at full size.
- **Consistency:** All unit icons must share the same visual language — same stroke weight, same lighting direction, same level of detail.

---

## App Icon [BLOCKING]

| File | Size | Notes |
|------|------|-------|
| `AppIcon.png` | 1024×1024px | No alpha, no rounded corners (iOS adds them). Bold, food-themed. A chef's hat, a Michelin star, or a fork/knife motif. Must read at 60×60px. |

---

## Level Scene Artworks [BLOCKING] — 8 images

Illustrated full-bleed scenes. Used as backgrounds behind the gameplay UI. Slightly desaturated in the center where the UI sits, rich at the edges.

**Size:** 1920×1080px (PNG or WebP, < 1MB each after compression)

| Asset Name | Scene Description | Level Colors |
|------------|------------------|-------------|
| `level_street_food.png` | Vibrant evening street market — food carts, neon signs, crowds, warm orange light | Primary: #D4622A |
| `level_french_bistro.png` | Cozy Parisian bistro interior — red leather banquettes, candlelight, wine glasses, jazz posters | Primary: #8B1A3A |
| `level_italian_trattoria.png` | Rustic Tuscan courtyard — wood-fired oven glowing, terracotta pots, olive trees, evening sun | Primary: #2E7D32 |
| `level_dim_sum_palace.png` | Grand Cantonese restaurant — red lanterns, bamboo steamers, trolleys in motion, gilded pillars | Primary: #C62828 |
| `level_sushi_bar.png` | Minimalist Japanese sushi counter — dark wood bar, blue indirect lighting, chef in white, calm | Primary: #1565C0 |
| `level_fusion_kitchen.png` | Modern open kitchen — dramatic plating under spotlights, smoke, tweezers, organised chaos | Primary: #6A1B9A |
| `level_michelin_fine_dining.png` | Elegant dining room — white tablecloths, candlelight, silver service, lone Michelin star plaque | Primary: #37474F |
| `level_global_empire.png` | Epic aerial view — a golden world map with restaurant pins across six continents, warm glow | Primary: #B8860B |

---

## Unit Icons [BLOCKING] — 43 icons

**Size:** 192×192px PNG (retina @3x for 64pt display) or SVG
**Style:** Semi-flat icon, consistent stroke weight (~3px), light source from top-left, subtle drop shadow

### Level 1 — Street Food Cart (terracotta/orange palette)
| Asset Name | Icon |
|------------|------|
| `unit_street_food_cart.png` | A small wheeled food cart with a striped awning |
| `unit_street_food_taco.png` | Two tacos on a wooden board |
| `unit_street_food_noodles.png` | A bowl of ramen/noodles with chopsticks |
| `unit_street_food_dumplings.png` | Bamboo steamer basket with dumplings visible |
| `unit_street_food_waffle.png` | A waffle truck (food truck shape) with waffle iron |

### Level 2 — French Bistro (burgundy/wine palette)
| Asset Name | Icon |
|------------|------|
| `unit_bistro_bread.png` | A wicker bread basket with baguette |
| `unit_bistro_escargot.png` | Escargot dish — 6 snails in a ceramic plate with tongs |
| `unit_bistro_wine.png` | Wine cellar rack with bottles |
| `unit_bistro_kitchen.png` | French kitchen pass — copper pans hanging, white-hat chef |
| `unit_bistro_brasserie.png` | A brasserie hall — arched ceiling, rows of banquettes |

### Level 3 — Italian Trattoria (basil green palette)
| Asset Name | Icon |
|------------|------|
| `unit_trattoria_pasta.png` | Bronze pasta extruder with fresh spaghetti |
| `unit_trattoria_pizza.png` | Wood-fired pizza oven with flames visible |
| `unit_trattoria_olive.png` | Olive press — stone wheel, olive branch, oil flowing |
| `unit_trattoria_cured_meat.png` | Hanging prosciutto legs in a dark cured meat room |
| `unit_trattoria_terrace.png` | Cobblestone terrace with candles and potted plants |

### Level 4 — Dim Sum Palace (celebration red palette)
| Asset Name | Icon |
|------------|------|
| `unit_dimsum_steamer.png` | Stack of three bamboo steamer baskets, steam rising |
| `unit_dimsum_trolley.png` | Classic dim sum trolley cart, top view with dishes |
| `unit_dimsum_tea.png` | Teapot with steam and a teacup beside it |
| `unit_dimsum_duck.png` | Hanging lacquered roast duck |
| `unit_dimsum_banquet.png` | Round banquet table with lazy susan, top-down view |
| `unit_dimsum_imperial.png` | Imperial kitchen archway — tiled, ornate, with wok flames |

### Level 5 — Sushi Bar (ocean blue palette)
| Asset Name | Icon |
|------------|------|
| `unit_sushi_rice.png` | Electric rice cooker, glossy, steam vent open |
| `unit_sushi_nigiri.png` | Two pieces of salmon nigiri on a wooden board |
| `unit_sushi_tsukiji.png` | Tuna fillet block on ice with a price tag |
| `unit_sushi_knife.png` | Yanagiba (long sushi knife) on a magnetic strip |
| `unit_sushi_omakase.png` | Omakase counter — 12 seats, intimate, lit from above |
| `unit_sushi_sake.png` | Sake carafe (tokkuri) and small cup (ochoko) |

### Level 6 — Fusion Kitchen (violet/purple palette)
| Asset Name | Icon |
|------------|------|
| `unit_fusion_spice.png` | Lab-style spice rack with labelled glass jars |
| `unit_fusion_ferment.png` | Fermentation crocks and jars in a cellar setting |
| `unit_fusion_molecular.png` | Molecular gastronomy kit — syringe, agar, liquid nitrogen wisps |
| `unit_fusion_pantry.png` | Globe surrounded by ingredient icons (a world pantry) |
| `unit_fusion_popup.png` | Pop-up tent/stall in a modern urban setting |
| `unit_fusion_tasting.png` | Tasting menu booklet with 18 courses listed, elegant |

### Level 7 — Michelin Fine Dining (charcoal slate palette)
| Asset Name | Icon |
|------------|------|
| `unit_finedining_tablecloth.png` | White linen napkin fold on a set table, silver cutlery |
| `unit_finedining_amuse.png` | Amuse-bouche on a ceramic spoon — single perfect bite |
| `unit_finedining_cheese.png` | Artisan cheese cave — stone walls, wheels of cheese aging |
| `unit_finedining_sommelier.png` | Sommelier with tastevin, decanting a bottle |
| `unit_finedining_kitchen.png` | Three-star brigade kitchen — stainless steel, precision plating |
| `unit_finedining_private.png` | Private dining room — single table, fireplace, velvet curtains |

### Level 8 — Global Empire (antique gold palette)
| Asset Name | Icon |
|------------|------|
| `unit_empire_flagship.png` | Grand restaurant exterior — arch entrance, red carpet |
| `unit_empire_hotel.png` | Luxury hotel tower with a fork & knife silhouette overlay |
| `unit_empire_academy.png` | Culinary school building with chef's hat flag |
| `unit_empire_tv.png` | TV studio camera focused on a cooking station |
| `unit_empire_airline.png` | Aeroplane with a chef's hat in the window, tray of food |
| `unit_empire_hq.png` | World headquarters — glass tower with a fork/knife spire |

---

## Milestone Artworks — 16 images

**Size:** 512×512px PNG
**Style:** Celebratory, badge-like composition. Think award plaque meets food illustration. Each should feel like an achievement worth displaying.

| Asset Name | Scene |
|------------|-------|
| `milestone_street_food_yelp_favorite.png` | Phone screen showing 4.5 stars with a glowing food cart behind |
| `milestone_street_food_local_legend.png` | Neighbourhood map pinned with a glowing star over a food cart |
| `milestone_bistro_bib_gourmand.png` | Michelin Bib Gourmand figure (cheerful tire man) with wine glass |
| `milestone_bistro_first_star.png` | Single gold Michelin star on a dark velvet background |
| `milestone_trattoria_dop.png` | DOP certification seal with olive branch and Italian flag colours |
| `milestone_trattoria_slow_food.png` | Slow Food snail symbol with Tuscan countryside backdrop |
| `milestone_dimsum_yum_cha.png` | Multigenerational family around a round table, joyful morning scene |
| `milestone_dimsum_imperial_court.png` | Imperial Chinese court scroll unrolling to reveal the dish |
| `milestone_sushi_freshness.png` | Certificate scroll with a perfect tuna fillet illustration |
| `milestone_sushi_omakase.png` | 12-seat omakase counter aerial view, all seats occupied |
| `milestone_fusion_innovation.png` | Trophy shaped like a molecular gastronomy sphere |
| `milestone_fusion_50_best.png` | Gold plaque reading "World's 50 Best" with a number badge |
| `milestone_finedining_second_star.png` | Two gold Michelin stars side by side, glowing |
| `milestone_finedining_third_star.png` | Three gold Michelin stars in a triangle, radiant glow |
| `milestone_empire_brand.png` | World map with a branded hat/logo item overlaid |
| `milestone_empire_world_heritage.png` | UNESCO-style plaque with a globe and fork/knife, gold on stone |

---

## Head Chef Portraits — 10 images

**Size:** 256×256px PNG
**Style:** Character card art — bust portrait, warm personality-forward expression, food-relevant background element. Each chef should look distinct and memorable.

| Asset Name | Character | Visual Notes |
|------------|-----------|-------------|
| `char_marco_fuoco.png` | Marco Fuoco | Scruffy, energetic, apron over street clothes, street food cart blurred behind |
| `char_colette_dubois.png` | Colette Dubois | Classically elegant, sharp eyes, red neckerchief, bistro behind |
| `char_nonna_giulia.png` | Nonna Giulia | Silver hair, warm smile, flour-dusted hands, rustic kitchen behind |
| `char_liang_wei.png` | Chef Liang Wei | Dignified, white chef's jacket, dim sum palace behind |
| `char_kenji_tanaka.png` | Kenji Tanaka | Focused, minimalist white uniform, sushi bar behind |
| `char_priya_nair.png` | Priya Nair | Bright eyes, clipboard, fish market behind |
| `char_diego_flores.png` | Diego Flores | Creative, colourful apron, fusion kitchen behind with smoke |
| `char_amara_okafor.png` | Amara Okafor | Confident, vibrant, global map on wall behind her |
| `char_henri_lacombe.png` | Henri Lacombe | Severe, immaculate whites, Michelin dining room behind |
| `char_sofia_reyes_kwan.png` | Sofia Reyes-Kwan | Powerful, media-ready, world map with restaurant pins behind |

---

## Ambient Audio — 8 tracks

**Format:** MP3, stereo, 128kbps minimum, 2–4 minute seamless loop
**Volume:** Mastered for background (quiet, non-distracting at default volume)

| Asset Name | Mood & Style |
|------------|-------------|
| `ambient_street_food.mp3` | Upbeat street atmosphere — distant crowds, light percussion, street music |
| `ambient_french_bistro.mp3` | Jazz accordion, gentle café murmur, light piano |
| `ambient_italian_trattoria.mp3` | Italian folk guitar, outdoor ambience, soft clinking |
| `ambient_dim_sum_palace.mp3` | Guzheng (Chinese zither), subtle restaurant bustle, gentle chime |
| `ambient_sushi_bar.mp3` | Minimal koto, water sounds, calm and precise |
| `ambient_fusion_kitchen.mp3` | Modern electronic with organic textures, subtle sizzle |
| `ambient_michelin_fine_dining.mp3` | Solo piano, very quiet, elegant and spacious |
| `ambient_global_empire.mp3` | Orchestral swell, grand, cinematic, victorious |

---

## App Store Screenshots — after app builds

Generated via `studio screenshots --game idle-restaurant-empire` once the app runs on simulator.

**Required:** iPhone 6.7" (1290×2796px) — 6 screenshots
**Recommended:** iPad Pro 12.9" (2048×2732px) — 6 screenshots

Screenshot order and content:
1. Hero shot — level 5 (Sushi Bar) gameplay, full production running
2. Cuisine Era select — showing all 8 era cards
3. Michelin Star earn moment — construction timer completing
4. Head Chef collection — chef card grid
5. Prestige screen — Legacy Tokens and multiplier display
6. Event leaderboard — World Restaurant Awards
