import * as ed from '@noble/ed25519'
import { sha512 } from '@noble/hashes/sha512'
import { randomBytes } from 'node:crypto'

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m))

const priv = new Uint8Array(randomBytes(32))
const pub = await ed.getPublicKeyAsync(priv)
console.log('Public key (hex):  ', Buffer.from(pub).toString('hex'))
console.log('Private key (b64): ', Buffer.from(priv).toString('base64'))
console.log('\nNext: set QR_KEY_CURRENT=v1:<that base64> in .env or `fly secrets set`')
