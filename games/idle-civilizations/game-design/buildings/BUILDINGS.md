# Buildings — Master Index

All buildings across all eras. Each era's buildings are documented in detail in the era file.

## Quick Reference Table

| Era | ID | Name | Base Cost | Base Rate | Manager @ |
|-----|----|------|-----------|-----------|-----------|
| **Stone Age** | | | | | |
| | `campfire` | Campfire | 10 Gold | 0.1 Gold/s | 10 |
| | `hunting_ground` | Hunting Ground | 100 Gold | 0.5 Gold/s | 10 |
| | `berry_bush` | Berry Bush | 800 Gold | 4 Gold/s | 10 |
| | `cave_painting` | Cave Painting | 1,200 Gold | 10 Gold/s | 25 |
| | `flint_workshop` | Flint Workshop | 3,000 Gold | 40 Gold/s | 10 |
| **Bronze Age** | | | | | |
| | `grain_farm` | Grain Farm | 500 Gold | 5 Gold/s | 10 |
| | `bronze_mine` | Bronze Mine | 2,000 Gold | 0.1 Bronze/s | 10 |
| | `pottery_workshop` | Pottery Workshop | 5,000 Gold | 30 Gold/s | 10 |
| | `trading_post` | Trading Post | 20,000 Gold | 80 Gold/s | 10 |
| | `bronze_forge` | Bronze Forge | 80,000 Gold | 250 Gold/s | 25 |
| | `river_port` | River Port | 300,000 Gold | 600 Gold/s | 10 |
| **Classical Empire** | | | | | |
| | `forum` | Forum | 50,000 Gold | 500 Gold/s | 10 |
| | `aqueduct` | Aqueduct | 200,000 Gold | +10% all | 10 |
| | `temple` | Temple | 500,000 Gold | 50 Culture/s | 10 |
| | `colosseum` | Colosseum | 2,000,000 Gold | 200 Culture/s | 25 |
| | `senate` | Senate | 5,000,000 Gold | 3,000 Gold/s | 10 |
| | `trade_route` | Trade Route | 20,000,000 Gold | 8,000 Gold/s | 10 |
| | `roman_legion` | Roman Legion | 80,000,000 Gold | 25,000 Gold/s | 10 |
| **Medieval Kingdom** | | | | | |
| | `village` | Village | 500,000 Gold | 5,000 Gold/s | 10 |
| | `church` | Church | 2,000,000 Gold | 100 Faith/s | 10 |
| | `blacksmith` | Blacksmith | 8,000,000 Gold | 50 Iron/s | 10 |
| | `castle` | Castle | 30,000,000 Gold | 50,000 Gold/s | 25 |
| | `market_square` | Market Square | 100,000,000 Gold | 150,000 Gold/s | 10 |
| | `university` | University | 400,000,000 Gold | 200 Science/s | 10 |
| | `knight_order` | Knight Order | 1,500,000,000 Gold | 500,000 Gold/s | 25 |
| | `cathedral` | Cathedral | 5,000,000,000 Gold | 2,000,000 Gold/s | 50 |
| **Renaissance** | | | | | |
| | `printing_press` | Printing Press | 5,000,000,000 Gold | ×1.5 all | 10 |
| | `art_studio` | Art Studio | 20,000,000,000 Gold | 1,000 Art/s | 10 |
| | `library` | Library | 80,000,000,000 Gold | 500 Knowledge/s | 10 |
| | `observatory` | Observatory | 300,000,000,000 Gold | 2,000 Science/s | 25 |
| | `bank` | Bank | 1,000,000,000,000 Gold | 10,000,000 Gold/s | 10 |
| | `merchant_guild` | Merchant Guild | 4,000,000,000,000 Gold | 50,000,000 Gold/s | 10 |
| | `academy` | Academy | 15,000,000,000,000 Gold | 200,000,000 Gold/s | 25 |
| **Industrial Revolution** | | | | | |
| | `coal_mine` | Coal Mine | 50B Gold | 500 Coal/s | 10 |
| | `steam_engine` | Steam Engine | 200B Gold | ×2.0 (needs Coal) | 25 |
| | `railway_station` | Railway Station | 800B Gold | connects buildings | 10 |
| | `factory` | Factory | 3T Gold | 5B Gold/s | 10 |
| | `stock_exchange` | Stock Exchange | 12T Gold | 25B Gold/s | 10 |
| | `telegraph_office` | Telegraph Office | 50T Gold | 100B Gold/s | 10 |
| | `iron_bridge` | Iron Bridge | 200T Gold | 500B Gold/s | 25 |
| **Space Age** | | | | | |
| | `research_lab` | Research Lab | 500T Gold | 5,000 Science/s | 10 |
| | `nuclear_plant` | Nuclear Power Plant | 2Qa Gold | 10,000 Energy/s | 10 |
| | `satellite_network` | Satellite Network | 8Qa Gold | ×1.5 all | 25 |
| | `space_centre` | Space Centre | 30Qa Gold | 10T Gold/s | 10 |
| | `moon_base` | Moon Base | 120Qa Gold | +50% offline cap | 50 |
| | `mars_colony` | Mars Colony | 500Qa Gold | 100T Gold/s | 25 |
| | `ai_division` | AI Research Division | 2Qi Gold | ×2.0 all | 100 |

---

## Building Design Rules

### Cost Multiplier by Building Tier
| Tier | Cost Multiplier | Use case |
|------|----------------|---------|
| Standard | 1.15 | Most buildings (opener, mid-tier) |
| Rare | 1.12 | Mid-game buildings requiring resource dependencies |
| Mega | 1.08–1.10 | Late-era final buildings (steep but forgiving) |

### Production Rate Ratios (building N vs building N-1)
At count=1, each new building should produce approximately **5–8× more** than the previous building at count=1. This creates a clear "upgrade path" feel.

### Manager Thresholds
| Building role | Manager at |
|--------------|-----------|
| Opening building | 10 owned |
| Mid-tier building | 10 owned |
| Resource-special building | 25 owned (harder to idle) |
| Mega/final building | 25–50 owned |

### Building Description Template
Every building needs:
1. **Name** (2–3 words, historically evocative)
2. **Description** (one sentence, slightly humorous, historically grounded)
3. **Icon name** following `building_[id]` convention
4. **Era-appropriate visual** (described for artist — no fine detail at small sizes)
