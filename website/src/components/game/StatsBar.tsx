'use client'

import { motion } from 'framer-motion'
import type { GameConfig } from '@/config/types'
import { GoldNumber } from '@/components/ui/GoldNumber'

interface StatsBarProps {
  game: GameConfig
}

export function StatsBar({ game }: StatsBarProps) {
  const stats = [
    { value: game.stats.levelCount, label: game.vocab.levelPlural },
    { value: game.stats.unitCount, label: game.vocab.unitPlural },
    { value: game.stats.milestoneCount, label: game.vocab.milestonePlural },
    { value: game.stats.leaderCount, label: game.vocab.characterPlural },
  ]

  const container = {
    hidden: {},
    visible: { transition: { staggerChildren: 0.1 } },
  }
  const item = {
    hidden: { opacity: 0, scale: 0.8 },
    visible: { opacity: 1, scale: 1, transition: { duration: 0.5, ease: [0.21, 0.47, 0.32, 0.98] } },
  }

  return (
    <section className="py-16 px-6">
      <motion.div
        variants={container}
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, amount: 0.5 }}
        className="max-w-4xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-px bg-white/10 rounded-3xl overflow-hidden"
      >
        {stats.map((stat) => (
          <motion.div
            key={stat.label}
            variants={item}
            className="bg-[#0D0D0F] px-8 py-10 text-center"
          >
            <GoldNumber
              value={stat.value}
              className="block font-serif text-5xl font-bold mb-2 text-white"
            />
            <p className="text-white/50 text-sm uppercase tracking-widest font-sans">{stat.label}</p>
          </motion.div>
        ))}
      </motion.div>
    </section>
  )
}
