import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { ALL_GAMES, getGameConfig } from '@/config/games'
import { generateSupportMetadata } from '@/lib/metadata'
import { SupportPageClient } from './SupportPageClient'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()
  return generateSupportMetadata(game)
}

export default async function SupportPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()
  return <SupportPageClient game={game} />
}
