'use client'

import { useScroll, useTransform, type MotionValue } from 'framer-motion'
import { useRef } from 'react'

export function useParallax(speed: number = 0.3): {
  ref: React.RefObject<HTMLDivElement>
  y: MotionValue<string>
} {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start end', 'end start'],
  })
  const y = useTransform(scrollYProgress, [0, 1], [`-${speed * 100}%`, `${speed * 100}%`])
  return { ref, y }
}
