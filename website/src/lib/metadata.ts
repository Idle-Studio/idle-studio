import type { Metadata } from 'next'
import type { GameConfig } from '@/config/types'

const BASE_URL = 'https://idle-studio.vercel.app'

/** Studio-wide 1.91:1 share card — also the fallback for games with no artwork yet. */
const STUDIO_OG_IMAGE = {
  url: `${BASE_URL}/og-image.jpg`,
  width: 1200,
  height: 630,
  alt: 'Idle Studio',
}

/**
 * Share artwork only ships alongside a released game, so unreleased titles fall
 * back to the studio card rather than pointing scrapers at a 404.
 */
function ogImage(game: GameConfig) {
  if (game.status !== 'live') return STUDIO_OG_IMAGE
  return {
    url: `${BASE_URL}/assets/${game.id}/og-card.jpg`,
    width: 1200,
    height: 630,
    alt: game.displayName,
  }
}

/** Trim to a whole word so meta descriptions never break mid-word. */
function truncate(text: string, max: number) {
  if (text.length <= max) return text
  const clipped = text.slice(0, max - 1)
  const lastSpace = clipped.lastIndexOf(' ')
  const body = lastSpace > 0 ? clipped.slice(0, lastSpace) : clipped
  return `${body.replace(/[\s.,;:—–-]+$/, '')}…`
}

export function generateGameMetadata(game: GameConfig): Metadata {
  const isLive = game.status === 'live'
  const url = `${BASE_URL}/games/${game.id}/`

  return {
    title: `${game.displayName} — Idle Studio`,
    description: truncate(game.description, 160),
    alternates: {
      canonical: url,
    },
    robots: isLive
      ? { index: true, follow: true }
      : { index: false, follow: false },
    openGraph: {
      title: game.displayName,
      description: game.tagline,
      url,
      siteName: 'Idle Studio',
      type: 'website',
      images: [ogImage(game)],
    },
    twitter: {
      card: 'summary_large_image',
      title: game.displayName,
      description: game.tagline,
      images: [ogImage(game).url],
    },
  }
}

export function generateSupportMetadata(game: GameConfig): Metadata {
  const url = `${BASE_URL}/games/${game.id}/support/`
  return {
    title: `Support — ${game.displayName}`,
    description: `Get help with ${game.displayName}. Browse FAQs or contact the Idle Studio support team.`,
    alternates: { canonical: url },
    robots: { index: true, follow: true },
    openGraph: {
      title: `Support — ${game.displayName}`,
      description: `Get help with ${game.displayName}.`,
      url,
      siteName: 'Idle Studio',
      type: 'website',
      images: [ogImage(game)],
    },
  }
}

export function generateTermsMetadata(game: GameConfig): Metadata {
  const url = `${BASE_URL}/games/${game.id}/terms/`
  return {
    title: `Terms of Use — ${game.displayName}`,
    description: `Terms of use for ${game.displayName} by Idle Studio.`,
    alternates: { canonical: url },
    robots: { index: true, follow: true },
    openGraph: {
      title: `Terms of Use — ${game.displayName}`,
      description: `Terms of use for ${game.displayName} by Idle Studio.`,
      url,
      siteName: 'Idle Studio',
      type: 'website',
    },
  }
}

export function generatePrivacyMetadata(game: GameConfig): Metadata {
  const url = `${BASE_URL}/games/${game.id}/privacy/`
  return {
    title: `Privacy Policy — ${game.displayName}`,
    description: `Privacy policy for ${game.displayName} by Idle Studio. Learn how we handle your data.`,
    alternates: { canonical: url },
    robots: { index: true, follow: true },
    openGraph: {
      title: `Privacy Policy — ${game.displayName}`,
      description: `Privacy policy for ${game.displayName} by Idle Studio.`,
      url,
      siteName: 'Idle Studio',
      type: 'website',
    },
  }
}

// ─── JSON-LD helpers ──────────────────────────────────────────────────────────

export function gameJsonLd(game: GameConfig) {
  return {
    '@context': 'https://schema.org',
    '@type': 'VideoGame',
    name: game.displayName,
    description: game.description,
    url: `${BASE_URL}/games/${game.id}/`,
    image: ogImage(game).url,
    applicationCategory: 'Game',
    operatingSystem: 'iOS',
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'USD',
      availability: 'https://schema.org/InStock',
    },
    ...(game.appStoreUrl && {
      installUrl: game.appStoreUrl,
      downloadUrl: game.appStoreUrl,
    }),
    publisher: {
      '@type': 'Organization',
      name: 'Idle Studio',
      url: BASE_URL,
    },
  }
}

export function breadcrumbJsonLd(crumbs: { name: string; url: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((crumb, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  }
}

export function organizationJsonLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'Idle Studio',
    url: BASE_URL,
    logo: `${BASE_URL}/icon.png`,
    email: 'vmihai12@icloud.com',
    sameAs: [],
  }
}
