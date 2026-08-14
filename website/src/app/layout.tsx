import type { Metadata } from 'next'
import { Playfair_Display, Inter } from 'next/font/google'
import { MotionConfig } from 'framer-motion'
import './globals.css'

const OG_IMAGE = {
  url: '/og-image.jpg',
  width: 1200,
  height: 630,
  alt: 'Idle Studio — Mobile Idle Games',
}

const playfair = Playfair_Display({
  subsets: ['latin'],
  variable: '--font-playfair',
  display: 'swap',
})

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'Idle Studio — Mobile Idle Games',
  description: 'We build premium idle games for history lovers, foodies, scientists, and sports fans.',
  metadataBase: new URL('https://idle-studio.vercel.app'),
  keywords: ['idle game', 'incremental game', 'mobile game', 'iOS game', 'Idle Civilizations', 'idle studio'],
  alternates: {
    canonical: 'https://idle-studio.vercel.app/',
  },
  robots: {
    index: true,
    follow: true,
  },
  openGraph: {
    title: 'Idle Studio — Mobile Idle Games',
    description: 'We build premium idle games for history lovers, foodies, scientists, and sports fans.',
    url: 'https://idle-studio.vercel.app/',
    siteName: 'Idle Studio',
    type: 'website',
    images: [OG_IMAGE],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Idle Studio — Mobile Idle Games',
    description: 'We build premium idle games for history lovers, foodies, scientists, and sports fans.',
    images: [OG_IMAGE.url],
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${playfair.variable} ${inter.variable}`}>
      <body>
        <MotionConfig reducedMotion="user">{children}</MotionConfig>
      </body>
    </html>
  )
}
