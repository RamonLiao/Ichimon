import * as ed from '@noble/ed25519'
import { sha512 } from '@noble/hashes/sha512'
import { randomBytes } from 'node:crypto'
import { Errors } from '../errors.js'

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m))

const b64u = {
  encode: (buf: Uint8Array | string) => Buffer.from(buf as any).toString('base64url'),
  decode: (s: string) => Buffer.from(s, 'base64url'),
}

export type QrBody = {
  station_id: string
  fighter_id: string
  nonce: string
  iat: number
  exp: number
}

export type SignInput = {
  station_id: string
  fighter_id: string
  exp: number
  iat?: number
  nonce?: string
}

type ParsedKey = { kid: string; priv: Uint8Array; pub: Uint8Array }

async function parseKey(spec: string): Promise<ParsedKey> {
  const [kid, b64] = spec.split(':')
  if (!kid || !b64) throw new Error('Malformed QR key spec')
  const priv = new Uint8Array(Buffer.from(b64, 'base64'))
  if (priv.length !== 32) throw new Error('QR key must be 32 bytes')
  const pub = await ed.getPublicKeyAsync(priv)
  return { kid, priv, pub }
}

export type Signer = {
  sign: (input: SignInput) => Promise<string>
  verify: (payload: string) => Promise<{ payload: QrBody; kid: string }>
  pubkeys: () => Record<string, string>
}

export async function createSigner(opts: { current: string; previous?: string }): Promise<Signer> {
  const current = await parseKey(opts.current)
  const previous = opts.previous ? await parseKey(opts.previous) : null
  const keymap = new Map<string, ParsedKey>()
  keymap.set(current.kid, current)
  if (previous) keymap.set(previous.kid, previous)

  return {
    async sign(input) {
      const body: QrBody = {
        station_id: input.station_id,
        fighter_id: input.fighter_id,
        nonce: input.nonce ?? Buffer.from(randomBytes(16)).toString('base64url'),
        iat: input.iat ?? Date.now(),
        exp: input.exp,
      }
      const header = { alg: 'ed25519', kid: current.kid }
      const h = b64u.encode(JSON.stringify(header))
      const b = b64u.encode(JSON.stringify(body))
      const msg = new TextEncoder().encode(`${h}.${b}`)
      const sig = await ed.signAsync(msg, current.priv)
      return `${h}.${b}.${b64u.encode(sig)}`
    },

    async verify(payload) {
      const parts = payload.split('.')
      if (parts.length !== 3) throw Errors.malformedQr()
      const [h, b, s] = parts as [string, string, string]
      let header: { alg: string; kid: string }
      let body: QrBody
      try {
        header = JSON.parse(b64u.decode(h).toString('utf8'))
        body = JSON.parse(b64u.decode(b).toString('utf8'))
      } catch {
        throw Errors.malformedQr()
      }
      if (header.alg !== 'ed25519' || typeof header.kid !== 'string') throw Errors.malformedQr()
      if (
        typeof body.station_id !== 'string' ||
        typeof body.fighter_id !== 'string' ||
        typeof body.nonce !== 'string' ||
        typeof body.iat !== 'number' ||
        typeof body.exp !== 'number'
      ) throw Errors.malformedQr()

      const key = keymap.get(header.kid)
      if (!key) throw Errors.invalidSignature()

      const msg = new TextEncoder().encode(`${h}.${b}`)
      let sig: Uint8Array
      try { sig = new Uint8Array(b64u.decode(s)) } catch { throw Errors.malformedQr() }
      const ok = await ed.verifyAsync(sig, msg, key.pub).catch(() => false)
      if (!ok) throw Errors.invalidSignature()

      if (Date.now() > body.exp) throw Errors.expired()
      return { payload: body, kid: header.kid }
    },

    pubkeys() {
      const out: Record<string, string> = {}
      for (const [kid, k] of keymap) out[kid] = Buffer.from(k.pub).toString('hex')
      return out
    },
  }
}
