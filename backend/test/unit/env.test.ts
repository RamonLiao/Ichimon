import { describe, it, expect } from 'vitest'
import { parseEnv } from '../../src/env.js'

const base = {
  NODE_ENV: 'test',
  PORT: '3000',
  DATA_SOURCE: 'mock',
  SUI_GRPC_URL: 'https://fullnode.testnet.sui.io:443',
  PKG_ID: '0xabc',
  MINT_REGISTRY_ID: '0xdef',
  MINT_REGISTRY_INITIAL_SHARED_VERSION: '828957603',
  QR_KEY_CURRENT: 'v1:' + Buffer.alloc(32, 1).toString('base64'),
  QR_EXPIRY_MS: '300000',
  ISSUER_TOKENS: 'demo-1,demo-2',
  UPSTASH_REDIS_REST_URL: 'https://example.upstash.io',
  UPSTASH_REDIS_REST_TOKEN: 'token',
  ALLOWED_ORIGINS: 'http://localhost:5173',
}

describe('parseEnv', () => {
  it('parses a valid env', () => {
    const env = parseEnv(base)
    expect(env.PORT).toBe(3000)
    expect(env.ISSUER_TOKENS).toEqual(['demo-1', 'demo-2'])
    expect(env.ALLOWED_ORIGINS).toEqual(['http://localhost:5173'])
  })
  it('throws when required field missing', () => {
    const { PKG_ID, ...bad } = base
    expect(() => parseEnv(bad)).toThrow()
  })
  it('throws on malformed QR_KEY_CURRENT', () => {
    expect(() => parseEnv({ ...base, QR_KEY_CURRENT: 'notvalid' })).toThrow()
  })
})
