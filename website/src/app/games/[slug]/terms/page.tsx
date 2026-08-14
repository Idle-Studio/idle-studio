import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { ALL_GAMES, getGameConfig } from '@/config/games'
import { generateTermsMetadata, breadcrumbJsonLd } from '@/lib/metadata'
import { GameAppIcon } from '@/components/ui/GameAppIcon'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()
  return generateTermsMetadata(game)
}

export default async function TermsPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()

  const lastUpdated = new Date(game.termsLastUpdated).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })

  return (
    <main className="min-h-screen" style={{ backgroundColor: game.backgroundColor }}>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd([
          { name: 'Idle Studio', url: 'https://idle-studio.vercel.app/' },
          { name: game.displayName, url: `https://idle-studio.vercel.app/games/${game.id}/` },
          { name: 'Terms of Use', url: `https://idle-studio.vercel.app/games/${game.id}/terms/` },
        ])) }}
      />
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

      <article className="max-w-3xl mx-auto px-6 py-20">
        <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-3">Terms of Use</h1>
        <p className="text-white/60 text-sm font-sans mb-16">
          {game.displayName} · Last updated {lastUpdated}
        </p>

        <div className="space-y-12 text-white/70 font-sans leading-relaxed">
          <TermsSection title="Acceptance of Terms">
            <p>
              By downloading or using {game.displayName} (&ldquo;the App&rdquo;), you agree to these Terms of Use. If you do not agree, do not use the App.
            </p>
          </TermsSection>

          <TermsSection title="License">
            <p>
              Idle Studio grants you a limited, non-exclusive, non-transferable, revocable licence to use the App for personal, non-commercial purposes on devices you own or control, subject to these terms and the App Store Terms of Service.
            </p>
          </TermsSection>

          <TermsSection title="In-App Purchases & Subscriptions">
            <ul className="space-y-4 list-none pl-0">
              <TermsItem title="Consumables">Coin packs and one-time purchases are non-refundable once delivered.</TermsItem>
              <TermsItem title="Subscriptions">The {game.vocab.premiumPassName} is an auto-renewable subscription billed to your Apple ID. It renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your Apple ID account settings.</TermsItem>
              <TermsItem title="Restore Purchases">You may restore previous purchases at any time using the &ldquo;Restore Purchases&rdquo; option in the App.</TermsItem>
              <TermsItem title="Refunds">All purchases are processed by Apple. Refund requests must be submitted to Apple directly via reportaproblem.apple.com.</TermsItem>
            </ul>
          </TermsSection>

          <TermsSection title="User Conduct">
            <p className="mb-4">You agree not to:</p>
            <ul className="space-y-2 text-white/50 text-sm">
              <li>• Reverse-engineer, decompile, or modify the App</li>
              <li>• Use cheats, exploits, automation software, or any unauthorised third-party tools</li>
              <li>• Attempt to gain unauthorised access to Idle Studio servers or other users&apos; accounts</li>
              <li>• Use the App for any unlawful purpose</li>
            </ul>
          </TermsSection>

          <TermsSection title="Intellectual Property">
            <p>
              All content in the App — including artwork, music, text, and code — is the property of Idle Studio or its licensors and is protected by copyright law. You may not reproduce or distribute any content without written permission.
            </p>
          </TermsSection>

          <TermsSection title="Disclaimer of Warranties">
            <p>
              The App is provided &ldquo;as is&rdquo; without warranties of any kind. Idle Studio does not guarantee the App will be uninterrupted, error-free, or free of harmful components.
            </p>
          </TermsSection>

          <TermsSection title="Limitation of Liability">
            <p>
              To the maximum extent permitted by law, Idle Studio shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App, including loss of in-game progress or virtual items.
            </p>
          </TermsSection>

          <TermsSection title="Changes to These Terms">
            <p>
              We may update these terms from time to time. The &ldquo;Last updated&rdquo; date at the top of this page will reflect the most recent version. Continued use of the App after changes constitutes acceptance of the updated terms.
            </p>
          </TermsSection>

          <TermsSection title="Governing Law">
            <p>
              These terms are governed by the laws of Romania, without regard to conflict of law provisions.
            </p>
          </TermsSection>

          <TermsSection title="Contact">
            <p>
              Questions about these terms? Email us at{' '}
              <a href={`mailto:${game.supportEmail}`} className="text-white underline hover:text-white/80">
                {game.supportEmail}
              </a>.
            </p>
          </TermsSection>
        </div>
      </article>
    </main>
  )
}

function TermsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-serif text-xl font-bold text-white mb-4">{title}</h2>
      {children}
    </section>
  )
}

function TermsItem({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <li>
      <strong className="text-white/90 font-semibold">{title}:</strong>{' '}
      {children}
    </li>
  )
}
