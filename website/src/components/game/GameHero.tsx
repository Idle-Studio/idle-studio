'use client'

import { useRef } from 'react'
import { motion, useScroll, useTransform, useMotionValue, useReducedMotion } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'
import { AppStoreButton } from '@/components/ui/AppStoreButton'

interface GameHeroProps {
  game: GameConfig
}

export function GameHero({ game }: GameHeroProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const { scrollY } = useScroll()
  const heroY = useTransform(scrollY, [0, 600], [0, 150])
  const heroOpacity = useTransform(scrollY, [0, 400], [1, 0])
  const mouseX = useMotionValue(0)
  const imgShiftX = useTransform(mouseX, [-1, 1], [-15, 15])
  const prefersReducedMotion = useReducedMotion()

  // Artwork only exists for shipped games — unreleased themes get a placeholder.
  const isLive = game.status === 'live'
  const heroSrc = assetPath(game.id, 'eras', game.heroArtworkAsset)
  const iconSrc = assetPath(game.id, 'root', game.appIconAsset)
  const taglineWords = game.tagline.split(' ')

  function handleMouseMove(e: React.MouseEvent) {
    if (prefersReducedMotion) return
    const rect = containerRef.current?.getBoundingClientRect()
    if (!rect) return
    const x = ((e.clientX - rect.left) / rect.width) * 2 - 1
    mouseX.set(x)
  }

  return (
    <section
      ref={containerRef}
      onMouseMove={handleMouseMove}
      className="relative min-h-screen flex items-center justify-center overflow-hidden"
    >
      <motion.div
        style={{ y: heroY, x: imgShiftX }}
        className="absolute inset-[-10%] z-0"
      >
        {isLive ? (
          <Image src={heroSrc} alt={game.displayName} fill sizes="100vw" className="object-cover" priority />
        ) : (
          <div
            className="w-full h-full"
            style={{ background: `linear-gradient(135deg, ${game.accentColor}20, ${game.backgroundColor})` }}
          />
        )}
      </motion.div>

      <div
        className="absolute inset-0 z-10"
        style={{ background: `linear-gradient(to bottom, ${game.backgroundColor}80 0%, transparent 30%, transparent 60%, ${game.backgroundColor} 100%)` }}
      />
      <div
        className="absolute inset-0 z-10"
        style={{ background: `radial-gradient(ellipse 70% 80% at 50% 50%, transparent 0%, ${game.backgroundColor}90 100%)` }}
      />

      <motion.div style={{ opacity: heroOpacity }} className="relative z-20 text-center px-6 max-w-4xl mx-auto pt-24">
        <div className="mb-8 flex justify-center">
          <div className="relative w-24 h-24 rounded-[22px] overflow-hidden shadow-2xl border border-white/20">
            {isLive ? (
              <Image src={iconSrc} alt={`${game.displayName} icon`} fill sizes="96px" className="object-cover" />
            ) : (
              <div
                className="w-full h-full flex items-center justify-center"
                style={{ background: `linear-gradient(135deg, ${game.accentColor}20, ${game.backgroundColor})` }}
              >
                <span className="text-4xl opacity-30">🎮</span>
              </div>
            )}
          </div>
        </div>

        <p
          className="text-sm uppercase tracking-[0.3em] mb-5 font-sans"
          style={{ color: game.accentColor }}
        >
          {game.subtitle}
        </p>

        <h1 className="font-serif text-5xl md:text-7xl lg:text-8xl font-bold text-white leading-tight mb-6">
          {game.displayName}
        </h1>

        <div className="font-sans text-white/70 text-xl md:text-2xl mb-10 overflow-hidden">
          {taglineWords.map((word, i) => (
            <span key={i} className="inline-block mr-[0.3em]">
              {word}
            </span>
          ))}
        </div>

        <div>
          {isLive ? (
            <AppStoreButton url={game.appStoreUrl} size="lg" />
          ) : (
            <div className="inline-flex items-center gap-3 bg-white/10 text-white/60 font-semibold rounded-2xl px-10 py-5 text-lg font-sans">
              Coming Soon
            </div>
          )}
        </div>
      </motion.div>
    </section>
  )
}
