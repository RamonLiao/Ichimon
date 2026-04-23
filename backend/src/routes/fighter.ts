import type { FastifyInstance } from 'fastify'
import { FighterParams, FighterResponse } from '../schemas/fighter.js'
import { loadMock } from '../services/mock.js'
import { Errors } from '../errors.js'

export async function fighterRoutes(app: FastifyInstance) {
  app.get<{ Params: { id: string } }>(
    '/api/fighter/:id',
    { schema: { params: FighterParams, response: { 200: FighterResponse } } },
    async (req) => {
      if (req.params.id !== 'takeru') throw Errors.notFound('fighter_id')
      const m = loadMock()
      return {
        fighter_id: m.fighter.fighter_id,
        name: m.fighter.name,
        profile: m.fighter.profile,
        events: m.stations,
        videos: m.videos,
      }
    },
  )
}
