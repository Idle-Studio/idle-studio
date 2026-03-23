import type { Metadata } from 'next'
import type { GameConfig } from '@/config/types'

const BASE_URL = 'https://idlestudio.io'

export function generateGameMetadata(game: GameConfig): Metadata {
  return {
    title: `${game.displayName} — Idle Studio`,
    description: game.description.slice(0, 160),
    openGraph: {
      title: game.displayName,
      description: game.tagline,
      url: `${BASE_URL}/games/${game.id}`,
      siteName: 'Idle Studio',
      type: 'website',
    },
    twitter: {
      card: 'summary_large_image',
      title: game.displayName,
      description: game.tagline,
    },
  }
}

export function generateSupportMetadata(game: GameConfig): Metadata {
  return {
    title: `Support — ${game.displayName}`,
    description: `Get help with ${game.displayName}. FAQ, contact info, and more.`,
  }
}

export function generatePrivacyMetadata(game: GameConfig): Metadata {
  return {
    title: `Privacy Policy — ${game.displayName}`,
    description: `Privacy policy for ${game.displayName} by Idle Studio.`,
  }
}
