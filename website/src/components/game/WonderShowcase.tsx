'use client'

import { useRef, useState } from 'react'
import { motion, useScroll, useTransform, AnimatePresence } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface WonderShowcaseProps {
  game: GameConfig
}

export function WonderShowcase({ game }: WonderShowcaseProps) {
  return (
    <section className="py-32 px-6 overflow-hidden">
      <div className="max-w-7xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.7 }}
          className="text-center mb-20"
        >
          <p className="text-sm uppercase tracking-[0.3em] mb-4 font-sans" style={{ color: game.accentColor }}>
            Build History
          </p>
          <h2 className="font-serif text-4xl md:text-5xl font-bold text-white">
            {game.stats.milestoneCount} World {game.vocab.milestonePlural}
          </h2>
        </motion.div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {game.wonders.map((wonder, i) => (
            <WonderCard key={wonder.id} wonder={wonder} game={game} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}

function WonderCard({
  wonder,
  game,
  index,
}: {
  wonder: GameConfig['wonders'][0]
  game: GameConfig
  index: number
}) {
  const [hovered, setHovered] = useState(false)
  const cardRef = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: cardRef,
    offset: ['start end', 'end start'],
  })
  const imgY = useTransform(scrollYProgress, [0, 1], ['-10%', '10%'])

  return (
    <motion.div
      ref={cardRef}
      initial={{ opacity: 0, scale: 0.92 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.6, delay: index * 0.07 }}
      onHoverStart={() => setHovered(true)}
      onHoverEnd={() => setHovered(false)}
      className="relative aspect-[4/3] rounded-2xl overflow-hidden cursor-pointer border border-white/10"
    >
      <motion.div style={{ y: imgY }} className="absolute inset-[-10%]">
        <Image
          src={assetPath(game.id, 'wonders', wonder.artworkAsset)}
          alt={wonder.displayName}
          fill
          className="object-cover"
        />
      </motion.div>
      <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />

      <div className="absolute bottom-3 left-3 right-3">
        <p className="text-white text-sm font-semibold font-serif leading-tight">{wonder.displayName}</p>
        <p className="text-white/50 text-xs font-sans">{wonder.era}</p>
      </div>

      <AnimatePresence>
        {hovered && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ duration: 0.3, ease: [0.21, 0.47, 0.32, 0.98] }}
            className="absolute inset-0 flex flex-col justify-end p-5"
            style={{
              background: `linear-gradient(to top, ${game.backgroundColor}F0 0%, ${game.accentColor}40 100%)`,
            }}
          >
            <p className="text-white font-serif text-base font-bold mb-1">{wonder.displayName}</p>
            <p className="text-white/70 text-xs font-sans mb-2">{wonder.era}</p>
            <p className="font-semibold text-sm font-sans" style={{ color: game.accentColor }}>
              {wonder.bonus}
            </p>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  )
}
