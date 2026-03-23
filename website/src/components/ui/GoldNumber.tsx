'use client'

import { useEffect, useRef } from 'react'
import { useInView, useMotionValue, useTransform, animate, motion } from 'framer-motion'

interface GoldNumberProps {
  value: number
  suffix?: string
  className?: string
}

export function GoldNumber({ value, suffix = '', className }: GoldNumberProps) {
  const ref = useRef<HTMLSpanElement>(null)
  const motionValue = useMotionValue(0)
  const rounded = useTransform(motionValue, (v: number) => Math.round(v))
  const isInView = useInView(ref, { once: true, amount: 0.5 })

  useEffect(() => {
    if (isInView) {
      animate(motionValue, value, { duration: 1.5, ease: 'easeOut' })
    }
  }, [isInView, motionValue, value])

  return (
    <span ref={ref} className={className}>
      <motion.span>{rounded}</motion.span>{suffix}
    </span>
  )
}
