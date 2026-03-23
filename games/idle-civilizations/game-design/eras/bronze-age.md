# Bronze Age

**ID:** `bronze_age`  
**Order:** 2  
**Primary color:** `#CD7F32`  
**Secondary color:** `#8B4513`  
**Advance requirement:** 50,000 Gold  
**Era resources:** Bronze, Food  
**Unlocked after:** Stone Age advance

> *"From stone to metal — humanity begins to build empires."*

## Historical Context
3,000–1,200 BCE. The discovery of bronze revolutionises tools and warfare. City-states emerge in Mesopotamia, Egypt rises along the Nile, and long-distance trade begins to connect civilisations.

## Buildings

| # | ID | Name | Base Cost | Cost Mult | Base Rate | Manager @ |
|---|-----|------|-----------|-----------|-----------|-----------|
| 1 | `grain_farm` | Grain Farm | 500 Gold | 1.15 | 5 Gold/s | 10 owned |
| 2 | `bronze_mine` | Bronze Mine | 2,000 Gold | 1.15 | 0 Gold + 0.1 Bronze/s | 10 owned |
| 3 | `pottery_workshop` | Pottery Workshop | 5,000 Gold | 1.14 | 30 Gold/s | 10 owned |
| 4 | `trading_post` | Trading Post | 20,000 Gold | 1.13 | 80 Gold/s | 10 owned |
| 5 | `bronze_forge` | Bronze Forge | 80,000 Gold | 1.12 | 0.5 Bronze → 250 Gold/s | 25 owned |
| 6 | `river_port` | River Port | 300,000 Gold | 1.11 | 600 Gold/s | 10 owned |

### Building Notes
- **Grain Farm:** Standard opener. Produces Food as secondary (1 Food per 10 owned).
- **Bronze Mine:** Produces Bronze (not Gold directly). Bronze is needed for the Pyramid Wonder and boosts Bronze Forge.
- **Pottery Workshop:** Pure Gold production. Staple mid-era building.
- **Trading Post:** Benefits from Food and Bronze bonuses — produces more when both are high. `goldRate × (1 + food/1000 + bronze/500)`.
- **Bronze Forge:** Converts Bronze into Gold at a favourable rate. Requires Bronze Mine investment.
- **River Port:** Late-era mega-producer. Produces massive Gold, requires 50 Bronze in stock to unlock.

## Wonders

### Pyramid of Giza
**ID:** `pyramid_of_giza`  
**Requirement:** 10,000 Gold + 500 Bronze  
**Construction time:** 2 hours  
**Skip cost:** 200 Premium Coins  
**Bonus:** +100% Gold production + +30% all resources (Bronze Age scope)  
**Flavor:** *"A monument to ambition. And a lot of sand."*

## Leaders Available

### Ramesses the Builder
**ID:** `leader_ramesses`  
**Bonus:** +15% Wonder construction speed, +10% River Port production  
**Unlock:** Complete the Bronze Age  
**Quote:** *"Every stone placed is a prayer to eternity."*

## Progression Notes

### Expected Session Pattern
- **Session 1:** Collect Stone Age prestige bonus → discover era reset → buy Grain Farms aggressively
- **Session 2–3:** Bronze Mine investment, accumulate Bronze toward Pyramid
- **Session 4–5:** Pottery Workshop rush, Trading Post unlocked
- **Session 6–8:** Bronze Forge starts multiplying income
- **Session 9–10:** River Port unlocked, advance requirement reachable
- **Session 11–12:** Hit 50,000 Gold → advance

### Balance Targets
- Time to first manager (Grain Farm): ~4–6 minutes
- Time to advance era: ~10–12 sessions
- Offline income at comfortable stage: ~5,000 Gold/s

### Key Tension Point
Bronze management is the core Bronze Age tension: Bronze Mine produces Bronze but no Gold. Players must decide how much production to allocate to Bronze (for Wonder + Forge bonuses) vs. Gold buildings. This is the first resource management decision of the game.

## JSON Block

```json
{
  "id": "bronze_age",
  "name": "Bronze Age",
  "order": 2,
  "flavorText": "From stone to metal — humanity begins to build empires.",
  "primaryColor": "#CD7F32",
  "secondaryColor": "#8B4513",
  "advanceRequirement": { "gold": 50000 },
  "eraResources": ["bronze", "food"],
  "buildingIDs": ["grain_farm", "bronze_mine", "pottery_workshop", "trading_post", "bronze_forge", "river_port"],
  "wonderIDs": ["pyramid_of_giza"],
  "leaderIDs": ["leader_ramesses"]
}
```
