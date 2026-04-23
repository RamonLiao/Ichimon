import { describe, it, expect, afterAll } from 'vitest'
import { buildTestApp } from '../helpers/build-test-app.js'

const app = await buildTestApp()
afterAll(async () => { await app.close() })

describe('monkey: QR payload abuse', () => {
  it('10MB garbage → 400 (schema rejects, never crash)', async () => {
    const payload = 'x'.repeat(10 * 1024 * 1024)
    const res = await app.inject({ method: 'POST', url: '/api/checkin/qr/verify', payload: { qr_payload: payload } })
    expect([400, 413]).toContain(res.statusCode)
  })
  it('100 concurrent same-nonce verify → exactly 1 passes', async () => {
    const issue = await app.inject({
      method: 'POST', url: '/api/checkin/qr/issue',
      payload: { station_id: 'sx', fighter_id: 'takeru', issuer_token: 'demo-1' },
    })
    const { qr_payload } = issue.json()
    const reqs = await Promise.all(Array.from({ length: 100 }, () =>
      app.inject({ method: 'POST', url: '/api/checkin/qr/verify', payload: { qr_payload } })
    ))
    const okCount = reqs.filter((r) => r.statusCode === 200).length
    const usedCount = reqs.filter((r) => r.statusCode === 409).length
    expect(okCount).toBe(1)
    expect(okCount + usedCount).toBe(100)
  })
  it('injection string in station_id roundtrips as literal', async () => {
    const evil = `"; DROP TABLE foo; --`
    const issue = await app.inject({
      method: 'POST', url: '/api/checkin/qr/issue',
      payload: { station_id: evil, fighter_id: 'takeru', issuer_token: 'demo-1' },
    })
    expect(issue.statusCode).toBe(200)
    const verify = await app.inject({
      method: 'POST', url: '/api/checkin/qr/verify', payload: { qr_payload: issue.json().qr_payload },
    })
    expect(verify.statusCode).toBe(200)
    expect(verify.json().payload.station_id).toBe(evil)
  })
  it('clock skew (short-expiry + sleep) → EXPIRED', async () => {
    const past = await app.services.signer.sign({ station_id: 'a', fighter_id: 'b', exp: Date.now() - 1 })
    const res = await app.inject({ method: 'POST', url: '/api/checkin/qr/verify', payload: { qr_payload: past } })
    expect(res.statusCode).toBe(410)
  })
  it('tampered sig → INVALID_SIGNATURE (no stack leak)', async () => {
    const issue = await app.inject({
      method: 'POST', url: '/api/checkin/qr/issue',
      payload: { station_id: 's', fighter_id: 'takeru', issuer_token: 'demo-1' },
    })
    const p = issue.json().qr_payload
    const bad = p.slice(0, -4) + 'AAAA'
    const res = await app.inject({ method: 'POST', url: '/api/checkin/qr/verify', payload: { qr_payload: bad } })
    expect(res.statusCode).toBe(401)
    expect(res.body).not.toMatch(/at \w+.*\(.*\.ts:/)
  })
})
