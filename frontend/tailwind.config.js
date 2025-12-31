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
        background: '#0a0a12',
        foreground: '#f9fafb',
        card: {
          DEFAULT: 'rgba(255, 255, 255, 0.03)',
          foreground: '#f9fafb',
        },
        primary: {
          DEFAULT: '#8b5cf6',
          foreground: '#ffffff',
        },
        secondary: {
          DEFAULT: '#06b6d4',
          foreground: '#ffffff',
        },
        muted: {
          DEFAULT: '#1f1f2e',
          foreground: '#9ca3af',
        },
        border: 'rgba(255, 255, 255, 0.1)',
        success: '#10b981',
        warning: '#f59e0b',
      },
      fontFamily: {
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-glow': 'pulse-glow 4s ease-in-out infinite',
        'fade-in': 'fade-in 0.5s ease-out',
        'slide-up': 'slide-up 0.5s ease-out',
        'slide-in-right': 'slide-in-right 0.6s ease-out',
      },
      keyframes: {
        'pulse-glow': {
          '0%, 100%': { opacity: '0.4', transform: 'scale(1)' },
          '50%': { opacity: '0.7', transform: 'scale(1.05)' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'slide-up': {
          '0%': { opacity: '0', transform: 'translateY(24px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'slide-in-right': {
          '0%': { opacity: '0', transform: 'translateX(40px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
      },
      backgroundImage: {
        'gradient-hero': 'linear-gradient(135deg, #0a0a12 0%, #1a1a2e 50%, #0a0a12 100%)',
        'gradient-radial': 'radial-gradient(circle, var(--tw-gradient-stops))',
      },
    },
  },
  plugins: [],
}
