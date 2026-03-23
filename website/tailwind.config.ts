import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      fontFamily: {
        serif: ['var(--font-playfair)', 'Georgia', 'serif'],
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
      },
      colors: {
        gold: {
          300: '#E8D5A3',
          400: '#D4B869',
          500: '#C8A84B',
          600: '#A88A35',
        },
      },
    },
  },
  plugins: [],
}

export default config
