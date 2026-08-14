'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Link from 'next/link'
import type { GameConfig } from '@/config/types'
import { GameAppIcon } from '@/components/ui/GameAppIcon'

interface SupportPageClientProps {
  game: GameConfig
}

export function SupportPageClient({ game }: SupportPageClientProps) {
  return (
    <main className="min-h-screen" style={{ backgroundColor: game.backgroundColor }}>
      <div className="border-b border-white/10 py-6 px-6">
        <div className="max-w-3xl mx-auto flex items-center justify-between">
          <Link href={`/games/${game.id}`} className="flex items-center gap-3">
            <GameAppIcon game={game} />
            <span className="font-serif text-white font-bold">{game.displayName}</span>
          </Link>
          <Link href="/" className="text-white/60 hover:text-white text-sm transition-colors font-sans">
            Idle Studio
          </Link>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-6 py-20">
        <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-4">Support</h1>
        <p className="text-white/50 text-lg mb-16 font-sans">
          We&apos;re here to help. Check the FAQ below or reach out directly.
        </p>

        <motion.a
          href={`mailto:${game.supportEmail}`}
          whileHover={{ scale: 1.02, boxShadow: '0 10px 30px rgba(0,0,0,0.4)' }}
          whileTap={{ scale: 0.98 }}
          className="flex items-center gap-4 p-6 rounded-2xl border border-white/10 bg-white/[0.05] mb-16 cursor-pointer group"
        >
          <div
            className="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: `${game.accentColor}20` }}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ color: game.accentColor }}>
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
          </div>
          <div>
            <p className="text-white font-semibold font-sans">{game.supportEmail}</p>
            <p className="text-white/60 text-sm font-sans">We typically respond within 1 business day</p>
          </div>
          <svg className="w-5 h-5 text-white/20 ml-auto transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </motion.a>

        {game.supportFAQ.length > 0 && (
          <>
            <h2 className="font-serif text-2xl font-bold text-white mb-8">Frequently Asked Questions</h2>
            <div className="space-y-3">
              {game.supportFAQ.map((item, i) => (
                <FAQItem key={i} question={item.question} answer={item.answer} />
              ))}
            </div>
          </>
        )}
      </div>
    </main>
  )
}

function FAQItem({ question, answer }: { question: string; answer: string }) {
  const [open, setOpen] = useState(false)
  return (
    <div className="rounded-2xl border border-white/10 overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        aria-expanded={open}
        className="w-full flex items-center justify-between p-6 text-left bg-white/[0.03] hover:bg-white/[0.06] transition-colors"
      >
        <span className="font-sans text-white font-medium pr-4">{question}</span>
        <motion.div
          animate={{ rotate: open ? 45 : 0 }}
          transition={{ duration: 0.2 }}
          className="w-5 h-5 flex-shrink-0 text-white/40"
        >
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 5v14M5 12h14" />
          </svg>
        </motion.div>
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: [0.21, 0.47, 0.32, 0.98] }}
            className="overflow-hidden"
          >
            <p className="px-6 pb-6 pt-2 text-white/60 text-sm leading-relaxed font-sans">{answer}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
