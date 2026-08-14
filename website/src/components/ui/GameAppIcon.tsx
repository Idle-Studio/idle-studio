import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface GameAppIconProps {
  game: GameConfig
}

/**
 * The 40px app icon used in the privacy / terms / support page headers.
 * Icon artwork only ships with a released game, so unreleased themes get the
 * same emoji placeholder the studio game cards use instead of a broken image.
 */
export function GameAppIcon({ game }: GameAppIconProps) {
  if (game.status !== 'live') {
    return (
      <div
        className="relative w-10 h-10 rounded-xl overflow-hidden flex items-center justify-center"
        style={{ background: `linear-gradient(135deg, ${game.accentColor}20, ${game.backgroundColor})` }}
      >
        <span className="text-lg opacity-40">🎮</span>
      </div>
    )
  }

  return (
    <div className="relative w-10 h-10 rounded-xl overflow-hidden">
      <Image
        src={assetPath(game.id, 'root', game.appIconAsset)}
        alt={game.displayName}
        fill
        sizes="40px"
        className="object-cover"
      />
    </div>
  )
}
