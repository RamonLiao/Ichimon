import { describe, it, expect } from 'vitest'
import { createSigner } from '../../src/services/qr-signer.js'

const kp1 = 'v1:' + Buffer.alloc(32, 1).toString('base64')
const kp2 = 'v2:' + Buffer.alloc(32, 2).toString('base64')

describe('qr-signer', () => {
  it('sign then verify roundtrip', async () => {
    const s = await createSigner({ current: kp1 })
    const payload = await s.sign({ station_id: 'st1', fighter_id: 'takeru', exp: Date.now() + 60_000 })
    const v = await s.verify(payload)
    expect(v.payload.station_id).toBe('st1')
  })
  it('verify fails on tamper', async () => {
    const s = await createSigner({ current: kp1 })
    const p = await s.sign({ station_id: 'a', fighter_id: 'b', exp: Date.now() + 60_000 })
    const tampered = p.slice(0, -4) + 'XXXX'
    await expect(s.verify(tampered)).rejects.toThrow(/INVALID_SIGNATURE/)
  })
  it('verify fails on expired', async () => {
    const s = await createSigner({ current: kp1 })
    const p = await s.sign({ station_id: 'a', fighter_id: 'b', exp: Date.now() - 1 })
    await expect(s.verify(p)).rejects.toThrow(/EXPIRED/)
  })
  it('verify fails when kid unknown', async () => {
    const signer = await createSigner({ current: kp2 })
    const p = await signer.sign({ station_id: 'a', fighter_id: 'b', exp: Date.now() + 60_000 })
    const onlyV1 = await createSigner({ current: kp1 })
    await expect(onlyV1.verify(p)).rejects.toThrow(/INVALID_SIGNATURE/)
  })
  it('verifies with PREVIOUS key during rotation', async () => {
    const v1 = await createSigner({ current: kp1 })
    const p = await v1.sign({ station_id: 'a', fighter_id: 'b', exp: Date.now() + 60_000 })
    const rotated = await createSigner({ current: kp2, previous: kp1 })
    const res = await rotated.verify(p)
    expect(res.payload.station_id).toBe('a')
  })
  it('malformed payload → MALFORMED_QR', async () => {
    const s = await createSigner({ current: kp1 })
    await expect(s.verify('notdotseparated')).rejects.toThrow(/MALFORMED_QR/)
  })
})
