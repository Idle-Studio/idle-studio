'use client'

import { useRef } from 'react'
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion'
import { studioConfig } from '@/config/studio'

export function StudioHero() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const opacity = useTransform(scrollYProgress, [0, 0.5], [1, 0])
  const y = useTransform(scrollYProgress, [0, 1], ['0%', '20%'])
  const prefersReducedMotion = useReducedMotion()

  const words = studioConfig.tagline.split(' ')

  return (
    <section ref={ref} className="relative min-h-screen flex items-center justify-center overflow-hidden bg-[#0D0D0F]">
      <div
        className="absolute inset-0"
        style={{ background: 'radial-gradient(ellipse 80% 60% at 50% 40%, rgba(200,168,75,0.08) 0%, transparent 70%)' }}
      />

      <motion.div style={{ opacity, y }} className="relative z-10 text-center px-6 max-w-5xl mx-auto">
        {/* Above the fold: rendered visible in the static HTML so first paint
            does not wait on hydration. */}
        <p className="text-gold-500 text-sm uppercase tracking-[0.3em] mb-8 font-sans">
          {studioConfig.name}
        </p>

        <h1 className="font-serif text-5xl md:text-7xl lg:text-8xl font-bold text-white leading-[1.05] mb-8">
          {words.map((word, i) => (
            <span key={i} className="inline-block mr-[0.25em]">
              {word}
            </span>
          ))}
        </h1>

        <p className="text-white/50 text-lg md:text-xl max-w-xl mx-auto leading-relaxed font-sans">
          {studioConfig.description}
        </p>

        <div className="mt-16 flex justify-center">
          <motion.div
            animate={prefersReducedMotion ? undefined : { y: [0, 10, 0] }}
            transition={prefersReducedMotion ? undefined : { repeat: Infinity, duration: 2, ease: 'easeInOut' }}
            className="text-white/20 text-xs uppercase tracking-widest flex flex-col items-center gap-3"
          >
            <span>Scroll</span>
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 9l-7 7-7-7" />
            </svg>
          </motion.div>
        </div>
      </motion.div>
    </section>
  )
}
