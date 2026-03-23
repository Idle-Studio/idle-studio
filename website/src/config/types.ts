export interface EraConfig {
  id: string
  displayName: string
  order: number
  flavorText: string
  artworkAsset: string
  primaryColor: string
  secondaryColor: string
}

export interface WonderConfig {
  id: string
  displayName: string
  artworkAsset: string
  era: string
  bonus: string
}

export interface LeaderConfig {
  id: string
  displayName: string
  era: string
  portraitAsset: string
  keyBonus: string
}

export interface BuildingShowcaseItem {
  id: string
  displayName: string
  iconAsset: string
  era: string
}

export interface GameFeature {
  icon: string
  title: string
  description: string
}

export interface SupportFAQ {
  question: string
  answer: string
}

export interface GameConfig {
  id: string
  displayName: string
  tagline: string
  subtitle: string
  description: string
  appStoreId: string
  appStoreUrl: string
  status: 'live' | 'coming-soon' | 'beta'
  accentColor: string
  backgroundColor: string
  appIconAsset: string
  heroArtworkAsset: string
  eras: EraConfig[]
  wonders: WonderConfig[]
  leaders: LeaderConfig[]
  buildingShowcase: BuildingShowcaseItem[]
  features: GameFeature[]
  vocab: {
    levelPlural: string
    unitPlural: string
    milestonePlural: string
    characterPlural: string
    prestigeVerb: string
    premiumPassName: string
  }
  stats: {
    levelCount: number
    unitCount: number
    milestoneCount: number
    leaderCount: number
  }
  supportEmail: string
  privacyPolicyLastUpdated: string
  supportFAQ: SupportFAQ[]
}

export interface StudioConfig {
  name: string
  tagline: string
  description: string
  email: string
  twitter?: string
  instagram?: string
}
