import { describe, it, expect, afterAll } from 'vitest'
import { buildTestApp } from '../helpers/build-test-app.js'

const app = await buildTestApp()
afterAll(async () => { await app.close() })

describe('GET /api/moments', () => {
  it('returns 3 moments with mock defaults', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/moments' })
    expect(res.statusCode).toBe(200)
    const body = res.json()
    expect(body.moments.length).toBe(3)
    expect(body.moments[0].status).toBe(0)
    expect(Array.isArray(body.moments[0].top_guardians)).toBe(true)
  })
  it('filters by status=candidate', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/moments?status=candidate' })
    expect(res.statusCode).toBe(200)
    expect(res.json().moments.every((m: any) => m.status === 0)).toBe(true)
  })
  it('rejects invalid status', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/moments?status=bogus' })
    expect(res.statusCode).toBe(400)
  })
})
