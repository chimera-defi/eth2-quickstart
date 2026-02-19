/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    domains: [],
    formats: ['image/avif', 'image/webp'],
  },
  // Enable static export for deployment flexibility
  output: 'standalone',
  async redirects() {
    return [
      { source: '/learn', destination: '/quickstart', permanent: true },
    ]
  },
}

module.exports = nextConfig
