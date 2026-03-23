import { ALL_GAMES } from '@/config/games'
import { notFound } from 'next/navigation'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export default async function GameLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
  const game = ALL_GAMES.find(g => g.id === slug)
  if (!game) notFound()

  return (
    <div
      style={{
        '--accent': game.accentColor,
        '--game-bg': game.backgroundColor,
      } as React.CSSProperties}
    >
      {children}
    </div>
  )
}
