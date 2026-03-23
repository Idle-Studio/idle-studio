import Link from 'next/link'
import { studioConfig } from '@/config/studio'
import { ALL_GAMES } from '@/config/games'

export function SiteFooter() {
  const liveGames = ALL_GAMES.filter(g => g.status === 'live')

  return (
    <footer className="border-t border-white/10 bg-black/40 py-16 px-6">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 mb-12">
          <div>
            <h3 className="font-serif text-lg font-bold text-white mb-3">{studioConfig.name}</h3>
            <p className="text-white/50 text-sm leading-relaxed">{studioConfig.tagline}</p>
          </div>
          <div>
            <h4 className="text-white/80 text-xs uppercase tracking-widest mb-4">Games</h4>
            <ul className="space-y-2">
              {liveGames.map(game => (
                <li key={game.id}>
                  <Link href={`/games/${game.id}`} className="text-white/50 hover:text-white text-sm transition-colors">
                    {game.displayName}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h4 className="text-white/80 text-xs uppercase tracking-widest mb-4">Support</h4>
            <ul className="space-y-2">
              {liveGames.map(game => (
                <li key={game.id}>
                  <Link href={`/games/${game.id}/support`} className="text-white/50 hover:text-white text-sm transition-colors">
                    {game.displayName} Support
                  </Link>
                </li>
              ))}
              <li>
                <a href={`mailto:${studioConfig.email}`} className="text-white/50 hover:text-white text-sm transition-colors">
                  {studioConfig.email}
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="border-t border-white/10 pt-8 flex flex-col md:flex-row justify-between items-center gap-4 text-white/30 text-xs">
          <p>© {new Date().getFullYear()} Idle Studio. All rights reserved.</p>
          <div className="flex gap-6">
            {liveGames.map(game => (
              <Link key={game.id} href={`/games/${game.id}/privacy`} className="hover:text-white/60 transition-colors">
                {game.displayName} Privacy
              </Link>
            ))}
          </div>
        </div>
      </div>
    </footer>
  )
}
