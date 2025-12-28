import Wizard from '@/components/Wizard';

export default function WizardPage() {
  return (
    <div className="min-h-screen bg-black text-green-400 font-mono p-8">
      <div className="max-w-6xl mx-auto">
        <header className="mb-12 text-center">
          <h1 className="text-4xl font-bold mb-2">Configuration Wizard</h1>
          <p className="opacity-60">Customize your Ethereum Node in 5 steps</p>
        </header>
        
        <Wizard />
      </div>
    </div>
  );
}
