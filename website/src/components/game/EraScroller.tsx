'use client'

import { useRef, useState, useEffect } from 'react'
import { motion, useScroll, useTransform, AnimatePresence, type MotionValue } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'

interface EraScrollerProps {
  game: GameConfig
}

export function EraScroller({ game }: EraScrollerProps) {
  const sectionRef = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end end'],
  })

  const totalEras = game.eras.length

  // x must be in pixels — percentage would be relative to the strip's own width
  const [vw, setVw] = useState(0)
  useEffect(() => {
    const update = () => setVw(window.innerWidth)
    update()
    window.addEventListener('resize', update)
    return () => window.removeEventListener('resize', update)
  }, [])

  const x = useTransform(scrollYProgress, [0, 1], [0, -(totalEras - 1) * vw])

  return (
    <section
      ref={sectionRef}
      className="relative"
      style={{ height: `${totalEras * 100}vh` }}
    >
      <div className="sticky top-0 h-screen overflow-hidden">
        <motion.div
          className="flex h-full"
          style={{ x, width: `${totalEras * 100}vw` }}
        >
          {game.eras.map((era) => (
            <div
              key={era.id}
              className="relative flex-shrink-0 h-screen w-screen"
            >
              <Image
                src={assetPath(game.id, 'eras', era.artworkAsset)}
                alt={era.displayName}
                fill
                sizes="100vw"
                className="object-cover"
              />
              <div
                className="absolute inset-0"
                style={{ background: `linear-gradient(to bottom, transparent 40%, ${era.primaryColor}CC 100%)` }}
              />
            </div>
          ))}
        </motion.div>

        <div className="absolute bottom-16 left-0 right-0 px-12 z-20 pointer-events-none">
          <div className="max-w-7xl mx-auto">
            <EraLabel game={game} scrollYProgress={scrollYProgress} />
          </div>
        </div>

        <div className="absolute right-8 top-1/2 -translate-y-1/2 z-20 flex flex-col gap-3">
          {game.eras.map((era, i) => (
            <ProgressDot
              key={era.id}
              index={i}
              scrollYProgress={scrollYProgress}
              total={game.eras.length}
              color={era.primaryColor}
            />
          ))}
        </div>
      </div>
    </section>
  )
}

function EraLabel({ game, scrollYProgress }: { game: GameConfig; scrollYProgress: MotionValue<number> }) {
  const [activeIdx, setActiveIdx] = useState(0)

  useEffect(() => {
    const unsubscribe = scrollYProgress.on('change', (v: number) => {
      const idx = Math.min(Math.floor(v * game.eras.length), game.eras.length - 1)
      setActiveIdx(idx)
    })
    return unsubscribe
  }, [scrollYProgress, game.eras.length])

  const era = game.eras[activeIdx]

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={activeIdx}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -20 }}
        transition={{ duration: 0.4 }}
      >
        <p className="text-sm uppercase tracking-[0.3em] text-white/60 mb-2 font-sans">
          Era {era.order} of {game.eras.length}
        </p>
        <h2 className="font-serif text-4xl md:text-6xl font-bold text-white mb-3">
          {era.displayName}
        </h2>
        <p className="text-white/60 text-lg italic font-sans max-w-md">{era.flavorText}</p>
      </motion.div>
    </AnimatePresence>
  )
}

function ProgressDot({
  index,
  scrollYProgress,
  total,
  color,
}: {
  index: number
  scrollYProgress: MotionValue<number>
  total: number
  color: string
}) {
  const [active, setActive] = useState(false)

  useEffect(() => {
    const unsubscribe = scrollYProgress.on('change', (v: number) => {
      const idx = Math.min(Math.floor(v * total), total - 1)
      setActive(idx === index)
    })
    return unsubscribe
  }, [scrollYProgress, total, index])

  return (
    <motion.div
      animate={{ scale: active ? 1.5 : 1, opacity: active ? 1 : 0.3 }}
      transition={{ duration: 0.3 }}
      className="w-2 h-2 rounded-full"
      style={{ backgroundColor: active ? color : 'white' }}
    />
  )
}
