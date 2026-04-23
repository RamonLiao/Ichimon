import Fastify, { type FastifyInstance, type FastifyError } from 'fastify'
import { parseEnv, type Env } from './env.js'
import { AppError } from './errors.js'
import { healthRoutes } from './routes/health.js'
import { stationsRoutes } from './routes/stations.js'
import { fighterRoutes } from './routes/fighter.js'

declare module 'fastify' {
  interface FastifyInstance {
    config: Env
  }
}

export async function buildApp(): Promise<FastifyInstance> {
  const env = parseEnv()
  const app = Fastify({
    logger: {
      level: env.LOG_LEVEL,
      redact: ['req.headers.authorization', 'req.body.issuer_token'],
    },
    disableRequestLogging: env.NODE_ENV === 'test',
  })
  app.decorate('config', env)

  app.setErrorHandler((err: FastifyError, req, reply) => {
    if (err instanceof AppError) {
      return reply.status(err.httpStatus).send({
        error: { code: err.code, message: err.message, details: err.details },
      })
    }
    if (err.validation) {
      return reply.status(400).send({
        error: { code: 'VALIDATION_ERROR', message: err.message, details: err.validation },
      })
    }
    req.log.error({ err }, 'unhandled')
    return reply.status(500).send({
      error: {
        code: 'INTERNAL_ERROR',
        message: env.NODE_ENV === 'production' ? 'Internal error' : err.message,
      },
    })
  })

  await app.register(healthRoutes)
  await app.register(stationsRoutes)
  await app.register(fighterRoutes)
  return app
}
