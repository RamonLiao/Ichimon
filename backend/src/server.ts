import { buildApp } from './app.js'

const app = await buildApp()
const port = app.config.PORT
const host = '0.0.0.0'
app.listen({ port, host }).then(() => {
  app.log.info(`listening on http://${host}:${port}`)
}).catch((err) => {
  app.log.error({ err }, 'failed to start')
  process.exit(1)
})
