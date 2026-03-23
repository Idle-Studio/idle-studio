import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { ALL_GAMES, getGameConfig } from '@/config/games'
import { generateGameMetadata } from '@/lib/metadata'
import { SiteHeader } from '@/components/layout/SiteHeader'
import { SiteFooter } from '@/components/layout/SiteFooter'
import { GameHero } from '@/components/game/GameHero'
import { StatsBar } from '@/components/game/StatsBar'
import { EraScroller } from '@/components/game/EraScroller'
import { FeaturesGrid } from '@/components/game/FeaturesGrid'
import { WonderShowcase } from '@/components/game/WonderShowcase'
import { LeaderCards } from '@/components/game/LeaderCards'
import { BuildingIconGrid } from '@/components/game/BuildingIconGrid'
import { DownloadCTA } from '@/components/game/DownloadCTA'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()
  return generateGameMetadata(game)
}

export default async function GamePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()

  return (
    <main style={{ backgroundColor: game.backgroundColor }}>
      <SiteHeader />
      <GameHero game={game} />
      <StatsBar game={game} />
      {game.eras.length > 0 && <EraScroller game={game} />}
      <FeaturesGrid game={game} />
      {game.wonders.length > 0 && <WonderShowcase game={game} />}
      {game.leaders.length > 0 && <LeaderCards game={game} />}
      {game.buildingShowcase.length > 0 && <BuildingIconGrid game={game} />}
      <DownloadCTA game={game} />
      <SiteFooter />
    </main>
  )
}
