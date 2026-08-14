'use client'

import { useRef } from 'react'
import { motion, useScroll, useTransform } from 'framer-motion'
import Image from 'next/image'
import type { GameConfig } from '@/config/types'
import { assetPath } from '@/lib/assetPath'
import { AppStoreButton } from '@/components/ui/AppStoreButton'

interface DownloadCTAProps {
  game: GameConfig
}

export function DownloadCTA({ game }: DownloadCTAProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ['start end', 'end start'],
  })
  const imgY = useTransform(scrollYProgress, [0, 1], ['5%', '-5%'])

  const lastEra = game.eras[game.eras.length - 1]
  const bgSrc = lastEra ? assetPath(game.id, 'eras', lastEra.artworkAsset) : null
  const taglineWords = game.tagline.split(' ')

  return (
    <section ref={containerRef} className="relative min-h-screen flex items-center justify-center overflow-hidden">
      {bgSrc && (
        <motion.div style={{ y: imgY }} className="absolute inset-[-10%]">
          <Image src={bgSrc} alt={lastEra.displayName} fill sizes="100vw" className="object-cover" />
        </motion.div>
      )}
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to bottom, ${game.backgroundColor} 0%, ${game.backgroundColor}80 40%, ${game.backgroundColor}80 60%, ${game.backgroundColor} 100%)`,
        }}
      />

      <div className="relative z-10 text-center px-6 max-w-3xl mx-auto">
        <div className="font-serif text-4xl md:text-6xl font-bold text-white mb-8 leading-tight">
          {taglineWords.map((word, i) => (
            <motion.span
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.3 + i * 0.08, duration: 0.5 }}
              className="inline-block mr-[0.25em]"
            >
              {word}
            </motion.span>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.8 }}
          className="flex justify-center"
        >
          {game.status === 'live' ? (
            <AppStoreButton url={game.appStoreUrl} size="lg" />
          ) : (
            <div className="text-white/60 text-lg font-sans">Coming Soon</div>
          )}
        </motion.div>
      </div>
    </section>
  )
}
