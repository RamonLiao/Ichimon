import { buildApp } from '../../src/app.js'

export async function buildTestApp() {
  process.env.NODE_ENV = 'test'
  process.env.DATA_SOURCE = 'mock'
  process.env.SUI_GRPC_URL ??= 'https://fullnode.testnet.sui.io:443'
  process.env.PKG_ID ??= '0xpkg'
  process.env.MINT_REGISTRY_ID ??= '0xreg'
  process.env.MINT_REGISTRY_INITIAL_SHARED_VERSION ??= '828957603'
  process.env.QR_KEY_CURRENT ??= 'v1:' + Buffer.alloc(32, 1).toString('base64')
  process.env.ISSUER_TOKENS ??= 'demo-1'
  process.env.UPSTASH_REDIS_REST_URL ??= 'https://example.upstash.io'
  process.env.UPSTASH_REDIS_REST_TOKEN ??= 'token'
  process.env.ALLOWED_ORIGINS ??= 'http://localhost:5173'
  return buildApp()
}
