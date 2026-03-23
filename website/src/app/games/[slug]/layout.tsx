import { ALL_GAMES } from '@/config/games'
import { notFound } from 'next/navigation'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export default function GameLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: { slug: string }
}) {
  const game = ALL_GAMES.find(g => g.id === params.slug)
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
