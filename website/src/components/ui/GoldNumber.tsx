'use client'

import { useEffect, useRef } from 'react'
import { useInView, useMotionValue, useTransform, useReducedMotion, animate, motion } from 'framer-motion'

interface GoldNumberProps {
  value: number
  suffix?: string
  className?: string
}

export function GoldNumber({ value, suffix = '', className }: GoldNumberProps) {
  const ref = useRef<HTMLSpanElement>(null)
  // Seeded with the real value so the prerendered HTML shows the final number
  // instead of a placeholder 0; the count-up rewinds to 0 on the client only
  // once the element actually scrolls into view.
  const motionValue = useMotionValue(value)
  const rounded = useTransform(motionValue, (v: number) => Math.round(v))
  const isInView = useInView(ref, { once: true, amount: 0.5 })
  const prefersReducedMotion = useReducedMotion()

  useEffect(() => {
    if (!isInView || prefersReducedMotion) return
    motionValue.set(0)
    const controls = animate(motionValue, value, { duration: 1.5, ease: 'easeOut' })
    return () => controls.stop()
  }, [isInView, motionValue, value, prefersReducedMotion])

  return (
    <span ref={ref} className={className}>
      <motion.span>{rounded}</motion.span>{suffix}
    </span>
  )
}
