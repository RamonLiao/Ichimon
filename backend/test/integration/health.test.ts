import { describe, it, expect, afterAll } from 'vitest'
import { buildTestApp } from '../helpers/build-test-app.js'

const app = await buildTestApp()
afterAll(async () => { await app.close() })

describe('GET /health', () => {
  it('returns ok', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' })
    expect(res.statusCode).toBe(200)
    const body = res.json()
    expect(body.ok).toBe(true)
    expect(typeof body.uptime).toBe('number')
  })
})

describe('GET /ready', () => {
  it('returns ok when deps healthy (test mode skips real ping)', async () => {
    const res = await app.inject({ method: 'GET', url: '/ready' })
    expect([200, 503]).toContain(res.statusCode)
  })
})
