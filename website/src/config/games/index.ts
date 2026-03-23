import type { GameConfig } from '../types'
import { idleCivilizationsConfig } from './idle-civilizations'
import { idleRestaurantEmpireConfig } from './idle-restaurant-empire'

export const ALL_GAMES: GameConfig[] = [
  idleCivilizationsConfig,
  idleRestaurantEmpireConfig,
]

export function getGameConfig(slug: string): GameConfig | undefined {
  return ALL_GAMES.find(g => g.id === slug)
}
