import type { MetadataRoute } from 'next'
import { ALL_GAMES } from '@/config/games'

const BASE_URL = 'https://idle-studio.vercel.app'

export default function sitemap(): MetadataRoute.Sitemap {
  const liveGames = ALL_GAMES.filter(g => g.status === 'live')

  const gameRoutes: MetadataRoute.Sitemap = liveGames.flatMap(game => [
    {
      url: `${BASE_URL}/games/${game.id}/`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${BASE_URL}/games/${game.id}/support/`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.6,
    },
    {
      url: `${BASE_URL}/games/${game.id}/privacy/`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
    {
      url: `${BASE_URL}/games/${game.id}/terms/`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
  ])

  return [
    {
      url: `${BASE_URL}/`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 1.0,
    },
    ...gameRoutes,
  ]
}
