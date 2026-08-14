import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { ALL_GAMES, getGameConfig } from '@/config/games'
import { generatePrivacyMetadata, breadcrumbJsonLd } from '@/lib/metadata'
import { GameAppIcon } from '@/components/ui/GameAppIcon'

export async function generateStaticParams() {
  return ALL_GAMES.map(game => ({ slug: game.id }))
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()
  return generatePrivacyMetadata(game)
}

export default async function PrivacyPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGameConfig(slug)
  if (!game) notFound()

  const lastUpdated = new Date(game.privacyPolicyLastUpdated).toLocaleDateString('en-US', {
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
          { name: 'Privacy Policy', url: `https://idle-studio.vercel.app/games/${game.id}/privacy/` },
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
        <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-3">Privacy Policy</h1>
        <p className="text-white/60 text-sm font-sans mb-16">
          {game.displayName} · Last updated {lastUpdated}
        </p>

        <div className="space-y-12 text-white/70 font-sans leading-relaxed">
          <PolicySection title="Overview">
            <p>
              {game.displayName} (&ldquo;the App&rdquo;) is operated by Idle Studio. This policy explains what data we collect, how we use it, and your rights.
            </p>
          </PolicySection>

          <PolicySection title="Data We Collect">
            <ul className="space-y-4 list-none pl-0">
              <PolicyItem title="Gameplay data">Your in-game progress, settings, and preferences are stored locally on your device and synced to your iCloud account (if enabled). We do not have access to this data.</PolicyItem>
              <PolicyItem title="Analytics">We collect anonymised, aggregated usage data through Firebase Analytics to understand how players interact with the game. This data cannot identify you personally.</PolicyItem>
              <PolicyItem title="Advertising">If you choose to watch rewarded ads, Google AdMob may collect device identifiers for ad personalisation subject to your device&apos;s tracking permissions (ATT). Rewarded ads are always optional.</PolicyItem>
              <PolicyItem title="Purchases">If you make in-app purchases, Apple processes the transaction. We receive only a purchase receipt — no payment card data.</PolicyItem>
              <PolicyItem title="Support emails">If you contact us by email, we retain your email address and message to respond to you and improve the game.</PolicyItem>
            </ul>
          </PolicySection>

          <PolicySection title="Data We Do Not Collect">
            <p>We do not collect your name, precise location, contacts, photos, or any sensitive personal information. The App does not require an account to play.</p>
          </PolicySection>

          <PolicySection title="Third-Party Services">
            <p className="mb-4">The App integrates the following third-party services, each governed by their own privacy policies:</p>
            <ul className="space-y-2 text-white/50 text-sm">
              <li>• <strong className="text-white/70">Firebase Analytics</strong> (Google) — anonymous usage metrics</li>
              <li>• <strong className="text-white/70">Google AdMob</strong> — optional rewarded advertising</li>
              <li>• <strong className="text-white/70">Apple Game Center</strong> — leaderboards and achievements</li>
              <li>• <strong className="text-white/70">Apple iCloud</strong> — game save sync</li>
              <li>• <strong className="text-white/70">Apple StoreKit</strong> — in-app purchases</li>
            </ul>
          </PolicySection>

          <PolicySection title="Data Retention">
            <p>Analytics data is retained for 14 months and then automatically deleted by Firebase. Support emails are retained for up to 2 years. iCloud save data is retained until you delete the App or your iCloud account.</p>
          </PolicySection>

          <PolicySection title="Children">
            <p>The App is rated 4+ on the App Store. We do not knowingly collect personal information from children under 13.</p>
          </PolicySection>

          <PolicySection title="Your Rights">
            <p>
              You may request access to, correction of, or deletion of any personal data we hold about you by emailing{' '}
              <a href={`mailto:${game.supportEmail}`} className="text-white underline hover:text-white/80">
                {game.supportEmail}
              </a>
              . We will respond within 30 days.
            </p>
          </PolicySection>

          <PolicySection title="Changes to This Policy">
            <p>We may update this policy occasionally. The &ldquo;Last updated&rdquo; date at the top of this page will always reflect the most recent version.</p>
          </PolicySection>

          <PolicySection title="Contact">
            <p>
              Questions about privacy? Email us at{' '}
              <a href={`mailto:${game.supportEmail}`} className="text-white underline hover:text-white/80">
                {game.supportEmail}
              </a>.
            </p>
          </PolicySection>
        </div>
      </article>
    </main>
  )
}

function PolicySection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-serif text-xl font-bold text-white mb-4">{title}</h2>
      {children}
    </section>
  )
}

function PolicyItem({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <li>
      <strong className="text-white/90 font-semibold">{title}:</strong>{' '}
      {children}
    </li>
  )
}
