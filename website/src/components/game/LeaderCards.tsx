'use client'

import { useRef, useState } from 'react'
import { motion } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface LeaderCardsProps {
  game: GameConfig
}

export function LeaderCards({ game }: LeaderCardsProps) {
  const constraintsRef = useRef<HTMLDivElement>(null)

  return (
    <section className="py-32 overflow-hidden">
      <div className="px-6 max-w-7xl mx-auto mb-20">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.7 }}
          className="text-center"
        >
          <p className="text-sm uppercase tracking-[0.3em] mb-4 font-sans" style={{ color: game.accentColor }}>
            Unlock Them All
          </p>
          <h2 className="font-serif text-4xl md:text-5xl font-bold text-white">
            {game.stats.leaderCount} Legendary {game.vocab.characterPlural}
          </h2>
        </motion.div>
      </div>

      <div ref={constraintsRef} className="overflow-hidden px-6">
        <motion.div
          drag="x"
          dragConstraints={constraintsRef}
          dragElastic={0.1}
          className="flex gap-6 cursor-grab active:cursor-grabbing"
          style={{ width: 'max-content' }}
        >
          {game.leaders.map((leader, i) => (
            <LeaderCard key={leader.id} leader={leader} game={game} index={i} />
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function LeaderCard({
  leader,
  game,
  index,
}: {
  leader: GameConfig['leaders'][0]
  game: GameConfig
  index: number
}) {
  const [flipped, setFlipped] = useState(false)

  return (
    <motion.button
      type="button"
      aria-pressed={flipped}
      aria-label={`${leader.displayName}, ${leader.era}. ${leader.keyBonus}`}
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
      onClick={() => setFlipped((f) => !f)}
      className="relative block w-56 h-72 flex-shrink-0 cursor-pointer text-left"
      style={{ perspective: 1000 }}
    >
      <motion.div
        animate={{ rotateY: flipped ? 180 : 0 }}
        transition={{ type: 'spring', stiffness: 200, damping: 20 }}
        className="relative w-full h-full"
        style={{ transformStyle: 'preserve-3d' }}
      >
        <div
          className="absolute inset-0 rounded-3xl overflow-hidden border border-white/10 bg-white/5"
          style={{ backfaceVisibility: 'hidden' }}
        >
          <div className="relative w-full h-48">
            <Image
              src={assetPath(game.id, 'leaders', leader.portraitAsset)}
              alt={leader.displayName}
              fill
              sizes="224px"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
          </div>
          <div className="p-4">
            <h3 className="font-serif text-white font-bold text-lg leading-tight">{leader.displayName}</h3>
            <p className="text-white/50 text-xs font-sans mt-1">{leader.era}</p>
          </div>
        </div>

        <div
          className="absolute inset-0 rounded-3xl border border-white/10 flex flex-col items-center justify-center p-6 text-center"
          style={{
            backfaceVisibility: 'hidden',
            transform: 'rotateY(180deg)',
            background: `linear-gradient(135deg, ${game.accentColor}20, ${game.backgroundColor})`,
          }}
        >
          <p className="font-serif text-white text-xl font-bold mb-3">{leader.displayName}</p>
          <p className="text-white/60 text-xs uppercase tracking-widest mb-4 font-sans">{leader.era}</p>
          <p className="font-semibold text-base font-sans" style={{ color: game.accentColor }}>
            {leader.keyBonus}
          </p>
          <p className="text-white/60 text-xs mt-6 font-sans">Tap to flip back</p>
        </div>
      </motion.div>
    </motion.button>
  )
}
