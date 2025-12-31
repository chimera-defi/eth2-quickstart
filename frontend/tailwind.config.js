/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Refined dark palette - deeper, more sophisticated
        background: '#09090b',
        foreground: '#fafafa',
        card: {
          DEFAULT: 'rgba(255, 255, 255, 0.02)',
          foreground: '#fafafa',
        },
        // Single, refined accent - elegant purple
        primary: {
          DEFAULT: '#a855f7',
          foreground: '#ffffff',
          muted: 'rgba(168, 85, 247, 0.1)',
        },
        // Subtle secondary - cool gray with hint of blue
        secondary: {
          DEFAULT: '#71717a',
          foreground: '#fafafa',
        },
        muted: {
          DEFAULT: '#18181b',
          foreground: '#a1a1aa',
        },
        border: 'rgba(255, 255, 255, 0.06)',
        success: '#22c55e',
        warning: '#eab308',
      },
      fontFamily: {
        mono: ['JetBrains Mono', 'SF Mono', 'monospace'],
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
      },
      animation: {
        'fade-in': 'fade-in 0.6s ease-out',
        'slide-up': 'slide-up 0.6s ease-out',
        'slide-in': 'slide-in 0.8s ease-out',
        'subtle-pulse': 'subtle-pulse 8s ease-in-out infinite',
      },
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'slide-up': {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'slide-in': {
          '0%': { opacity: '0', transform: 'translateX(24px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
        'subtle-pulse': {
          '0%, 100%': { opacity: '0.3' },
          '50%': { opacity: '0.5' },
        },
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(ellipse at center, var(--tw-gradient-stops))',
      },
      spacing: {
        '18': '4.5rem',
        '22': '5.5rem',
      },
    },
  },
  plugins: [],
}
