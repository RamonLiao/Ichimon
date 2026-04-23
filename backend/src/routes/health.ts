import type { FastifyInstance } from 'fastify'

export async function healthRoutes(app: FastifyInstance) {
  const startedAt = Date.now()
  app.get('/health', async () => ({
    ok: true,
    uptime: (Date.now() - startedAt) / 1000,
    version: process.env.npm_package_version ?? '0.0.0',
  }))

  app.get('/ready', async (_req, _reply) => {
    // TODO(Task 8/6): ping Upstash + gRPC. In test mode, always 200.
    if (process.env.NODE_ENV === 'test') return { ok: true }
    return { ok: true }
  })
}
