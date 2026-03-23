'use client'

import { motion } from 'framer-motion'
import { Moon, Zap, Crown, Trophy, RotateCcw, Globe, ChefHat, Star, FlaskConical, Dumbbell } from 'lucide-react'
import type { GameConfig } from '@/config/types'

const ICON_MAP: Record<string, React.ComponentType<{ className?: string; style?: React.CSSProperties }>> = {
  Moon, Zap, Crown, Trophy, RotateCcw, Globe, ChefHat, Star, FlaskConical, Dumbbell,
}

interface FeaturesGridProps {
  game: GameConfig
}

export function FeaturesGrid({ game }: FeaturesGridProps) {
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
            Why You&apos;ll Love It
          </p>
          <h2 className="font-serif text-4xl md:text-5xl font-bold text-white">Play Your Way</h2>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {game.features.map((feature, i) => {
            const Icon = ICON_MAP[feature.icon]
            return (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ duration: 0.6, delay: i * 0.08, ease: [0.21, 0.47, 0.32, 0.98] }}
                whileHover={{ scale: 1.03, boxShadow: '0 20px 40px rgba(0,0,0,0.4)' }}
                className="p-8 rounded-3xl border border-white/10 bg-white/[0.03] cursor-default"
              >
                {Icon && (
                  <div className="w-12 h-12 rounded-2xl flex items-center justify-center mb-5 bg-white/5">
                    <Icon className="w-6 h-6" style={{ color: game.accentColor }} />
                  </div>
                )}
                <h3 className="font-serif text-xl font-bold text-white mb-3">{feature.title}</h3>
                <p className="text-white/50 text-sm leading-relaxed font-sans">{feature.description}</p>
              </motion.div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
