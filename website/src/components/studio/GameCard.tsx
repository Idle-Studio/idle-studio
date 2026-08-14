'use client'

import { motion } from 'framer-motion'
import Image from 'next/image'
import Link from 'next/link'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface GameCardProps {
  game: GameConfig
  index: number
}

export function GameCard({ game, index }: GameCardProps) {
  const isLive = game.status === 'live'
  const heroSrc = assetPath(game.id, 'eras', game.heroArtworkAsset)
  const iconSrc = assetPath(game.id, 'root', game.appIconAsset)

  return (
    <motion.div
      initial={{ opacity: 0, y: 50 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.7, delay: index * 0.15, ease: [0.21, 0.47, 0.32, 0.98] }}
      whileHover={{ y: -8 }}
      className={`group relative rounded-3xl overflow-hidden border border-white/10 ${!isLive ? 'opacity-60 grayscale' : ''}`}
    >
      <div className="relative h-72 overflow-hidden">
        <motion.div
          whileHover={{ scale: 1.05 }}
          transition={{ duration: 0.6, ease: 'easeOut' }}
          className="w-full h-full"
        >
          {isLive ? (
            <Image
              src={heroSrc}
              alt={game.displayName}
              fill
              sizes="(max-width: 768px) 100vw, (max-width: 1280px) 50vw, 624px"
              className="object-cover"
            />
          ) : (
            <div
              className="w-full h-full flex items-center justify-center"
              style={{ background: `linear-gradient(135deg, ${game.accentColor}20, ${game.backgroundColor})` }}
            >
              <span className="text-7xl opacity-30">🎮</span>
            </div>
          )}
        </motion.div>
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
      </div>

      <div className="p-6 bg-white/[0.03]">
        <div className="flex items-center gap-4 mb-4">
          {isLive && (
            <div className="relative w-12 h-12 rounded-2xl overflow-hidden flex-shrink-0 shadow-lg">
              <Image src={iconSrc} alt={`${game.displayName} icon`} fill sizes="48px" className="object-cover" />
            </div>
          )}
          <div>
            <div className="flex items-center gap-2 mb-1">
              <h3 className="font-serif text-xl font-bold text-white">{game.displayName}</h3>
              {game.status === 'coming-soon' && (
                <span className="text-xs bg-white/10 text-white/50 px-2 py-0.5 rounded-full font-sans">Soon</span>
              )}
            </div>
            <p className="text-white/50 text-sm font-sans">{game.tagline}</p>
          </div>
        </div>

        {isLive && (
          <Link
            href={`/games/${game.id}`}
            className="inline-flex items-center gap-2 text-sm font-medium font-sans mt-2 transition-colors"
            style={{ color: game.accentColor }}
          >
            View Game
            <svg className="w-4 h-4 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        )}
      </div>
    </motion.div>
  )
}
