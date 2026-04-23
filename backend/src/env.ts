import { z } from 'zod'

const csv = (s: string) => s.split(',').map((x) => x.trim()).filter(Boolean)

const qrKey = z.string().regex(/^v\d+:[A-Za-z0-9+/=]+$/, 'QR key must be "v<N>:<base64>"')
  .refine((v) => {
    const b64 = v.split(':')[1]!
    try { return Buffer.from(b64, 'base64').length === 32 } catch { return false }
  }, 'QR key must decode to 32 bytes')

const schema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  DATA_SOURCE: z.enum(['chain', 'mock']).default('chain'),
  SUI_GRPC_URL: z.string().url(),
  PKG_ID: z.string().min(1),
  MINT_REGISTRY_ID: z.string().min(1),
  MINT_REGISTRY_INITIAL_SHARED_VERSION: z.string().regex(/^\d+$/),
  QR_KEY_CURRENT: qrKey,
  QR_KEY_PREVIOUS: qrKey.optional(),
  QR_EXPIRY_MS: z.coerce.number().int().positive().default(300000),
  ISSUER_TOKENS: z.string().min(1).transform(csv),
  UPSTASH_REDIS_REST_URL: z.string().url(),
  UPSTASH_REDIS_REST_TOKEN: z.string().min(1),
  ALLOWED_ORIGINS: z.string().min(1).transform(csv),
})

export type Env = z.infer<typeof schema>

export function parseEnv(raw: NodeJS.ProcessEnv | Record<string, string | undefined> = process.env): Env {
  const result = schema.safeParse(raw)
  if (!result.success) {
    const issues = result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('\n  ')
    throw new Error(`Invalid env:\n  ${issues}`)
  }
  return result.data
}
