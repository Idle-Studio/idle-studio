import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { ALL_GAMES, getGameConfig } from '@/config/games'
import { generateSupportMetadata } from '@/lib/metadata'
import { SupportPageClient } from './SupportPageClient'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const game = getGameConfig(params.slug)
  if (!game) notFound()
  return generateSupportMetadata(game)
}

export default function SupportPage({ params }: { params: { slug: string } }) {
  const game = getGameConfig(params.slug)
  if (!game) notFound()
  return <SupportPageClient game={game} />
}
