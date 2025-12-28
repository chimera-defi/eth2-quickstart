import Link from 'next/link';

export default function Home() {
  return (
    <div className="min-h-screen bg-black text-green-400 font-mono p-8 flex flex-col items-center justify-center">
      <header className="max-w-4xl w-full mb-12 text-center">
        <h1 className="text-6xl font-bold mb-4 border-b-2 border-green-500 pb-4">
          Eth2 Quick Start
        </h1>
        <p className="text-xl opacity-80 mb-8">
          The One-Liner Ethereum Node Setup
        </p>
      </header>

      <main className="max-w-4xl w-full grid gap-12">
        {/* The One Liner Hero */}
        <div className="bg-gray-900 border border-green-500 rounded-lg p-8 shadow-[0_0_20px_rgba(34,197,94,0.2)]">
          <h2 className="text-2xl mb-4 font-bold text-white">Get Started Instantly</h2>
          <div className="bg-black p-6 rounded border border-gray-700 font-mono text-lg overflow-x-auto">
            <span className="text-pink-500">$</span> curl -fsSL https://eth2-quickstart.vercel.app/install.sh | bash
          </div>
          <p className="mt-4 text-sm text-gray-400">
            * Bootstraps git, dependencies, and launches the configuration wizard.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid md:grid-cols-3 gap-6">
          <div className="border border-green-500/30 p-6 rounded-lg hover:border-green-500 transition-colors">
            <h3 className="text-xl font-bold mb-2 text-white">The One-Liner</h3>
            <p className="opacity-70">
              Zero friction setup. Paste one command and your environment is ready.
            </p>
          </div>
          <div className="border border-green-500/30 p-6 rounded-lg hover:border-green-500 transition-colors">
            <h3 className="text-xl font-bold mb-2 text-white">The Wizard</h3>
            <p className="opacity-70">
              Interactive configuration for Hardware, Clients, and MEV rewards.
            </p>
          </div>
          <div className="border border-green-500/30 p-6 rounded-lg hover:border-green-500 transition-colors">
            <h3 className="text-xl font-bold mb-2 text-white">The Doctor</h3>
            <p className="opacity-70">
              Automated health checks ensuring your node is synced and secure.
            </p>
          </div>
        </div>

        {/* CTA */}
        <div className="text-center">
          <Link 
            href="/wizard" 
            className="inline-block bg-green-600 hover:bg-green-500 text-black font-bold text-xl py-4 px-12 rounded-full transition-all transform hover:scale-105"
          >
            Start Web Configurator &rarr;
          </Link>
          <p className="mt-4 opacity-60">
            Or configure directly in the browser and generate a setup script.
          </p>
        </div>
      </main>
      
      <footer className="mt-20 opacity-40 text-sm">
        <p>Powered by the Agent Flywheel Pattern</p>
      </footer>
    </div>
  );
}
