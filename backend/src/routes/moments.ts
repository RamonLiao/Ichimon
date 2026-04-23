import type { FastifyInstance } from 'fastify'
import { MomentsResponse, MomentStatusQuery } from '../schemas/moments.js'
import { loadMock } from '../services/mock.js'
import { emptyMomentState, readMomentState } from '../services/top-guardians.js'

const STATUS_MAP = { candidate: 0, finalized: 1, expired: 2 } as const

export async function momentsRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { status?: 'candidate' | 'finalized' | 'expired' } }>(
    '/api/moments',
    { schema: { querystring: MomentStatusQuery, response: { 200: MomentsResponse } } },
    async (req) => {
      const meta = loadMock().moments
      const states = await Promise.all(meta.map(async (m) => {
        if (
          app.config.DATA_SOURCE === 'mock'
          || !m.moment_id.startsWith('0x')
          || m.moment_id.includes('PLACEHOLDER')
        ) {
          return emptyMomentState()
        }
        try {
          return await readMomentState(app.services.sui, m.moment_id)
        } catch (e) {
          req.log.warn({ err: e, moment_id: m.moment_id }, 'moment read failed')
          return emptyMomentState()
        }
      }))
      const merged = meta.map((m, i) => ({ ...m, ...states[i]! }))
      if (!req.query.status) return { moments: merged }
      const want = STATUS_MAP[req.query.status]
      return { moments: merged.filter((m) => m.status === want) }
    },
  )
}
