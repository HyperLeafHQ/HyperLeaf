# HyperLeaf Analytics

Dune-free analytics for assets HyperLeaf supports or plans to support. The UI is adapter-driven; data comes from public RPC and public market endpoints.

## Current scope

- hNEST / NEST on HyperEVM (HyperLeaf native line)
- hKAITO / sKAITO on Base (planned)
- hxSQUID / xSQUID on Base (planned)
- hwstETH / wstETH (planned)
- hVIRTUALMAX / VIRTUAL lock (planned)
- BLUAI4Y / BLUAI on BSC (planned)
- BERA / Berachain (planned analytics)

Pons is **not** a HyperLeaf asset and is intentionally out of scope.

## Architecture

```text
Public RPCs + public price APIs
          ↓
  chain / asset adapters
          ↓
     normalized metrics
          ↓
      Next.js API
          ↓
        dashboard
```

No Dune API and no private keys are required.

## Run

```bash
cd analytics
npm install
npm run dev
```
