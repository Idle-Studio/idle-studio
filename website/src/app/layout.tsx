import type { Metadata } from 'next'
import { Playfair_Display, Inter } from 'next/font/google'
import './globals.css'

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
  metadataBase: new URL('https://idlestudio.io'),
  keywords: ['idle game', 'incremental game', 'mobile game', 'iOS game', 'Idle Civilizations', 'idle studio'],
  alternates: {
    canonical: 'https://idlestudio.io/',
  },
  robots: {
    index: true,
    follow: true,
  },
  openGraph: {
    title: 'Idle Studio — Mobile Idle Games',
    description: 'We build premium idle games for history lovers, foodies, scientists, and sports fans.',
    url: 'https://idlestudio.io/',
    siteName: 'Idle Studio',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Idle Studio — Mobile Idle Games',
    description: 'We build premium idle games for history lovers, foodies, scientists, and sports fans.',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${playfair.variable} ${inter.variable}`}>
      <body>{children}</body>
    </html>
  )
}
