'use client'

import { motion, useScroll, useTransform } from 'framer-motion'
import Link from 'next/link'

export function SiteHeader() {
  const { scrollY } = useScroll()
  const bg = useTransform(scrollY, [0, 100], ['rgba(13,13,15,0)', 'rgba(13,13,15,0.95)'])

  return (
    <motion.header
      style={{ backgroundColor: bg }}
      className="fixed top-0 left-0 right-0 z-50 backdrop-blur-sm border-b border-white/0"
    >
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <Link href="/" className="font-serif text-xl font-bold text-white hover:text-gold-400 transition-colors">
          Idle Studio
        </Link>
        <nav className="hidden md:flex items-center gap-8 text-sm text-white/60">
          <Link href="/#games" className="hover:text-white transition-colors">Games</Link>
          <Link href="/#about" className="hover:text-white transition-colors">About</Link>
        </nav>
      </div>
    </motion.header>
  )
}
