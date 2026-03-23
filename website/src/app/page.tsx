import { SiteHeader } from '@/components/layout/SiteHeader'
import { SiteFooter } from '@/components/layout/SiteFooter'
import { StudioHero } from '@/components/studio/StudioHero'
import { GameCard } from '@/components/studio/GameCard'
import { ALL_GAMES } from '@/config/games'
import { ScrollReveal } from '@/components/ui/ScrollReveal'

export default function HomePage() {
  return (
    <>
      <SiteHeader />
      <main>
        <StudioHero />

        <section id="games" className="py-32 px-6">
          <div className="max-w-7xl mx-auto">
            <ScrollReveal className="text-center mb-20">
              <p className="text-sm uppercase tracking-[0.3em] text-gold-500 mb-4 font-sans">Our Games</p>
              <h2 className="font-serif text-4xl md:text-5xl font-bold text-white">
                One Engine. Infinite Worlds.
              </h2>
            </ScrollReveal>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {ALL_GAMES.map((game, i) => (
                <GameCard key={game.id} game={game} index={i} />
              ))}
            </div>
          </div>
        </section>

        <section id="about" className="py-32 px-6 border-t border-white/5">
          <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-20 items-center">
            <ScrollReveal delay={0}>
              <p className="text-sm uppercase tracking-[0.3em] text-gold-500 mb-6 font-sans">Our Philosophy</p>
              <h2 className="font-serif text-4xl md:text-5xl font-bold text-white mb-6 leading-tight">
                Built for longevity,<br />not addiction.
              </h2>
              <p className="text-white/50 leading-relaxed text-lg font-sans">
                We build idle games where your empire grows even when you&apos;re not playing. No energy limits. No forced ads. No dark patterns. Just the satisfaction of watching something you built get better over time.
              </p>
            </ScrollReveal>
            <ScrollReveal delay={0.15}>
              <div className="grid grid-cols-2 gap-4">
                {[
                  { number: '1', label: 'Shared Engine' },
                  { number: `${ALL_GAMES.filter(g => g.status === 'live').length}+`, label: 'Games Shipped' },
                  { number: '0', label: 'Forced Ads' },
                  { number: '4+', label: 'Age Rating' },
                ].map((stat) => (
                  <div key={stat.label} className="p-6 rounded-2xl border border-white/10 bg-white/[0.03]">
                    <p className="font-serif text-4xl font-bold text-white mb-1">{stat.number}</p>
                    <p className="text-white/40 text-sm font-sans">{stat.label}</p>
                  </div>
                ))}
              </div>
            </ScrollReveal>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  )
}
