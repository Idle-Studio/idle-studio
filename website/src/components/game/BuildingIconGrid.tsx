'use client'

import { motion } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface BuildingIconGridProps {
  game: GameConfig
}

export function BuildingIconGrid({ game }: BuildingIconGridProps) {
  const container = {
    hidden: {},
    visible: { transition: { staggerChildren: 0.04 } },
  }
  const item = {
    hidden: { opacity: 0, scale: 0.5 },
    visible: { opacity: 1, scale: 1, transition: { type: 'spring', bounce: 0.4 } },
  }

  return (
    <section className="py-32 px-6">
      <div className="max-w-7xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.7 }}
          className="text-center mb-20"
        >
          <p className="text-sm uppercase tracking-[0.3em] mb-4 font-sans" style={{ color: game.accentColor }}>
            Something to Build
          </p>
          <h2 className="font-serif text-4xl md:text-5xl font-bold text-white">
            {game.stats.unitCount} Unique {game.vocab.unitPlural}
          </h2>
        </motion.div>

        <motion.div
          variants={container}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.1 }}
          className="grid grid-cols-4 sm:grid-cols-6 lg:grid-cols-8 gap-4"
        >
          {game.buildingShowcase.map((building) => (
            <motion.div
              key={building.id}
              variants={item}
              whileHover={{
                scale: 1.15,
                rotate: [-2, 2, -2, 0],
                transition: { rotate: { duration: 0.3 } },
              }}
              className="flex flex-col items-center gap-2 cursor-default"
            >
              <div className="relative w-14 h-14 rounded-2xl overflow-hidden border border-white/10 bg-white/5">
                <Image
                  src={assetPath(game.id, 'buildings', building.iconAsset)}
                  alt={building.displayName}
                  fill
                  className="object-cover p-1"
                />
              </div>
              <p className="text-white/40 text-[10px] text-center font-sans leading-tight max-w-[60px]">
                {building.displayName}
              </p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
