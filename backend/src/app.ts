import Fastify, { type FastifyInstance, type FastifyError } from 'fastify'
import cors from '@fastify/cors'
import rateLimit from '@fastify/rate-limit'
import swagger from '@fastify/swagger'
import swaggerUi from '@fastify/swagger-ui'
import { parseEnv, type Env } from './env.js'
import { AppError } from './errors.js'
import { healthRoutes } from './routes/health.js'
import { stationsRoutes } from './routes/stations.js'
import { fighterRoutes } from './routes/fighter.js'
import { qrRoutes } from './routes/qr.js'
import { configRoutes } from './routes/config.js'
import { momentsRoutes } from './routes/moments.js'
import { buildServices, type Services } from './config.js'

declare module 'fastify' {
  interface FastifyInstance {
    config: Env
    services: Services
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
  const services = await buildServices(env)
  app.decorate('services', services)

  await app.register(cors, { origin: env.ALLOWED_ORIGINS, credentials: false })
  await app.register(rateLimit, {
    global: false,
    max: 1000,
    timeWindow: '1 minute',
    enableDraftSpec: false,
    skipOnError: true,
    allowList: env.NODE_ENV === 'test' ? () => true : undefined,
  })
  await app.register(swagger, {
    openapi: {
      info: { title: 'Ichimon Backend', version: '0.1.0' },
      servers: [{ url: '/' }],
    },
  })
  await app.register(swaggerUi, { routePrefix: '/docs' })

  app.setErrorHandler((err: FastifyError, req, reply) => {
    if (err instanceof AppError) {
      return reply.status(err.httpStatus).send({
        error: { code: err.code, message: err.humanMessage, details: err.details },
      })
    }
    if (err.validation) {
      return reply.status(400).send({
        error: { code: 'VALIDATION_ERROR', message: err.message, details: err.validation },
      })
    }
    if (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.status(err.statusCode).send({
        error: { code: err.code ?? 'CLIENT_ERROR', message: err.message },
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
  await app.register(qrRoutes)
  await app.register(configRoutes)
  await app.register(momentsRoutes)
  return app
}
